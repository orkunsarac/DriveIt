// Hive's independent binary codec is confined here, as in scoped storage.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import '../config/local_ownership_gate.dart';
import '../models/drive_session.dart';
import '../models/route_point.dart';
import 'legacy_source_writer_fence.dart';
import 'local_owner_lifecycle.dart';

/// Only completed Hive rows, never journal samples or an import workspace.
/// Caller supplies an already-open box: this reader cannot migrate/open/write it.
class SavedDriveArchiveSource {
  SavedDriveArchiveSource(this._box);
  final Box<DriveSession> _box;
  Map<String, Uint8List> capture() {
    if (!_box.isOpen) throw StateError('archive_source_closed');
    final result = <String, Uint8List>{};
    for (final key in _box.keys) {
      final drive = _box.get(key);
      if (key is! String || drive == null || drive.id != key) {
        throw StateError('archive_source_identity');
      }
      result[key] = _encode(drive);
    }
    return result;
  }
}

HiveImpl _registry() => HiveImpl()
  ..registerAdapter(DriveSessionAdapter())
  ..registerAdapter(RoutePointAdapter());
Uint8List _encode(DriveSession value) =>
    (BinaryWriterImpl(_registry())..write(value)).toBytes();
DriveSession _decode(Uint8List bytes) {
  final value = BinaryReaderImpl(bytes, _registry()).read();
  if (value is! DriveSession) throw StateError('archive_invalid_record');
  if (value.id.isEmpty ||
      !value.distance.isFinite ||
      !value.averageSpeed.isFinite ||
      !value.maxSpeed.isFinite ||
      value.durationSeconds < 0 ||
      value.route.any(
        (p) =>
            !p.latitude.isFinite ||
            !p.longitude.isFinite ||
            p.latitude.abs() > 90 ||
            p.longitude.abs() > 180,
      )) {
    throw StateError('archive_invalid_record');
  }
  return value;
}

/// Detached binary snapshot. No attached source objects/boxes, image file access,
/// computed scores, owner repositories or write services reach archive screens.
/// Binary encoding preserves legacy RoutePoint fields without interpreting them.
class DeviceDriveArchiveSnapshot {
  DeviceDriveArchiveSnapshot._(this._rows, this.fingerprint);
  final Map<String, String> _rows;
  final String fingerprint;
  static String _digest(Map<String, String> rows) {
    final sorted = {for (final id in rows.keys.toList()..sort()) id: rows[id]};
    return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
  }

  /// Empty archive is a valid, honest result when this installation has never
  /// had the legacy Hive drives file. It does not create that source file.
  factory DeviceDriveArchiveSnapshot.empty() =>
      DeviceDriveArchiveSnapshot._(const {}, _digest(const {}));

  factory DeviceDriveArchiveSnapshot.restore(String serialized) {
    final value = jsonDecode(serialized) as Map<String, dynamic>;
    if (value['version'] != 1 ||
        value['rows'] is! Map ||
        value['fingerprint'] is! String) {
      throw StateError('archive_invalid_snapshot');
    }
    final rows = Map<String, String>.from(value['rows'] as Map);
    if (_digest(rows) != value['fingerprint']) {
      throw StateError('archive_snapshot_checksum');
    }
    for (final row in rows.entries) {
      if (_decode(base64Decode(row.value)).id != row.key) {
        throw StateError('archive_snapshot_identity');
      }
    }
    return DeviceDriveArchiveSnapshot._(Map.unmodifiable(rows), _digest(rows));
  }
  String serialize() =>
      jsonEncode({'version': 1, 'rows': _rows, 'fingerprint': fingerprint});
  DriveSession _read(String id) {
    final bytes = _rows[id];
    if (bytes == null) throw StateError('archive_drive_missing');
    return _decode(base64Decode(bytes));
  }

  List<DriveSession> _all() => _rows.keys.map(_read).toList()
    ..sort((a, b) {
      final order = b.date.compareTo(a.date);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });

