import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/legacy_asset_transfer.dart';
import '../test/support/legacy_import_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native SQLite durable claim + StatFs + fsync + poster copy/reopen',
    (tester) async {
      // Android may expose a system alias above the app sandbox. Canonicalize
      // the trusted path-provider directory before deriving private test paths.
      final temporary = Directory(
        await (await getTemporaryDirectory()).resolveSymbolicLinks(),
      );
      final f = ImportFixture(
        await temporary.createTemp('legacy_import_native_synthetic_'),
        databaseFactory,
      );
      await f.start();
      try {
        final disk = AndroidImportDisk();
        expect(
          await disk.availableBytes(f.root),
          greaterThan(f.inventory.requiredBytes),
        );
        final reader = await f.run(f.importer(deviceDisk: disk));
        final drive = reader.read<DriveSession>('drives', 'old')!;
        expect(
          await (await reader.file(drive.mapImagePath)).readAsBytes(),
          f.png,
        );
        expect(await (await reader.posterFile('poster')).readAsBytes(), f.png);
        expect((await f.ledger.get(f.inventory.namespace))!.completed, true);
        expect((await f.source.survey()).fingerprint, f.inventory.fingerprint);
        await f.closeReaders();
        expect((await f.run(f.importer(deviceDisk: disk))).keys('drives'), [
          'old',
        ]);
      } finally {
        await f.close();
      }
    },
  );
}
