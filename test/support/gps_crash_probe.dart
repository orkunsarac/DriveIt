// Run only against a temporary synthetic database by gps_session_store_test.
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/services/gps_session_store.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  final store = await GpsSessionStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: args[0],
  );
  await store.db.transaction((tx) async {
    await tx.insert('points', {
      'session_id': args[1],
      'sequence': 2,
      'timestamp_us': 123,
      'payload': 'uncommitted process crash',
    });
    // Abrupt process exit: no transaction finally, db.close or onDestroy.
    exit(73);
  });
}