  static Future<DeviceDriveArchiveSnapshot> prepare({
    required SavedDriveArchiveSource source,
    required RegisteredSourceWriterFence writers,
    required Future<Set<String>> Function() unfinishedDriveIds,
  }) async {
    writers.requireRegistered();
    // A failed pause must not yield any snapshot. Fence owns partial-pause cleanup.
    await writers.pauseAndDrain();
    try {
      final unfinished = await unfinishedDriveIds();
      if (unfinished.isNotEmpty) throw StateError('archive_recording_pending');
      final rows = source.capture().map(
        (id, bytes) => MapEntry(id, base64Encode(bytes)),
      );
      final snapshot = DeviceDriveArchiveSnapshot.restore(
        jsonEncode({'version': 1, 'rows': rows, 'fingerprint': _digest(rows)}),
      );
      if (_digest(
                source.capture().map(
                  (id, bytes) => MapEntry(id, base64Encode(bytes)),
                ),
              ) !=
              snapshot.fingerprint ||
          (await unfinishedDriveIds()).isNotEmpty) {
        throw StateError('archive_source_changed');
      }
      return snapshot;
    } finally {
      await writers.resume();
    }
  }

  /// Captures the already-existing legacy source for the production read-only
  /// archive. The owner operation serializes account changes around this call;
  /// [sourceIsQuiescent] additionally rejects an active/recoverable GPS writer.
  /// Two byte-for-byte captures plus the before/after quiescence check prevent
  /// a partial snapshot from becoming visible. This method performs no Hive
  /// put/delete, migration, import, or owner-store write.
  static Future<DeviceDriveArchiveSnapshot> prepareReadOnly({
    required SavedDriveArchiveSource source,
    required Future<bool> Function() sourceIsQuiescent,
  }) async {
    if (!await sourceIsQuiescent()) {
      throw StateError('archive_source_busy');
    }
    Map<String, String> capture() =>
        source.capture().map((id, bytes) => MapEntry(id, base64Encode(bytes)));
    final first = capture();
    final second = capture();
    if (!await sourceIsQuiescent() || _digest(first) != _digest(second)) {
      throw StateError('archive_source_changed');
    }
    return DeviceDriveArchiveSnapshot.restore(
      jsonEncode({'version': 1, 'rows': first, 'fingerprint': _digest(first)}),
    );
  }
}

