import 'dart:async';

import '../../services/drive_source_provenance.dart';
import '../../services/gps_session_ownership.dart';
import '../../services/local_owner_lifecycle.dart';
import 'group_drive_models.dart';

/// Future remote implementations must derive their actor from authenticated
/// credentials, validate membership on every read/command, and enforce limits
/// in a server transaction. No Supabase or GPS dependency exists here.
abstract interface class GroupDriveService {
  bool get isSimulation;

  /// Test clock only; a real remote adapter must not manufacture GPS samples.
  DateTime get simulationTime;
  GroupDriveClient forOwner(LocalOwnerLease lease);
}

abstract interface class GroupDriveClient {
  Future<GroupDriveSnapshot?> current();
  Stream<GroupDriveSnapshot?> get changes;
  Future<GroupDriveSnapshot> create();
  Future<GroupDriveSnapshot> join(GroupDriveInvite invite);
  Future<GroupDriveSnapshot> extend(String groupId);
  Future<void> leave(String groupId);
  Future<GroupDriveSnapshot> ban(String groupId, String memberOwnerId);
  Future<void> end(String groupId);
  Future<GroupLocationGrant> startSharing(
    String groupId, {
    required bool consent,
  });
  Future<GroupDriveSnapshot> pauseSharing(String groupId);
  Future<GroupDriveSnapshot> stopSharing(String groupId);
  Future<void> publishSynthetic(
    GroupLocationGrant grant,
    GroupSyntheticLocation point,
  );
  Future<void> publishGps(GroupLocationGrant grant, GroupGpsLocation point);
  Future<void> close();
}

/// Explicitly injected, in-memory simulator. Mutations run synchronously after
/// an awaited fault seam; no await splits the membership/capacity transaction.
/// It does not survive a restart or claim actual multi-user/server security.
class FakeGroupDriveService implements GroupDriveService {
  FakeGroupDriveService({
    DateTime Function()? clock,
    Map<String, String> displayNames = const {},
    this.beforeRequest,
  }) : _clock = clock ?? DateTime.now,
       _displayNames = Map.unmodifiable(displayNames);
  final DateTime Function() _clock;
  final Map<String, String> _displayNames;
  final Future<void> Function(String operation)? beforeRequest;
  final _updates = StreamController<void>.broadcast(sync: true);
  final Map<String, _Group> _groups = {};
  final Map<String, String> _membership = {};
  final Set<_FakeClient> _clients = {};
  bool available = true;
  bool _closed = false;
  @override
  bool get isSimulation => true;
  @override
  DateTime get simulationTime => _now;

  @override
  GroupDriveClient forOwner(LocalOwnerLease lease) {
    _actor(lease);
    final client = _FakeClient(this, lease);
    _clients.add(client);
    return client;
  }

  String _actor(LocalOwnerLease lease) {
    lease.requireCurrent();
    if (lease.owner.kind != GpsOwnerKind.account) {
      throw const GroupDriveException('account_required');
    }
    return lease.owner.userId!;
  }

  DateTime get _now => _clock().toUtc();

  Future<T> _request<T>(
    LocalOwnerLease lease,
    String operation,
    T Function(String actor, DateTime now) action,
  ) async {
    _actor(lease);
    if (_closed || !available) throw const GroupDriveException('offline');
    await beforeRequest?.call(operation);
    final actor = _actor(lease); // A delayed request cannot mutate after A→B.
    if (_closed || !available) throw const GroupDriveException('offline');
    final now = _now;
    _expire(now);
    return action(actor, now);
  }

  void _expire(DateTime now) {
    var changed = false;
    for (final group in _groups.values) {
      if (group.status == GroupDriveStatus.active &&
          !now.isBefore(group.expiresAt)) {
        group.status = GroupDriveStatus.expired;
        group.stopAllSharing();
        group.revision++;
        changed = true;
      }
    }
    if (changed) _notify();
  }

  void _notify() {
    if (!_closed) _updates.add(null);
  }

