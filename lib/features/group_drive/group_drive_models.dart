enum GroupDriveStatus { active, ended, expired }

enum GroupRidePhase { lobby, running, ended }

enum GroupDriveRole { administrator, member }

enum GroupSharingStatus { off, sharing, paused }

/// Matches the M4 server's maximum accepted GPS timestamp clock skew.
const groupGpsFutureSkewTolerance = Duration(seconds: 3);
const groupGpsMaximumAge = Duration(seconds: 15);

bool isGroupGpsTimestampFresh(DateTime recordedAt, DateTime referenceTime) {
  final age = referenceTime.toUtc().difference(recordedAt.toUtc());
  return age >= -groupGpsFutureSkewTolerance && age <= groupGpsMaximumAge;
}

/// Advances an authoritative server timestamp using a monotonic elapsed
/// duration. The receiver's wall-clock offset must not affect GPS freshness.
DateTime estimateGroupServerTime(DateTime serverObservedAt, Duration elapsed) =>
    serverObservedAt.toUtc().add(elapsed.isNegative ? Duration.zero : elapsed);

/// Explicit test input only. There is no GPS provider in this delivery.
enum GroupLocationOrigin { synthetic, deviceGps }

class GroupLocationPoint {
  GroupLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.sequence,
    required this.origin,
    this.accuracyMeters,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        sequence <= 0 ||
        !recordedAt.isUtc) {
      throw const GroupDriveException('invalid_location');
    }
    if (origin == GroupLocationOrigin.deviceGps &&
        (accuracyMeters == null ||
            !accuracyMeters!.isFinite ||
            accuracyMeters! < 0 ||
            accuracyMeters! > 75)) {
      throw const GroupDriveException('invalid_location');
    }
  }
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final int sequence;
  final GroupLocationOrigin origin;
  final double? accuracyMeters;
}

class GroupSyntheticLocation extends GroupLocationPoint {
  GroupSyntheticLocation({
    required super.latitude,
    required super.longitude,
    required super.recordedAt,
    required super.sequence,
  }) : super(origin: GroupLocationOrigin.synthetic);
}

class GroupGpsLocation extends GroupLocationPoint {
  GroupGpsLocation({
    required super.latitude,
    required super.longitude,
    required super.recordedAt,
    required super.sequence,
    required double accuracyMeters,
  }) : super(
         origin: GroupLocationOrigin.deviceGps,
         accuracyMeters: accuracyMeters,
       );
}

/// A revocable publication fence. Old grants cannot survive pause/resume,
/// rejoining, owner epoch changes, or a new publishing client.
class GroupLocationGrant {
  const GroupLocationGrant({
    required this.groupId,
    required this.membershipId,
    required this.publicationId,
    required this.ownerEpoch,
    required this.startedAt,
    this.serverGeneration = 0,
  });
  final String groupId;
  final String membershipId;
  final String publicationId;
  final int ownerEpoch;
  final DateTime startedAt;

  /// Server topic fence. Zero is reserved for the in-memory simulator.
  final int serverGeneration;
}

class GroupDriveException implements Exception {
  const GroupDriveException(this.code);
  final String code;
  @override
  String toString() => 'GroupDriveException($code)';
}

/// A bearer invitation grants a request to join, never access to a group's
/// private snapshot. The backend must still authenticate the joining account.
class GroupDriveInvite {
  GroupDriveInvite(this.code) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(code)) {
      throw const GroupDriveException('invalid_invite');
    }
  }
  factory GroupDriveInvite.parse(String value) {
    final input = value.trim();
    if (!input.contains('://')) return GroupDriveInvite(input);
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'driveit' ||
        uri.host != 'group' ||
        uri.path != '/join' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty ||
        uri.queryParameters['v'] != '1' ||
        uri.queryParametersAll['v']?.length != 1 ||
        uri.queryParametersAll['code']?.length != 1) {
      throw const GroupDriveException('invalid_invite');
    }
    return GroupDriveInvite(uri.queryParameters['code']!);
  }
  final String code;
  Uri get link => Uri(
    scheme: 'driveit',
    host: 'group',
    path: '/join',
    queryParameters: {'v': '1', 'code': code},
  );
}

class GroupDriveMember {
  const GroupDriveMember({
    required this.membershipId,
    required this.accountId,
    required this.displayName,
    required this.joinedAt,
    required this.joinOrder,
    required this.role,
    this.sharingStatus = GroupSharingStatus.off,
    this.location,
    this.colorIndex = 0,
  });
  final String membershipId;
  final String accountId;
  final String displayName;
  final DateTime joinedAt;
  final int joinOrder;
  final GroupDriveRole role;
  final GroupSharingStatus sharingStatus;
  final GroupLocationPoint? location;
  final int colorIndex;
}

class GroupDriveSnapshot {
  GroupDriveSnapshot({
    required this.id,
    required this.createdAt,
    required this.observedAt,
    required this.expiresAt,
    required this.status,
    required this.extensionCount,
    required this.revision,
    required this.invite,
    required Iterable<GroupDriveMember> members,
    this.phase = GroupRidePhase.running,
  }) : members = List.unmodifiable(members);
  static const maximumMembers = 10;
  static const initialLifetime = Duration(hours: 12);
  static const extensionLifetime = Duration(hours: 6);
  static const maximumExtensions = 2;
  final String id;
  final DateTime createdAt;
  final DateTime observedAt;
  final DateTime expiresAt;
  final GroupDriveStatus status;
  final int extensionCount;
  final int revision;
  final GroupDriveInvite invite;
  final GroupRidePhase phase;
  final List<GroupDriveMember> members;
  bool get isActive => status == GroupDriveStatus.active;
  bool get isRunning => isActive && phase == GroupRidePhase.running;
}

/// Applies only transient, fresh points to a server snapshot. A normal
/// snapshot intentionally contains no location history, so the short-lived
/// Realtime cache is merged by membership identity until it expires or the
/// server revokes that member's sharing state.
GroupDriveSnapshot withFreshGroupLocations({
  required GroupDriveSnapshot snapshot,
  required Map<String, GroupLocationPoint> locations,
  required DateTime referenceTime,
}) => GroupDriveSnapshot(
  id: snapshot.id,
  createdAt: snapshot.createdAt,
  observedAt: snapshot.observedAt,
  expiresAt: snapshot.expiresAt,
  status: snapshot.status,
  extensionCount: snapshot.extensionCount,
  revision: snapshot.revision,
  invite: snapshot.invite,
  phase: snapshot.phase,
  members: snapshot.members.map((member) {
    final point = locations[member.membershipId];
    return GroupDriveMember(
      membershipId: member.membershipId,
      accountId: member.accountId,
      displayName: member.displayName,
      joinedAt: member.joinedAt,
      joinOrder: member.joinOrder,
      role: member.role,
      sharingStatus: member.sharingStatus,
      location:
          snapshot.isRunning &&
              member.sharingStatus == GroupSharingStatus.sharing &&
              point != null &&
              isGroupGpsTimestampFresh(point.recordedAt, referenceTime)
          ? point
          : null,
      colorIndex: member.colorIndex,
    );
  }),
);
