import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/local_owner_lifecycle.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';

/// Planet DEV Realtime adapter. The backend must be deployed and accepted
/// before this service is injected into normal navigation. Location payloads
/// are received only from private, generation-fenced Broadcast channels.
class SupabaseGroupDriveService implements GroupDriveService {
  SupabaseGroupDriveService(this.client);
  final SupabaseClient client;

  @override
  bool get isSimulation => false;
  @override
  DateTime get simulationTime => DateTime.now().toUtc();

  @override
  GroupDriveClient forOwner(LocalOwnerLease lease) {
    _requireAccount(lease);
    return _SupabaseGroupDriveClient(client, lease);
  }

  static void _requireAccount(LocalOwnerLease lease) {
    lease.requireCurrent();
    if (lease.owner.userId == null || lease.owner.kind.name != 'account') {
      throw const GroupDriveException('account_required');
    }
  }
}

class _SupabaseGroupDriveClient implements GroupDriveClient {
  _SupabaseGroupDriveClient(this._client, this._lease) {
    _lease.changes.addListener(_ownerChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_closed) _refreshQuietly();
    });
  }

  final SupabaseClient _client;
  final LocalOwnerLease _lease;
  final StreamController<GroupDriveSnapshot?> _changes =
      StreamController<GroupDriveSnapshot?>.broadcast(sync: true);
  final Map<String, GroupLocationPoint> _locations = {};
  Timer? _refreshTimer;
  RealtimeChannel? _channel;
  String? _topic;
  GroupDriveSnapshot? _snapshot;
  DateTime? _serverObservedAt;
  final Stopwatch _serverElapsed = Stopwatch();
  GroupLocationGrant? _localGrant;
  DateTime? _lastHeartbeat;
  int _generation = 0;
  bool _closed = false;
  Future<void>? _authRefresh;

  /// The Flutter SDK suspends automatic refresh while paused. The active
  /// foreground consumer explicitly refreshes before its HTTP operations.
  /// No session is copied into task preferences or a new persistent store.
  Future<void> _ensureAuth() async {
    _guard();
    final session = _client.auth.currentSession;
    if (session == null) throw const GroupDriveException('owner_auth_mismatch');
    final expiry = session.expiresAt;
    if (expiry != null &&
        expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) {
      await (_authRefresh ??= _client.auth
          .refreshSession()
          .then<void>((_) {
            _guard();
          })
          .whenComplete(() => _authRefresh = null));
    }
    _guard();
  }

  String get _actor => _lease.owner.userId!;
  void _guard() {
    if (_closed) throw const GroupDriveException('client_closed');
    _lease.requireCurrent();
    if (_lease.owner.kind.name != 'account' ||
        _client.auth.currentUser?.id != _actor) {
      throw const GroupDriveException('owner_auth_mismatch');
    }
  }

  void _ownerChanged() {
    if (!_lease.isCurrent) unawaited(close());
  }

  void _refreshQuietly() {
    unawaited(_refresh().catchError((_) => null));
  }

  @override
  Stream<GroupDriveSnapshot?> get changes => _changes.stream;

  @override
  Future<GroupDriveSnapshot?> current() async {
    final data = await _command('current');
    if (data == null) {
      _snapshot = null;
      _locations.clear();
      await _switchChannel(null, 0);
      _changes.add(null);
      return null;
    }
    final snapshot = _acceptSnapshot(data);
    await _maybeHeartbeat(snapshot);
    return snapshot;
  }

  Future<GroupDriveSnapshot?> _refresh() async {
    try {
      return await current();
    } on Object {
      // On transport/auth failure erase transient coordinates immediately;
      // retaining another member's last point would imply live presence.
      _locations.clear();
      if (!_closed) {
        _changes.add(_snapshot == null ? null : _withoutLocations(_snapshot!));
        _changes.addError(const GroupDriveException('remote_unavailable'));
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _command(
    String action, {
    String? groupId,
    String? inviteCode,
    String? memberId,
    bool consent = false,
  }) async {
    _guard();
    try {
      await _ensureAuth();
      final result = await _client.rpc(
        'phase8_group_command',
        params: {
          'p_action': action,
          'p_group_id': groupId,
          'p_invite_code': inviteCode,
          'p_member_id': memberId,
          'p_consent': consent,
        },
      );
      _guard();
      if (result == null) return null;
      if (result is! Map) throw const GroupDriveException('response_invalid');
      return Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      _guard();
      throw GroupDriveException(_mapServerError(error.message, error.code));
    } on GroupDriveException {
      rethrow;
    } on Object {
      _guard();
      throw const GroupDriveException('remote_unavailable');
    }
  }

  GroupDriveSnapshot _acceptSnapshot(Map<String, dynamic> data) {
    final id = _string(data, 'id');
    final generation = _int(data, 'generation');
    if (_snapshot?.id != id ||
        _generation != generation ||
        _topic != 'driveit:group:$id:$generation') {
      _locations.clear();
      unawaited(_switchChannel(id, generation));
    }
    _generation = generation;
    final membersRaw = data['members'];
    if (membersRaw is! List) {
      throw const GroupDriveException('response_invalid');
    }
    final now = _date(data, 'observedAt');
    _serverObservedAt = now;
    _serverElapsed
      ..reset()
      ..start();
    final members = <GroupDriveMember>[];
    for (final raw in membersRaw) {
      if (raw is! Map) throw const GroupDriveException('response_invalid');
      final member = Map<String, dynamic>.from(raw);
      final memberId = _string(member, 'membershipId');
      final state = _sharing(_string(member, 'sharingStatus'));
      members.add(
        GroupDriveMember(
          membershipId: memberId,
          accountId: _string(member, 'accountId'),
          displayName: _string(member, 'displayName'),
          joinedAt: _date(member, 'joinedAt'),
          joinOrder: _int(member, 'joinOrder'),
          role: _string(member, 'role') == 'administrator'
              ? GroupDriveRole.administrator
              : GroupDriveRole.member,
          sharingStatus: state,
          colorIndex: _int(member, 'colorIndex'),
        ),
      );
    }
    final visibleMembershipIds = members
        .where((member) => member.sharingStatus == GroupSharingStatus.sharing)
        .map((member) => member.membershipId)
        .toSet();
    _locations.removeWhere(
      (membershipId, point) =>
          !visibleMembershipIds.contains(membershipId) ||
          now.difference(point.recordedAt) > const Duration(seconds: 15),
    );
    final grant = _localGrant;
    final own = members
        .where((member) => member.accountId == _actor)
        .firstOrNull;
    if (grant != null) {
      if (own == null ||
          own.membershipId != grant.membershipId ||
          own.sharingStatus != GroupSharingStatus.sharing ||
          grant.groupId != id) {
        _localGrant = null;
        _lastHeartbeat = null;
      } else if (grant.serverGeneration != generation) {
        _localGrant = GroupLocationGrant(
          groupId: grant.groupId,
          membershipId: grant.membershipId,
          publicationId: grant.publicationId,
          ownerEpoch: grant.ownerEpoch,
          startedAt: grant.startedAt,
          serverGeneration: generation,
        );
      }
    }
    final invite = GroupDriveInvite(_string(data, 'inviteCode'));
    final snapshot = GroupDriveSnapshot(
      id: id,
      createdAt: _date(data, 'createdAt'),
      observedAt: now,
      expiresAt: _date(data, 'expiresAt'),
      status: switch (_string(data, 'status')) {
        'active' => GroupDriveStatus.active,
        'expired' => GroupDriveStatus.expired,
        'ended' => GroupDriveStatus.ended,
        _ => throw const GroupDriveException('response_invalid'),
      },
      extensionCount: _int(data, 'extensionCount'),
      revision: _int(data, 'revision'),
      invite: invite,
      members: members,
    );
    final merged = withFreshGroupLocations(
      snapshot: snapshot,
      locations: _locations,
      referenceTime: now,
    );
    _snapshot = merged;
    _changes.add(merged);
    return merged;
  }

  Future<void> _switchChannel(String? groupId, int generation) async {
    final topic = groupId == null ? null : 'driveit:group:$groupId:$generation';
    if (_topic == topic) return;
    final previous = _channel;
    _channel = null;
    _topic = topic;
    _locations.clear();
    if (previous != null) await _client.removeChannel(previous);
    if (_closed || topic == null || _topic != topic) return;
    _guard();
    final channel = _client.channel(
      topic,
      opts: const RealtimeChannelConfig(private: true),
    );
    channel.onBroadcast(
      event: 'location',
      callback: (message) {
        if (_closed ||
            !_lease.isCurrent ||
            _topic != topic ||
            _snapshot?.id != groupId ||
            message['type'] != 'broadcast' ||
            message['event'] != 'location' ||
            message['payload'] is! Map) {
          return;
        }
        try {
          // realtime_client delivers the Broadcast envelope, not its inner
          // application payload. Never accept a flat-map fallback.
          final payload = Map<String, dynamic>.from(message['payload'] as Map);
          if (_int(payload, 'generation') != generation) return;
          final id = _string(payload, 'membershipId');
          final member = _snapshot?.members
              .where((m) => m.membershipId == id)
              .firstOrNull;
          if (member == null ||
              member.sharingStatus != GroupSharingStatus.sharing) {
            return;
          }
          final at = _date(payload, 'recordedAt');
          final now = _estimatedServerNow();
          if (now == null) return;
          if (!isGroupGpsTimestampFresh(at, now)) {
            return;
          }
          final sequence = _int(payload, 'sequence');
          final previous = _locations[id];
          if (sequence <= 0 ||
              (previous != null &&
                  (previous.sequence >= sequence ||
                      !at.isAfter(previous.recordedAt)))) {
            return;
          }
          _locations[id] = GroupGpsLocation(
            latitude: (payload['latitude'] as num).toDouble(),
            longitude: (payload['longitude'] as num).toDouble(),
            accuracyMeters: (payload['accuracyMeters'] as num).toDouble(),
            sequence: sequence,
            recordedAt: at,
          );
          final current = _snapshot;
          if (current != null) _changes.add(_withLocations(current));
        } on Object {
          // Invalid transient data is dropped and never persisted.
        }
      },
    );
    _channel = channel;
    channel.subscribe((status, _) {
      if (_closed || _channel != channel || !_lease.isCurrent) return;
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        _locations.clear();
        _topic = null; // The next refresh/retry must create a fresh channel.
        if (_snapshot != null) _changes.add(_withoutLocations(_snapshot!));
        _changes.addError(const GroupDriveException('realtime_unavailable'));
      }
    });
  }

  Future<void> _maybeHeartbeat(GroupDriveSnapshot? snapshot) async {
    final grant = _localGrant;
    if (grant == null ||
        snapshot?.id != grant.groupId ||
        grant.ownerEpoch != _lease.epoch ||
        !_lease.isCurrent) {
      return;
    }
    final own = snapshot!.members
        .where((member) => member.membershipId == grant.membershipId)
        .firstOrNull;
    if (own?.sharingStatus != GroupSharingStatus.sharing ||
        grant.serverGeneration != _generation) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (_lastHeartbeat != null &&
        now.difference(_lastHeartbeat!) < const Duration(seconds: 10)) {
      return;
    }
    await _command('share_heartbeat', groupId: grant.groupId);
    _guard();
    _lastHeartbeat = now;
  }

  GroupDriveSnapshot _withoutLocations(GroupDriveSnapshot value) =>
      withFreshGroupLocations(
        snapshot: value,
        locations: const {},
        referenceTime: value.observedAt,
      );
  GroupDriveSnapshot _withLocations(GroupDriveSnapshot value) =>
      withFreshGroupLocations(
        snapshot: value,
        locations: _locations,
        referenceTime: _estimatedServerNow() ?? value.observedAt,
      );

  DateTime? _estimatedServerNow() {
    final observedAt = _serverObservedAt;
    if (observedAt == null || !_serverElapsed.isRunning) return null;
    return estimateGroupServerTime(observedAt, _serverElapsed.elapsed);
  }

  @override
  Future<GroupDriveSnapshot> create() async =>
      _acceptSnapshot((await _command('create'))!);
  @override
  Future<GroupDriveSnapshot> join(GroupDriveInvite invite) async =>
      _acceptSnapshot((await _command('join', inviteCode: invite.code))!);
  @override
  Future<GroupDriveSnapshot> extend(String groupId) async =>
      _acceptSnapshot((await _command('extend', groupId: groupId))!);
  @override
  Future<void> leave(String groupId) async {
    _localGrant = null;
    await _command('leave', groupId: groupId);
    await current();
  }

  @override
  Future<GroupDriveSnapshot> ban(String groupId, String memberOwnerId) async {
    final snapshot = _snapshot?.id == groupId ? _snapshot! : (await current())!;
    final member = snapshot.members
        .where((m) => m.accountId == memberOwnerId)
        .firstOrNull;
    if (member == null) throw const GroupDriveException('member_not_found');
    return _acceptSnapshot(
      (await _command('ban', groupId: groupId, memberId: member.membershipId))!,
    );
  }

  @override
  Future<void> end(String groupId) async {
    _localGrant = null;
    await _command('end', groupId: groupId);
    await current();
  }

  @override
  Future<GroupLocationGrant> startSharing(
    String groupId, {
    required bool consent,
  }) async {
    if (!consent) throw const GroupDriveException('consent_required');
    // Do not rewrite GPS timestamps to hide device clock skew. Bound the
    // comparison by this RPC's round trip so network latency alone cannot
    // prove skew. Keep the server's +3s / 15s sample limits unchanged.
    final before = DateTime.now().toUtc();
    final currentGroup = await _command('current');
    final after = DateTime.now().toUtc();
    if (currentGroup == null || _string(currentGroup, 'id') != groupId) {
      throw const GroupDriveException('membership_required');
    }
    final observedAt = _date(currentGroup, 'observedAt');
    if (observedAt.isBefore(before.subtract(const Duration(seconds: 3))) ||
        observedAt.isAfter(after.add(const Duration(seconds: 15)))) {
      throw const GroupDriveException('device_clock_out_of_sync');
    }
    final result = await _command(
      'share_start',
      groupId: groupId,
      consent: consent,
    );
    final grant = result?['grant'];
    if (grant is! Map) throw const GroupDriveException('response_invalid');
    final parsed = Map<String, dynamic>.from(grant);
    final snapshot = _acceptSnapshot(result!);
    final member = snapshot.members
        .where((m) => m.membershipId == parsed['membershipId'])
        .firstOrNull;
    if (member == null) throw const GroupDriveException('membership_required');
    final value = GroupLocationGrant(
      groupId: groupId,
      membershipId: member.membershipId,
      publicationId: _string(parsed, 'publicationId'),
      ownerEpoch: _lease.epoch,
      startedAt: _date(parsed, 'startedAt'),
      serverGeneration: _int(parsed, 'generation'),
    );
    _localGrant = value;
    _lastHeartbeat = DateTime.now().toUtc();
    return value;
  }

  @override
  Future<GroupDriveSnapshot> pauseSharing(String groupId) async =>
      _withdrawSharing('share_pause', groupId);
  @override
  Future<GroupDriveSnapshot> stopSharing(String groupId) async =>
      _withdrawSharing('share_stop', groupId);

  Future<GroupDriveSnapshot> _withdrawSharing(
    String action,
    String groupId,
  ) async {
    _localGrant = null;
    _lastHeartbeat = null;
    return _acceptSnapshot((await _command(action, groupId: groupId))!);
  }

  @override
  Future<void> publishSynthetic(
    GroupLocationGrant grant,
    GroupSyntheticLocation point,
  ) async => throw const GroupDriveException('synthetic_location_forbidden');
  @override
  Future<void> publishGps(
    GroupLocationGrant grant,
    GroupGpsLocation point,
  ) async {
    _guard();
    if (grant.ownerEpoch != _lease.epoch) {
      throw const GroupDriveException('publication_revoked');
    }
    await _publishGps(grant, point, allowGenerationRefresh: true);
  }

  Future<void> _publishGps(
    GroupLocationGrant original,
    GroupGpsLocation point, {
    required bool allowGenerationRefresh,
  }) async {
    _guard();
    final currentGrant = _localGrant;
    if (currentGrant == null ||
        currentGrant.publicationId != original.publicationId ||
        currentGrant.groupId != original.groupId ||
        currentGrant.serverGeneration != _generation) {
      throw const GroupDriveException('publication_revoked');
    }
    try {
      await _ensureAuth();
      await _client.functions.invoke(
        'phase8-group-publish',
        body: {
          'groupId': currentGrant.groupId,
          'membershipId': currentGrant.membershipId,
          'publicationId': currentGrant.publicationId,
          'generation': currentGrant.serverGeneration,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'accuracyMeters': point.accuracyMeters,
          'sequence': point.sequence,
          'recordedAt': point.recordedAt.toUtc().toIso8601String(),
        },
      );
      _guard();
    } on FunctionException catch (error) {
      _guard();
      final detail = '${error.details} ${error.reasonPhrase}';
      if (allowGenerationRefresh &&
          detail.contains('group_generation_revoked')) {
        await current();
        final refreshed = _localGrant;
        if (refreshed != null &&
            refreshed.publicationId == original.publicationId &&
            refreshed.ownerEpoch == _lease.epoch) {
          return _publishGps(original, point, allowGenerationRefresh: false);
        }
      }
      throw GroupDriveException(_mapServerError(detail, '${error.status}'));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lease.changes.removeListener(_ownerChanged);
    _refreshTimer?.cancel();
    _localGrant = null;
    _lastHeartbeat = null;
    final channel = _channel;
    _channel = null;
    _locations.clear();
    if (channel != null) await _client.removeChannel(channel);
    await _changes.close();
  }
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw const GroupDriveException('response_invalid');
  }
  return value;
}

int _int(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! num || !value.isFinite || value.toInt() != value) {
    throw const GroupDriveException('response_invalid');
  }
  return value.toInt();
}

DateTime _date(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) throw const GroupDriveException('response_invalid');
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) throw const GroupDriveException('response_invalid');
  return parsed;
}

GroupSharingStatus _sharing(String value) => switch (value) {
  'off' => GroupSharingStatus.off,
  'paused' => GroupSharingStatus.paused,
  'sharing' => GroupSharingStatus.sharing,
  _ => throw const GroupDriveException('response_invalid'),
};
String _mapServerError(String message, String? code) {
  final text = '$message $code'.toLowerCase();
  for (final value in const [
    'account_required',
    'already_in_group',
    'group_full',
    'extension_limit',
    'administrator_required',
    'membership_required',
    'group_generation_revoked',
    'publication_revoked',
    'consent_required',
    'invalid_invite',
    'invite_unavailable',
    'member_not_found',
    'group_inactive',
    'location_invalid_or_stale',
  ]) {
    if (text.contains(value)) return value;
  }
  if (text.contains('42501')) return 'membership_required';
  return 'remote_unavailable';
}
