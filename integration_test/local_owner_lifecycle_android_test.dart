import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/legacy_owner_consent.dart';

class _SyntheticAuth implements LocalOwnerAuth {
  @override
  String? userId;
  final events = StreamController<String?>.broadcast(sync: true);
  @override
  Stream<String?> get changes => events.stream;
  void change(String? id) {
    userId = id;
    events.add(id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'synthetic native owner switch revokes leases and consent; disks reopen',
    (tester) async {
      final root = await (await getTemporaryDirectory()).createTemp(
        'owner_lifecycle_native_synthetic_',
      );
      const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      final auth = _SyntheticAuth();
      LocalOwnerLifecycle create() => LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: auth,
        openStore: (owner) =>
            OwnerScopedLocalStore.open(root: root.path, owner: owner),
        driveInProgress: () async => false,
      );
      var runtime = create();
      try {
        await runtime.start();
        await runtime.lease.put('drive_names', 'same', 'guest');
        auth.change(a);
        await runtime.settled;
        final old = runtime.lease;
        await old.put('drive_names', 'same', 'A');
        final consent = LegacyOwnerConsentController(
          runtime,
          const LegacyOwnerPreview(
            manifestFingerprint: 'synthetic',
            driveCount: 1,
            worldStatus: 'synthetic',
            careerStatus: 'synthetic',
            copyContractVerified: true,
          ),
        ).approve();
        auth.change(b);
        expect(() => old.read('drive_names', 'same'), throwsStateError);
        expect(() => consent.verify('synthetic'), throwsStateError);
        await runtime.settled;
        expect(runtime.lease.read('drive_names', 'same'), null);
        await runtime.lease.put('drive_names', 'same', 'B');
        await runtime.close();
        runtime.dispose();
        runtime = create();
        await runtime.start();
        expect(runtime.lease.read('drive_names', 'same'), 'B');
        auth.change(a);
        await runtime.settled;
        expect(runtime.lease.read('drive_names', 'same'), 'A');
        auth.change(null);
        await runtime.settled;
        expect(runtime.lease.read('drive_names', 'same'), 'guest');
      } finally {
        await runtime.close();
        runtime.dispose();
        await auth.events.close();
        await root.delete(recursive: true); // Only this unique synthetic root.
      }
    },
  );
}
