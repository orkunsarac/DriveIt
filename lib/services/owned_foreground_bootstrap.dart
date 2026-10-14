import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../config/local_ownership_gate.dart';
import 'gps_session_store.dart';
import 'gps_session_ownership.dart';
import 'drive_source_provenance.dart';

/// Persistable descriptor for the CONTROLLED TEST journal only. Native isolate
/// restart opens the same journal/sidecar; it never initializes/reads Auth.
class OwnedForegroundBootstrap {
  OwnedForegroundBootstrap._(this.root, {this.handoff});
  final String root;
  final OwnedForegroundHandoff? handoff;
  static const preferenceKey = 'driveit_controlled_owner_foreground_v1';
  String get journalPath => '$root/gps.db';
  String get sidecarPath => '$root/owners.db';
  String get journalId => sha256.convert(utf8.encode(root)).toString();
  String encode() => jsonEncode({
    'version': 1,
    'root': root,
    'journalId': journalId,
    if (handoff != null) 'handoff': handoff!.toMap(),
  });

  /// Creates the immutable descriptor handed to the headless service. It is
  /// derived only from the durable ready sidecar row, never from Auth in the
  /// isolate. The caller must still hold a current owner lifecycle lease.
  OwnedForegroundBootstrap forSession(
    GpsSession session,
    GpsOwnershipManifest binding, {
    required int ownerEpoch,
  }) {
    final provenance = binding.provenance;
    if (ownerEpoch < 0 ||
        binding.state != 'ready' ||
        binding.journalId != journalId ||
        binding.sessionId != session.id ||
        binding.owner.kind == GpsOwnerKind.legacyUnassigned ||
        !provenance.isProven) {
      throw StateError('GPS handoff evidence incomplete');
    }
    return OwnedForegroundBootstrap._(
      root,
      handoff: OwnedForegroundHandoff(
        sessionId: session.id,
        reservationId: binding.reservationId,
        ownerKind: binding.owner.wireKind,
        ownerUserId: binding.owner.userId,
        ownerGuestIdentity: binding.owner.guestIdentity,
        targetStore: binding.targetStore,
        sourceIdentity: provenance.sourceIdentity!,
        sourceIdentityVersion: provenance.identityVersion!,
        sourceNamespace: provenance.sourceNamespace!,
        ownerEpoch: ownerEpoch,
      ),
    );
  }

  static Future<OwnedForegroundBootstrap> prepareForTesting(
    Directory directory,
  ) async {
    if (!LocalOwnershipGate.syntheticRuntimeAvailable) {
      throw StateError(
        'Controlled GPS unavailable outside isolated test build',
      );
    }
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

  /// Opens the real application's owner journal under its private Android
  /// support directory. The root is fixed by the application; callers cannot
  /// supply arbitrary paths or share the legacy GPS journal.
  static Future<OwnedForegroundBootstrap> prepareForProduction() async {
    if (!LocalOwnershipGate.localProductionActivation ||
        !LocalOwnershipGate.production.enabled) {
      throw StateError('Local production owner runtime is not enabled');
    }
    final support = await getApplicationSupportDirectory();
    final supportRoot = await support.resolveSymbolicLinks();
    final directory = Directory(
      '$supportRoot${Platform.pathSeparator}driveit_owner_runtime_v1',
    );
    await _ensurePrivateDirectory(directory);
    final real = await directory.resolveSymbolicLinks();
    if (!_isDirectChild(real, supportRoot, 'driveit_owner_runtime_v1')) {
      throw StateError('Production GPS root is outside app support storage');
    }
    final marker = File('$real/production_owner_runtime_v1');
    if (await marker.exists()) {
      if (await marker.readAsString() != 'production_owner_runtime_v1') {
        throw StateError('Production GPS root marker conflict');
      }
    } else {
      await marker.writeAsString('production_owner_runtime_v1', flush: true);
    }
    return OwnedForegroundBootstrap._(real);
  }

  static Future<OwnedForegroundBootstrap> decode(String value) async {
    final row = jsonDecode(value);
    if (row is! Map || row['version'] != 1 || row['root'] is! String) {
      throw StateError('GPS descriptor invalid');
    }
    final dir = Directory(row['root']);
    final real = await dir.resolveSymbolicLinks();
    if (real != row['root']) throw StateError('GPS descriptor root unverified');
    if (LocalOwnershipGate.syntheticRuntimeAvailable &&
        await _hasMarker(real, 'controlled_owner_test_v1')) {
      if (!real
          .replaceAll('\\', '/')
          .split('/')
          .last
          .startsWith('driveit_owner_test_')) {
        throw StateError('Synthetic GPS root required');
      }
    } else if (LocalOwnershipGate.localProductionActivation &&
        await _hasMarker(real, 'production_owner_runtime_v1')) {
      final support = await getApplicationSupportDirectory();
      final supportRoot = await support.resolveSymbolicLinks();
      if (!_isDirectChild(real, supportRoot, 'driveit_owner_runtime_v1')) {
        throw StateError('Production GPS root is outside app support storage');
      }
    } else {
      throw StateError('GPS descriptor root unverified');
    }
    final handoffRow = row['handoff'];
    final handoff = handoffRow == null
        ? null
        : OwnedForegroundHandoff.fromMap(handoffRow);
    final result = OwnedForegroundBootstrap._(real, handoff: handoff);
    if (result.journalId != row['journalId']) {
      throw StateError('GPS journal identity conflict');
    }
    return result;
  }

  static Future<void> _ensurePrivateDirectory(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw StateError('GPS root cannot be a symbolic link');
    }
    if (type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
    } else if (type != FileSystemEntityType.directory) {
      throw StateError('GPS root is not a directory');
    }
  }

