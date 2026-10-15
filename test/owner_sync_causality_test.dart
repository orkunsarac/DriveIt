import 'package:flutter_test/flutter_test.dart';
import 'package:driveit_project/services/owner_sync_causality.dart';

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const source = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const deletion = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

void main() {
  final deletedAt = DateTime.utc(2026, 10, 13, 12);

  testWidgets(
    'M2 heartbeat ticks at 30 seconds and stops on owner revocation',
    (tester) async {
      final remote = _LeaseTransport();
      var current = true;
      final failures = <Object>[];
      final heartbeat = OwnerDriveLeaseHeartbeat(
        remote: remote,
        requireCurrent: () {
          if (!current) throw StateError('revoked');
        },
        onFailure: failures.add,
      );
      await heartbeat.start(
        sourceIdentity: source,
        deviceId: 'synthetic-device-a',
        sessionId: 'synthetic-session-1',
      );
      expect(remote.calls, 1);
      await tester.pump(const Duration(seconds: 29));
      expect(remote.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(remote.calls, 2);
      current = false;
      await tester.pump(const Duration(seconds: 30));
      expect(failures, hasLength(1));
      expect(heartbeat.evidence, isNull);
      await tester.pump(const Duration(minutes: 2));
      expect(remote.calls, 2);
      heartbeat.stop();
    },
  );

  test('tombstone evidence needs explicit immutable causal claims', () {
    final a = OwnerDriveDeletionEvidence(
      ownerId: ownerA,
      deletionId: deletion,
      sourceIdentity: source,
      deletedAt: deletedAt,
      observedRemoteSequence: 14,
      causalVersion: 1,
    );
    final retry = OwnerDriveDeletionEvidence(
      ownerId: ownerA,
      deletionId: deletion,
      sourceIdentity: source,
      deletedAt: deletedAt,
      observedRemoteSequence: 14,
      causalVersion: 1,
    );
    expect(a.sameOperationAs(retry), isTrue);
    expect(
      a.sameOperationAs(
        OwnerDriveDeletionEvidence(
          ownerId: ownerA,
          deletionId: deletion,
          sourceIdentity: source,
          deletedAt: deletedAt,
          observedRemoteSequence: 15,
          causalVersion: 1,
        ),
      ),
      isFalse,
    );
  });

  test('tombstone rejects invented/missing identity or time evidence', () {
    expect(
      () => OwnerDriveDeletionEvidence(
        ownerId: ownerA,
        deletionId: 'legacy-drive-id',
        sourceIdentity: source,
        deletedAt: deletedAt,
        observedRemoteSequence: 0,
        causalVersion: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => OwnerDriveDeletionEvidence(
        ownerId: ownerA,
        deletionId: deletion,
        sourceIdentity: source,
        deletedAt: DateTime(2026, 10, 13, 12),
        observedRemoteSequence: 0,
        causalVersion: 1,
      ),
      throwsFormatException,
    );
  });

  test('tombstone rejects cross-owner and invalid causal revisions', () {
    expect(
      () => OwnerDriveDeletionEvidence(
        ownerId: 'not-an-owner',
        deletionId: deletion,
        sourceIdentity: source,
        deletedAt: deletedAt,
        observedRemoteSequence: -1,
        causalVersion: 0,
      ),
      throwsFormatException,
    );
  });

  test('lease is active only before expiry and after heartbeat', () {
    final lease = _lease(
      heartbeatAt: deletedAt,
      expiresAt: deletedAt.add(const Duration(minutes: 3)),
    );
    expect(lease.isActiveAt(deletedAt.add(const Duration(seconds: 2))), isTrue);
    expect(lease.isActiveAt(lease.expiresAt), isFalse);
    expect(
      lease.isActiveAt(deletedAt.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('stale fencing token is rejected for the same logical drive', () {
    final old = _lease(token: 7);
    final current = _lease(token: 8);
    expect(old.isFencedBy(current), isTrue);
    expect(current.isFencedBy(old), isFalse);
    expect(old.sameLeaseAs(current), isFalse);
  });

  test('a token for another owner or source is not treated as a renewal', () {
    final old = _lease();
    final otherOwner = _lease(
      ownerId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      token: 9,
    );
    final otherSource = _lease(
      sourceIdentity: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
      token: 9,
    );
    expect(old.isFencedBy(otherOwner), isFalse);
    expect(old.isFencedBy(otherSource), isFalse);
  });

  test('lease rejects oversized lifetime and non-monotonic interval', () {
    expect(
      () => _lease(expiresAt: deletedAt.add(const Duration(minutes: 4))),
      throwsFormatException,
    );
    expect(() => _lease(expiresAt: deletedAt), throwsFormatException);
  });
}

class _LeaseTransport implements OwnerDriveLeaseTransport {
  int calls = 0;
  @override
  Future<OwnerDriveLeaseEvidence> updateLease({
    required String sourceIdentity,
    required String deviceId,
    required String sessionId,
    int? fencingToken,
  }) async {
    calls++;
    return _lease();
  }
}

OwnerDriveLeaseEvidence _lease({
  String ownerId = ownerA,
  String sourceIdentity = source,
  int token = 7,
  DateTime? heartbeatAt,
  DateTime? expiresAt,
}) {
  final heartbeat = heartbeatAt ?? DateTime.utc(2026, 10, 13, 12);
  return OwnerDriveLeaseEvidence(
    ownerId: ownerId,
    deviceId: 'synthetic-device-a',
    sessionId: 'synthetic-session-1',
    sourceIdentity: sourceIdentity,
    fencingToken: token,
    heartbeatAt: heartbeat,
    expiresAt: expiresAt ?? heartbeat.add(const Duration(minutes: 3)),
  );
}
