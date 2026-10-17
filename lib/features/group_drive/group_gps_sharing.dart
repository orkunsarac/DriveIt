import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/local_owner_lifecycle.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';
import 'group_gps_source.dart';

/// Revocable owner-scoped publication. Background continuation requires both
/// explicit consent and the foreground-task-backed source; nothing is restored.
class GroupGpsSharing extends ChangeNotifier with WidgetsBindingObserver {
  GroupGpsSharing({
    required this.lease,
    required this.client,
    required this.source,
    this.diagnostics,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    lease.changes.addListener(_ownerChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  final LocalOwnerLease lease;
  final GroupDriveClient client;
  final GroupGpsSource source;

  /// Optional, non-sensitive diagnostics supplied only by a controlled test composition.
  final void Function(String event)? diagnostics;
  final DateTime Function() clock;
  StreamSubscription<Position>? _subscription;
  Timer? _permissionCheck;
  GroupLocationGrant? _grant;
  Position? _latest;
  DateTime? _lastTimestamp;
  int _generation = 0, _sequence = 0;
  bool _closed = false, _sending = false, _checking = false;
  bool _backgroundConsent = false;
  String? errorCode;
  String? sampleState;
  String? _consentedGroup, _consentedMembership;
  bool _consentedBackground = false, _autoStartPending = false;
  Future<void> _consentWork = Future.value();
  Future<void> _work = Future.value();
  Future<void> get settled async {
    await _consentWork;
    await _work;
  }

  bool get active => _grant != null && lease.isCurrent && !_closed;
  bool get _visible =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool _valid(int generation) =>
      !_closed &&
      lease.isCurrent &&
      generation == _generation &&
      (_visible || (_grant != null && _backgroundConsent));
  void _ownerChanged() {
    if (!lease.isCurrent) {
      _clearConsent();
      diagnostics?.call('owner_epoch_invalidated');
      _halt();
    }
  }

  bool hasSharingConsent(GroupDriveSnapshot group) =>
      !_closed &&
      lease.isCurrent &&
      group.isActive &&
      group.id == _consentedGroup &&
      group.members.any(
        (m) =>
            m.accountId == lease.owner.userId &&
            m.membershipId == _consentedMembership,
      );

  bool get consentedBackground => _consentedBackground;

  /// In-memory approval belongs to this exact membership and owner lease.
  /// Nothing is restored across application starts or membership replacement.
  void rememberConsent(
    GroupDriveSnapshot group, {
    required bool backgroundConsent,
    bool startWhenRunning = true,
  }) {
    lease.requireCurrent();
    if (_closed || !group.isActive) return;
    final own = group.members
        .where((m) => m.accountId == lease.owner.userId)
        .single;
    _consentedGroup = group.id;
    _consentedMembership = own.membershipId;
    _consentedBackground = backgroundConsent;
    _autoStartPending = startWhenRunning;
    updateGroup(group);
  }

  void _clearConsent() {
    _consentedGroup = null;
    _consentedMembership = null;
    _consentedBackground = false;
    _autoStartPending = false;
  }

  Future<void> _startApproved(String groupId, bool background) async {
    final membership = _consentedMembership;
    bool sameApproval() =>
        !_closed &&
        lease.isCurrent &&
        _consentedGroup == groupId &&
        _consentedMembership == membership;
    try {
      await start(groupId, consent: true, backgroundConsent: background);
    } on GroupGpsException catch (error) {
      if (!sameApproval()) return;
      errorCode = error.code;
      if (!_closed) notifyListeners();
    } on GroupDriveException catch (error) {
      if (!sameApproval()) return;
      errorCode = error.code;
      if (!_closed) notifyListeners();
    } on StateError {
      if (lease.isCurrent && !_closed) rethrow;
    }
  }

  void updateGroup(GroupDriveSnapshot? group) {
    if (group == null || !hasSharingConsent(group)) {
      final hadConsent = _consentedMembership != null;
      _clearConsent();
      if (hadConsent) {
        _halt(); // Revoke an in-flight Android permission request.
      }
    } else if (_autoStartPending && group.isRunning && _visible && !active) {
      _autoStartPending = false;
      _consentWork = _startApproved(group.id, _consentedBackground);
    }
    final grant = _grant;
    if (grant == null) {
      return;
    }
    if (group?.isRunning != true ||
        group?.id != grant.groupId ||
        !group!.members.any(
          (m) =>
              m.membershipId == grant.membershipId &&
              m.sharingStatus == GroupSharingStatus.sharing,
        )) {
      diagnostics?.call('grant_invalidated_group_or_membership');
      _halt();
      errorCode = 'group_access_lost';
      if (!_closed) notifyListeners();
    } else {
      diagnostics?.call('group_membership_valid');
    }
  }

  Future<void> start(
    String groupId, {
    required bool consent,
    bool backgroundConsent = false,
  }) async {
    diagnostics?.call(
      'start_requested:consent:$consent,visible:$_visible,owner_current:${lease.isCurrent}',
    );
    if (!consent) throw const GroupGpsException('consent_required');
    if (backgroundConsent && source is! BackgroundGroupGpsSource) {
      throw const GroupGpsException('background_source_required');
    }
    if (!_visible || !lease.isCurrent || _closed) {
      throw const GroupGpsException('foreground_required');
    }
    final approvedMembership = _consentedMembership;
    bool approvalCurrent() =>
        approvedMembership == null ||
        (_consentedGroup == groupId &&
            _consentedMembership == approvedMembership);
    final previousGroup = _grant?.groupId;
    _halt();
    final generation = _generation;
    if (previousGroup != null) await client.pauseSharing(previousGroup);
    errorCode = null;
    await source.requestAccess().timeout(
      const Duration(minutes: 1),
      onTimeout: () => throw const GroupGpsException('permission_timeout'),
    );
    diagnostics?.call('permission_access_granted');
    if (!_valid(generation) || !approvalCurrent()) {
      throw const GroupGpsException('context_changed');
    }
    final grant = await client.startSharing(groupId, consent: true);
    if (!_valid(generation) || !approvalCurrent()) {
      await client.pauseSharing(groupId);
      throw const GroupGpsException('context_changed');
    }
    _grant = grant;
    _backgroundConsent = backgroundConsent;
    diagnostics?.call(
      'sharing_grant_active:owner_current:${lease.isCurrent},visible:$_visible',
    );
    _lastTimestamp = null;
    _sequence = 0;
    try {
      _subscription = source.positions().listen(
        (position) {
          if (!_valid(generation) || !active) {
            diagnostics?.call(
              'callback_rejected:invalid_generation_or_inactive',
            );
            return;
          }
          _latest = position;
          if (!_sending) {
            _work = _pump(generation);
            unawaited(_work);
          }
        },
        onError: (Object _) => unawaited(_fail('gps_stream_error', generation)),
        onDone: () => unawaited(_fail('gps_stream_ended', generation)),
      );
      diagnostics?.call('position_subscription_created');
      _setSampleState('waiting_for_gps');
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
            age < -groupGpsFutureSkewTolerance ||
            age > groupGpsMaximumAge ||
            !position.accuracy.isFinite ||
            position.accuracy < 0 ||
            position.accuracy > 75 ||
            !position.latitude.isFinite ||
            !position.longitude.isFinite ||
            position.latitude.abs() > 90 ||
            position.longitude.abs() > 180 ||
            (_lastTimestamp != null && !at.isAfter(_lastTimestamp!))) {
          final reason = _rejectReason(position, at, age);
          diagnostics?.call('position_rejected:$reason');
          _setSampleState('rejected_$reason');
          continue;
        }
        diagnostics?.call(
          'position_accepted:age_seconds:${age.inSeconds},accuracy:${position.accuracy.round()},owner_current:${lease.isCurrent},group_grant:true',
        );
        _setSampleState('publishing');
        diagnostics?.call('gps_publish_started');
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
        if (!_valid(generation) || _grant == null) return;
        _setSampleState('published');
        diagnostics?.call('gps_publish_completed');
        if (diagnostics != null) {
          final snapshot = await client.current();
          final member = snapshot?.members
              .where((item) => item.membershipId == _grant?.membershipId)
              .firstOrNull;
          diagnostics?.call(
            'fake_member_readback:device_gps:${member?.location?.origin == GroupLocationOrigin.deviceGps},sharing:${member?.sharingStatus == GroupSharingStatus.sharing}',
          );
        }
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

  void _setSampleState(String? value) {
    if (sampleState == value) return;
    sampleState = value;
    if (!_closed) notifyListeners();
  }

  void _halt() {
    ++_generation;
    _backgroundConsent = false;
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
    diagnostics?.call('sharing_failed:$code');
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
    _autoStartPending = false;
    _halt();
    return client.pauseSharing(groupId);
  }

  Future<GroupDriveSnapshot> stop(String groupId) async {
    _autoStartPending = false;
    _halt();
    return client.stopSharing(groupId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    diagnostics?.call(
      'lifecycle:${state.name},visible:${state == AppLifecycleState.resumed}',
    );
    if (state == AppLifecycleState.detached ||
        (!_backgroundConsent &&
            (state == AppLifecycleState.paused ||
                state == AppLifecycleState.hidden ||
                state == AppLifecycleState.detached))) {
      unawaited(_fail('background_paused', _generation));
      _halt(); // Invalidates a pending permission request too.
    }
  }

  String _rejectReason(Position position, DateTime at, Duration age) {
    if (position.isMocked) return 'mocked';
    if (at.isBefore(_grant!.startedAt)) return 'before_grant';
    if (age < -groupGpsFutureSkewTolerance) return 'future_timestamp';
    if (age > groupGpsMaximumAge) return 'stale';
    if (!position.accuracy.isFinite || position.accuracy < 0) {
      return 'invalid_accuracy';
    }
    if (position.accuracy > 75) return 'accuracy_over_75m';
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return 'invalid_coordinates';
    }
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
      return 'coordinates_out_of_range';
    }
    if (_lastTimestamp != null && !at.isAfter(_lastTimestamp!)) {
      return 'non_monotonic_timestamp';
    }
    return 'unknown';
  }

  Future<void> close() async {
    if (_closed) return;
    _clearConsent();
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
