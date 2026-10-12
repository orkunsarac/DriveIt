import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/local_owner_lifecycle.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';
import 'group_gps_source.dart';

/// One revocable UI GPS subscription. No journal, storage, FGS or remote
/// transport. Background/restart never resumes sharing without another consent.
class GroupGpsSharing extends ChangeNotifier with WidgetsBindingObserver {
  GroupGpsSharing({
    required this.lease,
    required this.client,
    required this.source,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    lease.changes.addListener(_ownerChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  final LocalOwnerLease lease;
  final GroupDriveClient client;
  final GroupGpsSource source;
  final DateTime Function() clock;
  StreamSubscription<Position>? _subscription;
  Timer? _permissionCheck;
  GroupLocationGrant? _grant;
  Position? _latest;
  DateTime? _lastTimestamp;
  int _generation = 0, _sequence = 0;
  bool _closed = false, _sending = false, _checking = false;
  String? errorCode;
  Future<void> _work = Future.value();
  Future<void> get settled => _work;
  bool get active => _grant != null && lease.isCurrent && !_closed;
  bool get _visible =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool _valid(int generation) =>
      !_closed && lease.isCurrent && generation == _generation && _visible;
  void _ownerChanged() {
    if (!lease.isCurrent) {
      _halt();
    }
  }

  void updateGroup(GroupDriveSnapshot? group) {
    final grant = _grant;
    if (grant == null) {
      return;
    }
    if (group?.isActive != true ||
        group?.id != grant.groupId ||
        !group!.members.any(
          (m) =>
              m.membershipId == grant.membershipId &&
              m.sharingStatus == GroupSharingStatus.sharing,
        )) {
      _halt();
    }
  }

  Future<void> start(String groupId, {required bool consent}) async {
    if (!consent) throw const GroupGpsException('consent_required');
    if (!_visible || !lease.isCurrent || _closed) {
      throw const GroupGpsException('foreground_required');
    }
    final previousGroup = _grant?.groupId;
    _halt();
    final generation = _generation;
    if (previousGroup != null) await client.pauseSharing(previousGroup);
    errorCode = null;
    await source.requestAccess().timeout(
      const Duration(minutes: 1),
      onTimeout: () => throw const GroupGpsException('permission_timeout'),
    );
    if (!_valid(generation)) throw const GroupGpsException('context_changed');
    final grant = await client.startSharing(groupId, consent: true);
    if (!_valid(generation)) {
      await client.pauseSharing(groupId);
      throw const GroupGpsException('context_changed');
    }
    _grant = grant;
    _lastTimestamp = null;
    _sequence = 0;
    try {
      _subscription = source.positions().listen(
        (position) {
          if (!_valid(generation) || !active) return;
          _latest = position;
          if (!_sending) {
            _work = _pump(generation);
            unawaited(_work);
          }
        },
        onError: (Object _) => unawaited(_fail('gps_stream_error', generation)),
        onDone: () => unawaited(_fail('gps_stream_ended', generation)),
      );
      _permissionCheck = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_checking && _valid(generation)) unawaited(_check(generation));
      });
    } catch (_) {
      await _fail('gps_stream_error', generation);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _check(int generation) async {
    _checking = true;
    try {
      if (!await source.hasAccess().timeout(const Duration(seconds: 5)) &&
          _valid(generation)) {
        await _fail('permission_revoked', generation);
      }
    } catch (_) {
      if (_valid(generation)) {
        await _fail('permission_check_failed', generation);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _pump(int generation) async {
    _sending = true;
    try {
      while (_valid(generation) && _grant != null && _latest != null) {
        final position = _latest!;
        _latest = null;
        if (!await source.hasAccess().timeout(const Duration(seconds: 5))) {
          await _fail('permission_revoked', generation);
          return;
        }
        if (!_valid(generation) || _grant == null) return;
        final at = position.timestamp.toUtc();
        final age = clock().toUtc().difference(at);
        if (position.isMocked ||
            at.isBefore(_grant!.startedAt) ||
            age.isNegative ||
            age > const Duration(seconds: 15) ||
            !position.accuracy.isFinite ||
            position.accuracy < 0 ||
            position.accuracy > 75 ||
            !position.latitude.isFinite ||
            !position.longitude.isFinite ||
            position.latitude.abs() > 90 ||
            position.longitude.abs() > 180 ||
            (_lastTimestamp != null && !at.isAfter(_lastTimestamp!))) {
          continue;
        }
        await client.publishGps(
          _grant!,
          GroupGpsLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            recordedAt: at,
            accuracyMeters: position.accuracy,
            sequence: ++_sequence,
          ),
        );
        if (!_valid(generation)) return;
        _lastTimestamp = at;
      }
    } catch (_) {
      if (_valid(generation)) await _fail('gps_publish_failed', generation);
    } finally {
      _sending = false;
      if (active && _latest != null) unawaited(_pump(_generation));
    }
  }

  void _halt() {
    ++_generation;
    _grant = null;
    _latest = null;
    _permissionCheck?.cancel();
    _permissionCheck = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object _) {
          errorCode = 'gps_cancel_failed';
          if (!_closed) notifyListeners();
        }),
      );
    }
  }

  Future<void> _fail(String code, int generation) async {
    if (generation != _generation || _closed) return;
    final groupId = _grant?.groupId;
    _halt();
    errorCode = code;
    if (groupId != null && lease.isCurrent) {
      try {
        await client.pauseSharing(groupId);
      } on GroupDriveException catch (error) {
        if (error.code != 'group_inactive' &&
            error.code != 'membership_required') {
          errorCode = 'withdraw_failed';
        }
      }
    }
    if (!_closed) notifyListeners();
  }

  Future<GroupDriveSnapshot> pause(String groupId) async {
    _halt();
    return client.pauseSharing(groupId);
  }

  Future<GroupDriveSnapshot> stop(String groupId) async {
    _halt();
    return client.stopSharing(groupId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_fail('background_paused', _generation));
      _halt(); // Invalidates a pending permission request too.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    final group = _grant?.groupId;
    _halt();
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    lease.changes.removeListener(_ownerChanged);
    if (group != null && lease.isCurrent) {
      try {
        await client.pauseSharing(group);
      } on GroupDriveException catch (error) {
        if (error.code != 'group_inactive' &&
            error.code != 'membership_required' &&
            error.code != 'client_closed') {
          rethrow;
        }
      }
    }
  }
}
