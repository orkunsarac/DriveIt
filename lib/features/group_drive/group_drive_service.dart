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
  GroupDriveClient forOwner(LocalOwnerLease lease);
}

abstract interface class GroupDriveClient {
  Future<GroupDriveSnapshot?> current();
  Stream<GroupDriveSnapshot?> get changes;
  Future<GroupDriveSnapshot> create();
  Future<GroupDriveSnapshot> join(GroupDriveInvite invite);
  Future<GroupDriveSnapshot> extend(String groupId);
  Future<void> leave(String groupId);
  Future<void> end(String groupId);
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
  bool available = true;
  bool _closed = false;
  @override
  bool get isSimulation => true;

  @override
  GroupDriveClient forOwner(LocalOwnerLease lease) {
    _actor(lease);
    return _FakeClient(this, lease);
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
        group.revision++;
        changed = true;
      }
    }
    if (changed) _notify();
  }

  void _notify() => _updates.add(null);

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
    await _updates.close();
  }
}

class _FakeClient implements GroupDriveClient {
  _FakeClient(this.service, this.lease);
  final FakeGroupDriveService service;
  final LocalOwnerLease lease;
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
  Future<void> end(String groupId) =>
      service._request(lease, 'end', (actor, _) {
        final group = service._authorized(actor, groupId, admin: true);
        group.status = GroupDriveStatus.ended;
        group.revision++;
        service._notify();
      });
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
  void add(String actor, String displayName, DateTime now) {
    members[actor] = GroupDriveMember(
      membershipId: DriveSourceProvenance.newUuidV4(),
      accountId: actor,
      displayName: displayName,
      joinedAt: now,
      joinOrder: nextOrder++,
      role: GroupDriveRole.member,
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
      ),
    ),
  );
}
