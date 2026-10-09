import 'package:sqflite/sqflite.dart';
import 'gps_session_store.dart';

/// sqflite is auto-registered on the foreground-task FlutterEngine as on the
/// main engine. No Activity channel or UI isolate is required for acquisition.
Future<GpsSessionStore> openGpsJournal() =>
    GpsSessionStore.open(factory: databaseFactory);
