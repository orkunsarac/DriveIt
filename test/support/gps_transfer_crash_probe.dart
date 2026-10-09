import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/services/gps_session_store.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/gps_session_transfer.dart';
import 'package:driveit_project/services/drive_telemetry_storage_service.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  Hive.init(args[0]);
  Hive.registerAdapter(DriveSessionAdapter());
  Hive.registerAdapter(RoutePointAdapter());
  DriveTelemetryHive.registerAdapters(Hive);
  await Hive.openBox<DriveSession>('drives');
  await DriveTelemetryHive.openBox(Hive);
  final store = await GpsSessionStore.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${args[0]}/journal.db',
  );
  final id = args[1];
  final phase = args[2];
  final manifest = Map<String, dynamic>.from(
    jsonDecode(await File('${args[0]}/manifest.json').readAsString()) as Map,
  );
  await store.beginTransfer(id, id, jsonEncode(manifest));
  if (phase == 'intent') exit(73);
  final sink = GpsHiveTransferSink();
  await sink.writeTelemetry(
    id,
    (await store.read(id)).map((p) => p.point).toList(),
    {'sessionId': id, 'finalSequence': 4},
  );
  await sink.flush();
  if (phase == 'telemetry') exit(73);
  await sink.writeDrive(id, manifest);
  await sink.flush();
  if (phase == 'drive') exit(73);
  await GpsSessionTransfer(store, sink).save(id, manifest);
  exit(73);
}