  void _revokePublisher(String clientId) {
    var changed = false;
    for (final group in _groups.values) {
      for (final sharing in group.sharing.values) {
        if (sharing.issuerClient == clientId) {
          sharing.withdraw(GroupSharingStatus.paused);
          group.revision++;
          changed = true;
        }
      }
    }
    if (changed) _notify();
  }

  _Group? _current(String actor) => _groups[_membership[actor]];

  _Group _authorized(String actor, String id, {bool admin = false}) {
    final group = _groups[id];
    if (group == null ||
        _membership[actor] != id ||
        !group.members.containsKey(actor)) {
      throw const GroupDriveException('membership_required');
    }
    if (group.status != GroupDriveStatus.active) {
      throw const GroupDriveException('group_inactive');
    }
    if (admin && group.admin != actor) {
      throw const GroupDriveException('admin_required');
    }
    return group;
  }

  GroupDriveSnapshot? _snapshotFor(String actor) {
    final group = _current(actor);
    if (group == null || !group.members.containsKey(actor)) return null;
    return group.snapshot(_now);
  }

  Future<void> close() async {
    _closed = true;
    for (final client in _clients.toList()) {
      await client.close();
    }
    await _updates.close();
  }
}

class _FakeClient implements GroupDriveClient {
  _FakeClient(this.service, this.lease) {
    lease.changes.addListener(_ownerChanged);
  }
  final FakeGroupDriveService service;
  final LocalOwnerLease lease;
  final _id = DriveSourceProvenance.newUuidV4();
  bool _closed = false;
  void _ownerChanged() {
    if (!lease.isCurrent) service._revokePublisher(_id);
  }

  void _requireOpen() {
    if (_closed) throw const GroupDriveException('client_closed');
    service._actor(lease);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    lease.changes.removeListener(_ownerChanged);
    service._clients.remove(this);
    service._revokePublisher(_id);
  }

  @override
  Stream<GroupDriveSnapshot?> get changes {
    service._actor(lease);
    return service._updates.stream.map((_) {
      if (!lease.isCurrent) return null;
      return service._snapshotFor(service._actor(lease));
    });
  }

  @override
  Future<GroupDriveSnapshot?> current() => service._request(
    lease,
    'current',
    (actor, _) => service._snapshotFor(actor),
  );

  @override
  Future<GroupDriveSnapshot> create() =>
      service._request(lease, 'create', (actor, now) {
        final existing = service._current(actor);
        if (existing?.status == GroupDriveStatus.active) {
          // An ambiguous retry or repeated tap returns the same active group.
          return existing!.snapshot(now);
        }
        final group = _Group(
          id: DriveSourceProvenance.newUuidV4(),
          invite: GroupDriveInvite(DriveSourceProvenance.newUuidV4()),
          createdAt: now,
          admin: actor,
        );
        group.add(actor, service._displayNames[actor] ?? 'Katılımcı', now);
        service._groups[group.id] = group;
        service._membership[actor] = group.id;
        service._notify();
        return group.snapshot(now);
      });

  @override
  Future<GroupDriveSnapshot> join(GroupDriveInvite invite) =>
      service._request(lease, 'join', (actor, now) {
        final matches = service._groups.values.where(
          (group) => group.invite.code == invite.code,
        );
        if (matches.isEmpty) throw const GroupDriveException('invalid_invite');
        final group = matches.single;
        if (group.status != GroupDriveStatus.active) {
          throw const GroupDriveException('group_inactive');
        }
        final existing = service._current(actor);
        if (existing?.status == GroupDriveStatus.active &&
            existing!.id != group.id) {
          throw const GroupDriveException('already_in_group');
        }
        if (!group.members.containsKey(actor)) {
          if (group.members.length >= GroupDriveSnapshot.maximumMembers) {
            throw const GroupDriveException('group_full');
          }
          group.add(actor, service._displayNames[actor] ?? 'Katılımcı', now);
          service._membership[actor] = group.id;
          group.revision++;
          service._notify();
        }
        return group.snapshot(now);
      });

