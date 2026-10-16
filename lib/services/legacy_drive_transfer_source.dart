// Isolated Hive registry, separate from the read-only archive API.
// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/drive_session.dart';
import '../models/route_point.dart';
import 'account_drive_transfer.dart';

class LegacyHiveDriveTransferSource implements LegacyTransferSource {
  LegacyHiveDriveTransferSource._(this._hive, this._box, this._requireAccess);
  final HiveImpl _hive;
  final LazyBox<DriveSession> _box;
  final void Function() _requireAccess;

  static Future<bool> hasRecords({Directory? documentsDirectory}) async {
    final documents =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    if (!await File(
      '${documents.path}${Platform.pathSeparator}drives.hive',
    ).exists()) {
      return false;
    }
    final hive = HiveImpl()..init(documents.path);
    hive
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    try {
      return (await hive.openLazyBox<DriveSession>(
        'drives',
        crashRecovery: false,
        compactionStrategy: (_, _) => false,
      )).isNotEmpty;
    } finally {
      await hive.close();
    }
  }

  static Future<LegacyTransferSource> open({
    required void Function() requireAccess,
    Directory? documentsDirectory,
  }) async {
    requireAccess();
    final documents =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    if (!await File(
      '${documents.path}${Platform.pathSeparator}drives.hive',
    ).exists()) {
      throw StateError('archive_source_missing');
    }
    requireAccess();
    final hive = HiveImpl()..init(documents.path);
    hive
      ..registerAdapter(DriveSessionAdapter())
      ..registerAdapter(RoutePointAdapter());
    try {
      final box = await hive.openLazyBox<DriveSession>(
        'drives',
        crashRecovery: false,
        compactionStrategy: (_, _) => false,
      );
      requireAccess();
      return LegacyHiveDriveTransferSource._(hive, box, requireAccess);
    } catch (_) {
      await hive.close();
      rethrow;
    }
  }

  String _fingerprint(DriveSession drive) => sha256
      .convert((BinaryWriterImpl(_hive)..write(drive)).toBytes())
      .toString();
  @override
  Future<List<LegacyTransferRow>> read() async {
    _requireAccess();
    final result = <LegacyTransferRow>[];
    for (final key in _box.keys.toList()) {
      _requireAccess();
      if (key is! String) {
        result.add(
          LegacyTransferRow('unsupported-key:${result.length}', null, null),
        );
        continue;
      }
      DriveSession? drive;
      try {
        drive = await _box.get(key);
      } catch (_) {
        /* report unreadable, never delete */
      }
      _requireAccess();
      if (drive?.id != key) drive = null;
      result.add(
        LegacyTransferRow(
          key,
          drive,
          drive == null ? null : _fingerprint(drive),
        ),
      );
    }
    return result;
  }

  @override
  Future<void> remove(LegacyTransferRow expected) async {
    _requireAccess();
    final drive = await _box.get(expected.key);
    _requireAccess();
    if (drive == null ||
        expected.fingerprint == null ||
        _fingerprint(drive) != expected.fingerprint) {
      throw StateError('archive_source_changed');
    }
    await _box.delete(expected.key);
    await _box.flush();
    _requireAccess();
    if (_box.containsKey(expected.key)) {
      throw StateError('archive_cleanup_not_durable');
    }
  }

  @override
  Future<void> close() => _hive.close();
}
