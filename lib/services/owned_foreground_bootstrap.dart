import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'gps_session_store.dart';
import 'gps_session_ownership.dart';

/// Persistable descriptor for the CONTROLLED TEST journal only. Native isolate
/// restart opens the same journal/sidecar; it never initializes/reads Auth.
class OwnedForegroundBootstrap {
  OwnedForegroundBootstrap._(this.root);
  final String root;
  static const preferenceKey = 'driveit_controlled_owner_foreground_v1';
  String get journalPath => '$root/gps.db';
  String get sidecarPath => '$root/owners.db';
  String get journalId => sha256.convert(utf8.encode(root)).toString();
  String encode() =>
      jsonEncode({'version': 1, 'root': root, 'journalId': journalId});

  static Future<OwnedForegroundBootstrap> prepareForTesting(
    Directory directory,
  ) async {
    if (!kDebugMode) throw StateError('Controlled GPS unavailable in release');
    if (!directory.absolute.path
        .replaceAll('\\', '/')
        .split('/')
        .last
        .startsWith('driveit_owner_test_')) {
      throw StateError('Synthetic GPS root required');
    }
    await directory.create(recursive: true);
    final root = await directory.resolveSymbolicLinks();
    if (!root
        .replaceAll('\\', '/')
        .split('/')
        .last
        .startsWith('driveit_owner_test_')) {
      throw StateError('Synthetic GPS root required');
    }
    final marker = File('$root/controlled_owner_test_v1');
    if (!await marker.exists()) {
      await marker.writeAsString('controlled_owner_test_v1', flush: true);
    }
    return decode(
      jsonEncode({
        'version': 1,
        'root': root,
        'journalId': sha256.convert(utf8.encode(root)).toString(),
      }),
    );
  }

  static Future<OwnedForegroundBootstrap> decode(String value) async {
    if (!kDebugMode) throw StateError('Controlled GPS unavailable');
    final row = jsonDecode(value);
    if (row is! Map || row['version'] != 1 || row['root'] is! String) {
      throw StateError('GPS descriptor invalid');
    }
    final dir = Directory(row['root']);
    final real = await dir.resolveSymbolicLinks();
    if (real != row['root'] ||
        !real
            .replaceAll('\\', '/')
            .split('/')
            .last
            .startsWith('driveit_owner_test_') ||
        await File('$real/controlled_owner_test_v1').readAsString() !=
            'controlled_owner_test_v1') {
      throw StateError('GPS descriptor root unverified');
    }
    final result = OwnedForegroundBootstrap._(real);
    if (result.journalId != row['journalId']) {
      throw StateError('GPS journal identity conflict');
    }
    return result;
  }

  Future<GpsSessionStore> openJournal(DatabaseFactory factory) =>
      GpsSessionStore.open(factory: factory, path: journalPath);
  Future<GpsOwnershipStore> openOwnership(DatabaseFactory factory) =>
      GpsOwnershipStore.open(factory: factory, path: sidecarPath);
  Future<GpsOwnershipManifest> verify(
    DatabaseFactory factory,
    String sessionId,
  ) async {
    final sidecar = await openOwnership(factory);
    try {
      final binding = await sidecar.get(journalId, sessionId);
      if (binding == null ||
          binding.state != 'ready' ||
          binding.owner.kind == GpsOwnerKind.legacyUnassigned) {
        throw StateError('Native GPS ownership unverified');
      }
      return binding;
    } finally {
      await sidecar.close();
    }
  }
}