/// Reads only the existing legacy `drives.hive` in the app documents folder.
/// A missing file yields an empty snapshot without opening/creating a Hive box.
/// The isolated Hive registry is closed after capture; no app-global box or
/// owner-scoped repository is exposed to archive screens.
Future<DeviceDriveArchiveSnapshot> loadLegacyDeviceDriveArchiveSnapshot({
  required Future<bool> Function() sourceIsQuiescent,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final sourceFile = File(
    '${documents.path}${Platform.pathSeparator}drives.hive',
  );
  if (!await sourceFile.exists()) return DeviceDriveArchiveSnapshot.empty();
  if (!await sourceIsQuiescent()) throw StateError('archive_source_busy');

  final hive = HiveImpl()..init(documents.path);
  hive
    ..registerAdapter(DriveSessionAdapter())
    ..registerAdapter(RoutePointAdapter());
  try {
    final box = await hive.openBox<DriveSession>('drives');
    return await DeviceDriveArchiveSnapshot.prepareReadOnly(
      source: SavedDriveArchiveSource(box),
      sourceIsQuiescent: sourceIsQuiescent,
    );
  } finally {
    await hive.close();
  }
}

/// Device authentication is independent of Supabase identity and data ownership.
abstract interface class DeviceArchiveAuthorizer {
  Future<bool> verifyDeviceAccess();
}

class DeviceDriveArchiveAccess {
  DeviceDriveArchiveAccess({
    required this.gate,
    required this.snapshot,
    required this.authorizer,
    this.accessLifetime = const Duration(minutes: 2),
  });
  final LocalOwnershipGate gate;
  final DeviceDriveArchiveSnapshot snapshot;
  final DeviceArchiveAuthorizer authorizer;
  final Duration accessLifetime;
  bool _opening = false;
  Future<DeviceDriveArchiveContext> open(LocalOwnerLease lease) async {
    if (!gate.enabled) throw StateError('archive_disabled');
    if (_opening || accessLifetime <= Duration.zero) {
      throw StateError('archive_access_busy');
    }
    _opening = true;
    final foreground = _ArchiveAuthenticationLifecycle();
    try {
      lease.requireCurrent();
      foreground.requireForeground();
      if (!await authorizer.verifyDeviceAccess()) {
        throw StateError('archive_device_authorization_required');
      }
      lease.requireCurrent();
      // A native prompt may temporarily remove window focus (inactive), but
      // paused/hidden/detached during a challenge irreversibly rejects its result.
      await foreground.waitForForeground();
      lease.requireCurrent();
      foreground.requireForeground();
      return DeviceDriveArchiveContext._(snapshot, lease, accessLifetime);
    } finally {
      foreground.close();
      _opening = false;
    }
  }
}

/// No credential-prompt background exemption. A lost app foreground rejects
/// the pending grant even if the device provider later returns true.
class _ArchiveAuthenticationLifecycle with WidgetsBindingObserver {
  _ArchiveAuthenticationLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    _diagnostic('observer_added');
  }
  bool _backgrounded = false;
  Completer<void>? _resumed;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void requireForeground() {
    if (_backgrounded || !_foreground) {
      _diagnostic('foreground_rejected');
      throw StateError('archive_not_foreground');
    }
  }

  Future<void> waitForForeground() async {
    if (_backgrounded) throw StateError('archive_not_foreground');
    if (_foreground) return;
    _resumed = Completer<void>();
    await _resumed!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw StateError('archive_foreground_timeout');
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _diagnostic('lifecycle_${state.name}');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _backgrounded = true;
    }
    if ((state == AppLifecycleState.resumed || _backgrounded) &&
        _resumed?.isCompleted == false) {
      _resumed!.complete();
    }
  }

  void _diagnostic(String event) {
    const releaseAcceptance = bool.fromEnvironment(
      'DRIVEIT_RELEASE_ACCEPTANCE',
    );
    const isolatedTest = bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');
    if (!kReleaseMode || !releaseAcceptance || !isolatedTest) return;
    debugPrint(
      'DRIVEIT_ARCHIVE_LIFECYCLE:$event:'
      'flutter=${WidgetsBinding.instance.lifecycleState?.name ?? "null"}:'
      'backgrounded=$_backgrounded',
    );
  }

  void close() => WidgetsBinding.instance.removeObserver(this);
}

/// ID lookup requires this separate revocable capability, not an owner/drive ID.
class DeviceDriveArchiveContext extends ChangeNotifier
    with WidgetsBindingObserver {
  DeviceDriveArchiveContext._(this._snapshot, this._lease, this._lifetime) {
    _lease.changes.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _clock.start();
    _expiry = Timer(_lifetime, _revoke);
  }
  final DeviceDriveArchiveSnapshot _snapshot;
  final LocalOwnerLease _lease;
  bool _closed = false;
  bool _revoked = false;
  final Duration _lifetime;
  final Stopwatch _clock = Stopwatch();
  late final Timer _expiry;
  bool get isCurrent =>
      !_closed && !_revoked && _lease.isCurrent && _clock.elapsed < _lifetime;
  void _revoke() {
    if (_closed || _revoked) return;
    _revoked = true;
    _expiry.cancel();
    notifyListeners();
  }

  void _changed() {
    if (!_lease.isCurrent) _revoke();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _revoke();
  }

  void _require() {
    if (!isCurrent) throw StateError('archive_access_revoked');
  }

  List<DriveSession> drives() {
    _require();
    return _snapshot._all();
  }

  DriveSession drive(String id) {
    _require();
    return _snapshot._read(id);
  }

  @override
  void dispose() {
    _lease.changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _expiry.cancel();
    _clock.stop();
    _closed = true;
    super.dispose();
  }
}