  @override
  Future<GroupDriveSnapshot> extend(String groupId) =>
      service._request(lease, 'extend', (actor, now) {
        final group = service._authorized(actor, groupId, admin: true);
        if (group.extensionCount >= GroupDriveSnapshot.maximumExtensions) {
          throw const GroupDriveException('extension_limit');
        }
        group.expiresAt = group.expiresAt.add(
          GroupDriveSnapshot.extensionLifetime,
        );
        group.extensionCount++;
        group.revision++;
        service._notify();
        return group.snapshot(now);
      });

  @override
  Future<void> leave(String groupId) =>
      service._request(lease, 'leave', (actor, _) {
        final group = service._authorized(actor, groupId);
        group.members.remove(actor);
        group.sharing.remove(actor);
        service._membership.remove(actor);
        if (group.members.isEmpty) {
          group.status = GroupDriveStatus.ended;
        } else if (group.admin == actor) {
          group.admin = group.members.values
              .reduce(
                (left, right) =>
                    left.joinOrder < right.joinOrder ? left : right,
              )
              .accountId;
        }
        group.revision++;
        service._notify();
      });

  @override
  Future<GroupDriveSnapshot> ban(String groupId, String memberOwnerId) =>
      service._request(lease, 'ban', (actor, now) {
        final group = service._authorized(actor, groupId, admin: true);
        if (memberOwnerId == actor) {
          throw const GroupDriveException('cannot_ban_administrator');
        }
        if (group.members.remove(memberOwnerId) == null) {
          throw const GroupDriveException('member_not_found');
        }
        group.sharing.remove(memberOwnerId);
        if (service._membership[memberOwnerId] == groupId) {
          service._membership.remove(memberOwnerId);
        }
        group.revision++;
        service._notify();
        return group.snapshot(now);
      });

  @override
  Future<void> end(String groupId) =>
      service._request(lease, 'end', (actor, _) {
        final group = service._authorized(actor, groupId, admin: true);
        group.status = GroupDriveStatus.ended;
        group.stopAllSharing();
        group.revision++;
        service._notify();
      });

  @override
  Future<GroupLocationGrant> startSharing(
    String groupId, {
    required bool consent,
  }) async {
    _requireOpen();
    return service._request(lease, 'startSharing', (actor, now) {
      _requireOpen();
      if (!consent) throw const GroupDriveException('consent_required');
      final group = service._authorized(actor, groupId);
      final member = group.members[actor]!;
      final grant = GroupLocationGrant(
        groupId: groupId,
        membershipId: member.membershipId,
        publicationId: DriveSourceProvenance.newUuidV4(),
        ownerEpoch: lease.epoch,
        startedAt: now,
      );
      final sharing = group.sharing[actor]!;
      sharing.withdraw(GroupSharingStatus.sharing);
      sharing.grant = grant;
      sharing.issuerClient = _id;
      group.revision++;
      service._notify();
      return grant;
    });
  }

  /// Withdrawal is synchronous in this fake backend, including when its
  /// transport fault switch is offline. No awaited request can slip a sample
  /// between the user's pause and the publication fence being revoked.
  Future<GroupDriveSnapshot> _withdraw(
    String groupId,
    GroupSharingStatus status,
  ) async {
    _requireOpen();
    final actor = service._actor(lease);
    service._expire(service._now);
    final group = service._authorized(actor, groupId);
    group.sharing[actor]!.withdraw(status);
    group.revision++;
    service._notify();
    return group.snapshot(service._now);
  }

  @override
  Future<GroupDriveSnapshot> pauseSharing(String groupId) =>
      _withdraw(groupId, GroupSharingStatus.paused);
  @override
  Future<GroupDriveSnapshot> stopSharing(String groupId) =>
      _withdraw(groupId, GroupSharingStatus.off);

  @override
  Future<void> publishSynthetic(
    GroupLocationGrant grant,
    GroupSyntheticLocation point,
  ) => _publish(grant, point, 'publishSynthetic');

  @override
  Future<void> publishGps(GroupLocationGrant grant, GroupGpsLocation point) =>
      _publish(grant, point, 'publishGps');

