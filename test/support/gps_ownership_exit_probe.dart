import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/gps_session_ownership.dart';

// Synthetic DB only. Abrupt child exit is not an OS kill/power-loss claim.
Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  final sidecar = await GpsOwnershipStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: args[0],
  );
  final manifest = (await sidecar.get('local-journal-v1', args[1]))!;
  await sidecar.beginTransfer(manifest, manifest.targetStore);
  exit(73); // Deliberately no close; committed WAL must survive.
}
