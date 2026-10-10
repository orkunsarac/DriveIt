import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/owned_gps_session_coordinator.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/scoped_gps_transfer_sink.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native sqflite v3 sidecar and isolated Hive transfer reopen', (
    tester,
  ) async {
    final root = await (await getTemporaryDirectory()).createTemp(
      'scoped_native_synthetic_',
    );
    final ownerA = GpsOwner.account('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    final ownerB = GpsOwner.account('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    var a = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
    final b = await OwnerScopedLocalStore.open(root: root.path, owner: ownerB);
    final journal = await GpsSessionStore.open(
      factory: databaseFactory,
      path: '${root.path}/gps.db',
    );
    final sidecar = await GpsOwnershipStore.open(
      factory: databaseFactory,
      path: '${root.path}/owner.db',
    );
    try {
      var auth = ownerA;
      final coordinator = OwnedGpsSessionCoordinator(
        journal: journal,
        ownership: sidecar,
        journalId: 'synthetic-native-journal',
        ownerAtStart: () => auth,
      );
      final session = await coordinator.start();
      await journal.stop(session.id, expectedSequence: 0);
      auth = ownerB;
      final binding = (await sidecar.get(
        'synthetic-native-journal',
        session.id,
      ))!;
      final sink = ScopedGpsTransferSink(a, binding);
      final proposal = driveTransferManifest(
        DriveSession(
          id: session.id,
          date: DateTime.utc(2026),
          distance: 0,
          durationSeconds: 0,
          averageSpeed: 0,
          maxSpeed: 0,
          mapImagePath: '',
          route: [],
        ),
      );
      await coordinator.save(session.id, proposal, sink);
      await coordinator.save(session.id, proposal, sink);
      expect(await journal.db.getVersion(), 3);
      expect(await sidecar.db.getVersion(), 1);
      expect(
        await sidecar.verified('synthetic-native-journal', session.id),
        true,
      );
      expect(b.keys(ownerB, 'drives'), isEmpty);
      await a.close();
      a = await OwnerScopedLocalStore.open(root: root.path, owner: ownerA);
      expect(a.keys(ownerA, 'drives'), [session.id]);
      expect(
        a.read<DriveSession>(ownerA, 'drives', session.id)!.id,
        session.id,
      );
      expect(() => a.read(ownerB, 'drives', session.id), throwsStateError);
    } finally {
      await a.close();
      await b.close();
      await journal.close();
      await sidecar.close();
      await root.delete(
        recursive: true,
      ); // Only unique synthetic fixture directory.
    }
  });
}