  static Future<bool> _hasMarker(String root, String marker) async {
    final file = File('$root/$marker');
    return await file.exists() && await file.readAsString() == marker;
  }

  static bool _isDirectChild(String path, String parent, String name) {
    final separator = Platform.pathSeparator;
    final expected = '$parent$separator$name';
    return Platform.isWindows
        ? path.toLowerCase() == expected.toLowerCase()
        : path == expected;
  }

  Future<GpsSessionStore> openJournal(DatabaseFactory factory) =>
      GpsSessionStore.open(factory: factory, path: journalPath);
  Future<GpsOwnershipStore> openOwnership(DatabaseFactory factory) =>
      GpsOwnershipStore.open(factory: factory, path: sidecarPath);
  Future<GpsOwnershipManifest> verify(
    DatabaseFactory factory,
    String sessionId,
  ) async {
    if (handoff != null) return verifyHandoff(factory, sessionId);
    final sidecar = await openOwnership(factory);
    try {
      final journal = await openJournal(factory);
      final GpsOwnershipManifest? binding;
      try {
        binding = await sidecar.recoverBinding(
          journalId,
          sessionId,
          journalSessionExists: await journal.session(sessionId) != null,
        );
      } finally {
        await journal.close();
      }
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

  /// Strict callback-side verification. Every identity field in the durable
  /// task descriptor must match the sidecar evidence before GPS subscribes.
  Future<GpsOwnershipManifest> verifyHandoff(
    DatabaseFactory factory,
    String activeSessionId,
  ) async {
    final expected = handoff;
    if (expected == null || expected.sessionId != activeSessionId) {
      throw StateError('GPS handoff session mismatch');
    }
    final binding = await _recoverBinding(factory, activeSessionId);
    final provenance = binding.provenance;
    if (binding.state != 'ready' ||
        binding.reservationId != expected.reservationId ||
        binding.journalId != journalId ||
        binding.sessionId != expected.sessionId ||
        binding.owner.wireKind != expected.ownerKind ||
        binding.owner.userId != expected.ownerUserId ||
        binding.targetStore != expected.targetStore ||
        !provenance.isProven ||
        provenance.sourceIdentity != expected.sourceIdentity ||
        provenance.identityVersion != expected.sourceIdentityVersion ||
        provenance.sourceNamespace != expected.sourceNamespace) {
      throw StateError('GPS handoff sidecar conflict');
    }
    return binding;
  }

  Future<GpsOwnershipManifest> _recoverBinding(
    DatabaseFactory factory,
    String sessionId,
  ) async {
    final sidecar = await openOwnership(factory);
    try {
      final journal = await openJournal(factory);
      try {
        final binding = await sidecar.recoverBinding(
          journalId,
          sessionId,
          journalSessionExists: await journal.session(sessionId) != null,
        );
        if (binding == null ||
            binding.state != 'ready' ||
            binding.owner.kind == GpsOwnerKind.legacyUnassigned) {
          throw StateError('Native GPS ownership unverified');
        }
        return binding;
      } finally {
        await journal.close();
      }
    } finally {
      await sidecar.close();
    }
  }
}

/// Persisted with the foreground-task plugin data. ownerEpoch is an audit
/// token from the UI lease; on a process restart it is not compared with a new
/// in-memory epoch. The immutable owner/session/source tuple is checked against
/// the sidecar instead.
class OwnedForegroundHandoff {
  const OwnedForegroundHandoff({
    required this.sessionId,
    required this.reservationId,
    required this.ownerKind,
    required this.ownerUserId,
    this.ownerGuestIdentity,
    required this.targetStore,
    required this.sourceIdentity,
    required this.sourceIdentityVersion,
    required this.sourceNamespace,
    required this.ownerEpoch,
  });
  final String sessionId;
  final String reservationId;
  final String ownerKind;
  final String? ownerUserId;
  final String? ownerGuestIdentity;
  final String targetStore;
  final String sourceIdentity;
  final int sourceIdentityVersion;
  final String sourceNamespace;
  final int ownerEpoch;

  Map<String, Object?> toMap() => {
    'version': 1,
    'sessionId': sessionId,
    'reservationId': reservationId,
    'ownerKind': ownerKind,
    'ownerUserId': ownerUserId,
    'ownerGuestIdentity': ownerGuestIdentity,
    'targetStore': targetStore,
    'sourceIdentity': sourceIdentity,
    'sourceIdentityVersion': sourceIdentityVersion,
    'sourceNamespace': sourceNamespace,
    'ownerEpoch': ownerEpoch,
  };

  factory OwnedForegroundHandoff.fromMap(Object? value) {
    const uuid =
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';
    if (value is! Map ||
        value['version'] != 1 ||
        value['sessionId'] is! String ||
        !(value['sessionId'] as String).contains(RegExp(uuid)) ||
        value['reservationId'] is! String ||
        !(value['reservationId'] as String).contains(RegExp(uuid)) ||
        value['ownerKind'] is! String ||
        value['targetStore'] is! String ||
        value['sourceIdentity'] is! String ||
        value['sourceIdentityVersion'] != 1 ||
        value['sourceNamespace'] != 'drive_source_v1' ||
        value['ownerEpoch'] is! int) {
      throw StateError('GPS handoff descriptor invalid');
    }
    final kind = value['ownerKind'] as String;
    final userId = value['ownerUserId'] as String?;
    final guestIdentity = value['ownerGuestIdentity'] as String?;
    final owner = switch (kind) {
      'guest' when userId == null && guestIdentity == null =>
        const GpsOwner.guest(),
      'guest' when userId == null && guestIdentity != null =>
        GpsOwner.deviceGuest(guestIdentity),
      'account' when userId != null && guestIdentity == null =>
        GpsOwner.account(userId),
      _ => throw StateError('GPS handoff owner invalid'),
    };
    final targetStore = value['targetStore'] as String;
    if (owner.targetStore != targetStore || (value['ownerEpoch'] as int) < 0) {
      throw StateError('GPS handoff scope invalid');
    }
    final provenance = DriveSourceProvenance.proven(
      sourceIdentity: value['sourceIdentity'] as String,
      ownerScope: targetStore,
      identityVersion: 1,
    );
    if (!provenance.isProven) throw StateError('GPS handoff source invalid');
    return OwnedForegroundHandoff(
      sessionId: value['sessionId'] as String,
      reservationId: value['reservationId'] as String,
      ownerKind: kind,
      ownerUserId: userId,
      ownerGuestIdentity: guestIdentity,
      targetStore: targetStore,
      sourceIdentity: provenance.sourceIdentity!,
      sourceIdentityVersion: 1,
      sourceNamespace: 'drive_source_v1',
      ownerEpoch: value['ownerEpoch'] as int,
    );
  }
}