  Future<void> _publish(
    GroupLocationGrant grant,
    GroupLocationPoint point,
    String operation,
  ) async {
    _requireOpen();
    return service._request(lease, operation, (actor, now) {
      _requireOpen();
      final group = service._authorized(actor, grant.groupId);
      final sharing = group.sharing[actor]!;
      if (sharing.status != GroupSharingStatus.sharing ||
          sharing.issuerClient != _id ||
          sharing.grant?.publicationId != grant.publicationId ||
          sharing.grant?.startedAt != grant.startedAt ||
          grant.ownerEpoch != lease.epoch ||
          grant.membershipId != group.members[actor]!.membershipId) {
        throw const GroupDriveException('publication_revoked');
      }
      final age = now.difference(point.recordedAt);
      if (age.isNegative ||
          age > const Duration(seconds: 15) ||
          point.recordedAt.isBefore(sharing.grant!.startedAt) ||
          point.sequence <= sharing.lastSequence ||
          (sharing.location != null &&
              point.recordedAt.isBefore(sharing.location!.recordedAt))) {
        throw const GroupDriveException('stale_location');
      }
      sharing.location = point;
      sharing.lastSequence = point.sequence;
      group.revision++;
      service._notify();
    });
  }
}

class _Sharing {
  GroupSharingStatus status = GroupSharingStatus.off;
  GroupLocationGrant? grant;
  String? issuerClient;
  GroupLocationPoint? location;
  int lastSequence = 0;
  void withdraw(GroupSharingStatus next) {
    status = next;
    grant = null;
    issuerClient = null;
    location = null;
    lastSequence = 0;
  }
}

class _Group {
  _Group({
    required this.id,
    required this.invite,
    required this.createdAt,
    required this.admin,
  }) : expiresAt = createdAt.add(GroupDriveSnapshot.initialLifetime);
  final String id;
  final GroupDriveInvite invite;
  final DateTime createdAt;
  DateTime expiresAt;
  String admin;
  GroupDriveStatus status = GroupDriveStatus.active;
  int extensionCount = 0;
  int revision = 1;
  int nextOrder = 0;
  final Map<String, GroupDriveMember> members = {};
  final Map<String, _Sharing> sharing = {};
  void stopAllSharing() {
    for (final value in sharing.values) {
      value.withdraw(GroupSharingStatus.off);
    }
  }

  void add(String actor, String displayName, DateTime now) {
    sharing[actor] = _Sharing();
    final usedColors = members.values
        .map((member) => member.colorIndex)
        .toSet();
    final colorIndex = List.generate(
      GroupDriveSnapshot.maximumMembers,
      (index) => index,
    ).firstWhere((index) => !usedColors.contains(index));
    members[actor] = GroupDriveMember(
      membershipId: DriveSourceProvenance.newUuidV4(),
      accountId: actor,
      displayName: displayName,
      joinedAt: now,
      joinOrder: nextOrder++,
      role: GroupDriveRole.member,
      colorIndex: colorIndex,
    );
  }

  GroupDriveSnapshot snapshot(DateTime now) => GroupDriveSnapshot(
    id: id,
    createdAt: createdAt,
    observedAt: now,
    expiresAt: expiresAt,
    status: status == GroupDriveStatus.active && !now.isBefore(expiresAt)
        ? GroupDriveStatus.expired
        : status,
    extensionCount: extensionCount,
    revision: revision,
    invite: invite,
    members: members.values.map(
      (member) => GroupDriveMember(
        membershipId: member.membershipId,
        accountId: member.accountId,
        displayName: member.displayName,
        joinedAt: member.joinedAt,
        joinOrder: member.joinOrder,
        role: member.accountId == admin
            ? GroupDriveRole.administrator
            : GroupDriveRole.member,
        colorIndex: member.colorIndex,
        sharingStatus:
            status == GroupDriveStatus.active && now.isBefore(expiresAt)
            ? sharing[member.accountId]!.status
            : GroupSharingStatus.off,
        location:
            status == GroupDriveStatus.active &&
                now.isBefore(expiresAt) &&
                sharing[member.accountId]!.status == GroupSharingStatus.sharing
            ? sharing[member.accountId]!.location
            : null,
      ),
    ),
  );
}
