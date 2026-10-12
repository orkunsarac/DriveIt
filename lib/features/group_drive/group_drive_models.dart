enum GroupDriveStatus { active, ended, expired }

enum GroupDriveRole { administrator, member }

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
  });
  final String membershipId;
  final String accountId;
  final String displayName;
  final DateTime joinedAt;
  final int joinOrder;
  final GroupDriveRole role;
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
  final List<GroupDriveMember> members;
  bool get isActive => status == GroupDriveStatus.active;
}
