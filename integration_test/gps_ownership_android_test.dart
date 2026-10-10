import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/owned_gps_session_coordinator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native sqflite sidecar reopen and journal v3 isolation', (
    tester,
  ) async {
    final root = await Directory(
      (await getTemporaryDirectory()).path,
    ).createTemp('owned_gps_synthetic_');
    GpsSessionStore? journal;
    GpsOwnershipStore? sidecar;
    try {
      journal = await GpsSessionStore.open(
        factory: databaseFactory,
        path: '${root.path}/gps.db',
      );
      sidecar = await GpsOwnershipStore.open(
        factory: databaseFactory,
        path: '${root.path}/owners.db',
      );
      var owner = GpsOwner.account('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      final coordinator = OwnedGpsSessionCoordinator(
        journal: journal,
        ownership: sidecar,
        journalId: 'synthetic-native-journal',
        ownerAtStart: () => owner,
      );
      final s = await coordinator.start();
      expect(await journal.db.getVersion(), 3);
      expect(await sidecar.db.getVersion(), 1);
      expect(
        (await sidecar.db.rawQuery('PRAGMA synchronous')).single.values.single,
        2,
      );
      expect(
        (await sidecar.db.rawQuery('PRAGMA journal_mode')).single.values.single,
        'wal',
      );
      await sidecar.close();
      sidecar = await GpsOwnershipStore.open(
        factory: databaseFactory,
        path: '${root.path}/owners.db',
      );
      owner = GpsOwner.account('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
      final manifest = (await sidecar.get('synthetic-native-journal', s.id))!;
      expect(manifest.owner.userId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      await expectLater(
        sidecar.beginTransfer(manifest, owner.targetStore),
        throwsStateError,
      );
      expect((await journal.active())!.id, s.id);
      expect(
        (await sidecar.recoveryOwner(
          'synthetic-native-journal',
          'missing',
        )).kind,
        GpsOwnerKind.legacyUnassigned,
      );
    } finally {
      await sidecar?.close();
      await journal?.close();
      await root.delete(
        recursive: true,
      ); // Only this test's unique synthetic directory.
    }
  });
}
