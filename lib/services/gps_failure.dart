import 'dart:developer' as developer;
import 'package:sqflite_common/sqlite_api.dart';

enum GpsErrorCode {
  sqliteOpen,
  sqliteRead,
  sqliteWrite,
  recovery,
  legacyRecovery,
  gpsUnavailable,
  serviceStart,
  serviceStop,
  queueCapacity,
}

class GpsFailure extends StateError {
  GpsFailure(this.code, {this.databaseCode}) : super(code.name);
  final GpsErrorCode code;
  final int? databaseCode;
  static GpsFailure fromId(String id) {
    for (final code in GpsErrorCode.values) {
      final failure = GpsFailure(code);
      if (failure.id == id) return failure;
    }
    // Compatibility with already stored safe codes. No raw text displayed.
    return GpsFailure(
      id == 'gps_write_failed'
          ? GpsErrorCode.sqliteWrite
          : GpsErrorCode.recovery,
    );
  }

  String get id => switch (code) {
    GpsErrorCode.sqliteOpen => 'GPS_DB_OPEN',
    GpsErrorCode.sqliteRead => 'GPS_DB_READ',
    GpsErrorCode.sqliteWrite => 'GPS_DB_WRITE',
    GpsErrorCode.recovery => 'GPS_RECOVERY',
    GpsErrorCode.legacyRecovery => 'GPS_LEGACY_RECOVERY',
    GpsErrorCode.gpsUnavailable => 'GPS_SAMPLE_UNAVAILABLE',
    GpsErrorCode.serviceStart => 'GPS_SERVICE_START',
    GpsErrorCode.serviceStop => 'GPS_SERVICE_STOP',
    GpsErrorCode.queueCapacity => 'GPS_QUEUE_LIMIT',
  };
  String get description => switch (code) {
    GpsErrorCode.sqliteOpen =>
      'GPS deposu açılamadı. Kayıtlar silinmedi; yeni sürüş başlatılamaz.',
    GpsErrorCode.sqliteRead =>
      'GPS kayıtları okunamadı. Mevcut sürüş durumu belirsiz; kayıtlar korunuyor.',
    GpsErrorCode.sqliteWrite =>
      'GPS kalıcı yazması aksadı. Bekleyen örnek tekrar denenecek.',
    GpsErrorCode.recovery =>
      'Sürüş kurtarılamadı. Kayıtlar korunuyor; güvenli bölümlere dönebilirsin.',
    GpsErrorCode.legacyRecovery =>
      'Eski sürümden olası sürüş bulundu. SQLite sürüşü olarak devam ettirilmedi.',
    GpsErrorCode.gpsUnavailable =>
      'GPS bekleniyor. Sürüş korunuyor; konum kullanılabilir olunca kayıt devam eder.',
    GpsErrorCode.serviceStart =>
      'GPS servisi başlatılamadı. Mevcut session korunuyor.',
    GpsErrorCode.serviceStop =>
      'Sürüş güvenle durdurulamadı. Mevcut kayıtlar korunuyor.',
    GpsErrorCode.queueCapacity =>
      'Depolama yazması durmuş ve GPS kuyruğu dolmuş. Yeni örnekler kaydedilemedi; yer açıp kurtarma durumunu kontrol et.',
  };
  static GpsFailure from(Object error, GpsErrorCode fallback) =>
      error is GpsFailure
      ? error
      : GpsFailure(
          fallback,
          databaseCode: error is DatabaseException
              ? error.getResultCode()
              : null,
        );
  void report(String operation) {
    // Never pass raw exception/SQL/stack: they may contain coordinates or paths.
    developer.log(
      'operation=$operation code=$id db_code=${databaseCode ?? 'unknown'}',
      name: 'DriveItGps',
    );
  }
}

Future<T> gpsRead<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    final failure = GpsFailure.from(error, GpsErrorCode.sqliteRead);
    failure.report('read');
    throw failure;
  }
}

Future<T> gpsWrite<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    final failure = GpsFailure.from(error, GpsErrorCode.sqliteWrite);
    failure.report('write');
    throw failure;
  }
}
