import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'drive_source_provenance.dart';

enum GpsOwnerKind { guest, account, legacyUnassigned }

/// Local scope, not an authorization token. Never inferred from profile names.
class GpsOwner {
  const GpsOwner.guest()
    : kind = GpsOwnerKind.guest,
      userId = null,
      guestIdentity = null;
  GpsOwner.deviceGuest(String id)
    : kind = GpsOwnerKind.guest,
      userId = null,
      guestIdentity = id {
    if (!_isCanonicalUuid(id)) {
      throw ArgumentError('Device guest identity requires a canonical UUID');
    }
  }
  const GpsOwner.legacy()
    : kind = GpsOwnerKind.legacyUnassigned,
      userId = null,
      guestIdentity = null;
  GpsOwner.account(String id)
    : kind = GpsOwnerKind.account,
      userId = id,
      guestIdentity = null {
    if (!_isCanonicalUuid(id)) {
      throw ArgumentError('Account ownership requires a canonical UUID');
    }
  }
  final GpsOwnerKind kind;
  final String? userId;
  final String? guestIdentity;
  String get wireKind => switch (kind) {
    GpsOwnerKind.guest => 'guest',
    GpsOwnerKind.account => 'account',
    GpsOwnerKind.legacyUnassigned => 'legacy_unassigned',
  };
  String get targetStore => jsonEncode([
    'local_account_store_v1',
    wireKind,
    kind == GpsOwnerKind.guest ? guestIdentity : userId,
  ]);
  String recordKey(String localId) => jsonEncode([targetStore, localId]);
  static GpsOwner fromRow(Map<String, Object?> row) => switch (row['kind']) {
    'guest' when row['user_id'] == null => _guestFromRow(row),
    'account' => GpsOwner.account(row['user_id'] as String),
    'legacy_unassigned' when row['user_id'] == null => const GpsOwner.legacy(),
    _ => throw StateError('Unsupported ownership scope'),
  };

  static GpsOwner _guestFromRow(Map<String, Object?> row) {
    final target = row['target_store'];
    if (target is String) {
      final decoded = jsonDecode(target);
      if (decoded is List &&
          decoded.length == 3 &&
          decoded[0] == 'local_account_store_v1' &&
          decoded[1] == 'guest' &&
          decoded[2] is String) {
        return GpsOwner.deviceGuest(decoded[2] as String);
      }
    }
    return const GpsOwner.guest();
  }

  static bool _isCanonicalUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(value);
}

class GpsOwnershipManifest {
  GpsOwnershipManifest(this.row) {
    if (row['version'] != 1 || row['target_store'] != owner.targetStore) {
      throw StateError('Ownership manifest conflict');
    }
  }
  final Map<String, Object?> row;
  GpsOwner get owner => GpsOwner.fromRow(row);
  String get reservationId => row['reservation_id'] as String;
  String get journalId => row['journal_id'] as String;
  String? get sessionId =>
      (row['session_id'] ?? row['planned_session_id']) as String?;
  String get state => row['state'] as String;
  String get targetStore => row['target_store'] as String;
  DriveSourceProvenance get provenance {
    final id = row['source_identity'] as String?;
    final version = row['source_identity_version'] as int?;
    if (id == null || version == null) {
      return DriveSourceProvenance.unproven(ownerScope: targetStore);
    }
    try {
      return DriveSourceProvenance.proven(
        sourceIdentity: id,
        ownerScope: targetStore,
        identityVersion: version,
      );
    } on ArgumentError {
      return DriveSourceProvenance.conflict(
        ownerScope: targetStore,
        conflictCode: 'source_identity_invalid',
      );
    }
  }
}

/// Dormant sidecar. NOT opened by main, auth, task_handler or legacy transfer.
/// Separate WAL/FULL DB: no migration/alteration of the acquisition journal.
class GpsOwnershipStore {
  GpsOwnershipStore(this.db, {this.beforeCommit});
  final Database db;

  /// Fault seam for synthetic tests; invoked inside the SQLite transaction.
  final Future<void> Function(String stage)? beforeCommit;
  static Future<GpsOwnershipStore> open({
    required DatabaseFactory factory,
    required String path,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onConfigure: (db) async {
          final mode = await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=FULL');
          await db.rawQuery('PRAGMA busy_timeout=5000');
          final sync = await db.rawQuery('PRAGMA synchronous');
          if (mode.single.values.single.toString().toLowerCase() != 'wal' ||
              sync.single.values.single != 2) {
            throw StateError('Ownership durability unavailable');
          }
        },
        onCreate: (db, _) async {
          await db.execute(
            '''CREATE TABLE ownership (
          reservation_id TEXT PRIMARY KEY, version INTEGER NOT NULL CHECK(version=1),
          journal_id TEXT NOT NULL, session_id TEXT,
          kind TEXT NOT NULL CHECK(kind IN ('guest','account','legacy_unassigned')),
          user_id TEXT, target_store TEXT NOT NULL,
          state TEXT NOT NULL CHECK(state IN ('prepared','ready')),
          source_identity TEXT, source_identity_version INTEGER,
          planned_session_id TEXT,
          created_us INTEGER NOT NULL, updated_us INTEGER NOT NULL,
          UNIQUE(journal_id,session_id),
          CHECK((kind='account' AND user_id IS NOT NULL) OR (kind!='account' AND user_id IS NULL)),
          CHECK((state='prepared' AND session_id IS NULL) OR (state='ready' AND session_id IS NOT NULL)))''',
          );
          await db.execute(
            '''CREATE UNIQUE INDEX ownership_source_identity_unique
            ON ownership(source_identity) WHERE source_identity IS NOT NULL''',
          );
          await db.execute(
            '''CREATE UNIQUE INDEX ownership_planned_session_unique
            ON ownership(journal_id,planned_session_id)
            WHERE planned_session_id IS NOT NULL''',
          );
          await db.execute('''CREATE TABLE transfers (
          operation_id TEXT PRIMARY KEY, journal_id TEXT NOT NULL, session_id TEXT NOT NULL,
          target_store TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN ('intent','verified')),
          created_us INTEGER NOT NULL, verified_us INTEGER,
          UNIQUE(journal_id,session_id))''');
          await db.execute(
            '''CREATE TRIGGER ownership_immutable BEFORE UPDATE ON ownership
          WHEN NEW.reservation_id!=OLD.reservation_id OR NEW.journal_id!=OLD.journal_id
          OR NEW.kind!=OLD.kind OR NEW.user_id IS NOT OLD.user_id
          OR NEW.target_store!=OLD.target_store OR NEW.version!=OLD.version
          OR NEW.source_identity IS NOT OLD.source_identity
          OR NEW.source_identity_version IS NOT OLD.source_identity_version
          OR (OLD.planned_session_id IS NULL AND NEW.planned_session_id IS NOT NULL)
          OR (OLD.planned_session_id IS NOT NULL AND
              (NEW.state!='ready' OR NEW.session_id IS NOT OLD.planned_session_id
               OR NEW.planned_session_id IS NOT NULL))
          OR OLD.state='ready'
          BEGIN SELECT RAISE(ABORT,'Ownership is immutable'); END''',
          );
          for (final table in ['ownership', 'transfers']) {
            await db.execute(
              '''CREATE TRIGGER ${table}_no_delete BEFORE DELETE ON $table
            BEGIN SELECT RAISE(ABORT,'Ownership evidence is retained'); END''',
            );
          }
          await db.execute(
            '''CREATE TRIGGER transfer_immutable BEFORE UPDATE ON transfers
          WHEN NEW.operation_id!=OLD.operation_id OR NEW.journal_id!=OLD.journal_id
          OR NEW.session_id!=OLD.session_id OR NEW.target_store!=OLD.target_store
          OR OLD.state='verified'
          BEGIN SELECT RAISE(ABORT,'Transfer destination is immutable'); END''',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Historical reservations have no source-identity evidence and
            // deliberately remain NULL/unproven. Never derive IDs from keys.
            await db.execute(
              'ALTER TABLE ownership ADD COLUMN source_identity TEXT',
            );
            await db.execute(
              'ALTER TABLE ownership ADD COLUMN source_identity_version INTEGER',
            );
            await db.execute(
              '''CREATE UNIQUE INDEX ownership_source_identity_unique
              ON ownership(source_identity) WHERE source_identity IS NOT NULL''',
            );
            await db.execute('DROP TRIGGER IF EXISTS ownership_immutable');
            await db.execute(
              '''CREATE TRIGGER ownership_immutable BEFORE UPDATE ON ownership
              WHEN NEW.reservation_id!=OLD.reservation_id OR NEW.journal_id!=OLD.journal_id
              OR NEW.kind!=OLD.kind OR NEW.user_id IS NOT OLD.user_id
              OR NEW.target_store!=OLD.target_store OR NEW.version!=OLD.version
              OR NEW.source_identity IS NOT OLD.source_identity
              OR NEW.source_identity_version IS NOT OLD.source_identity_version
              OR OLD.state='ready'
              BEGIN SELECT RAISE(ABORT,'Ownership is immutable'); END''',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE ownership ADD COLUMN planned_session_id TEXT',
            );
            await db.execute(
              '''CREATE UNIQUE INDEX ownership_planned_session_unique
              ON ownership(journal_id,planned_session_id)
              WHERE planned_session_id IS NOT NULL''',
            );
            await db.execute('DROP TRIGGER IF EXISTS ownership_immutable');
            await db.execute(
              '''CREATE TRIGGER ownership_immutable BEFORE UPDATE ON ownership
              WHEN NEW.reservation_id!=OLD.reservation_id OR NEW.journal_id!=OLD.journal_id
              OR NEW.kind!=OLD.kind OR NEW.user_id IS NOT OLD.user_id
              OR NEW.target_store!=OLD.target_store OR NEW.version!=OLD.version
              OR NEW.source_identity IS NOT OLD.source_identity
              OR NEW.source_identity_version IS NOT OLD.source_identity_version
              OR (OLD.planned_session_id IS NULL AND NEW.planned_session_id IS NOT NULL)
              OR (OLD.planned_session_id IS NOT NULL AND
                  (NEW.state!='ready' OR NEW.session_id IS NOT OLD.planned_session_id
                   OR NEW.planned_session_id IS NOT NULL))
              OR OLD.state='ready'
              BEGIN SELECT RAISE(ABORT,'Ownership is immutable'); END''',
            );
          }
        },
      ),
    );
    return GpsOwnershipStore(db);
  }

  Future<GpsOwnershipManifest> prepare(
    String journalId,
    GpsOwner owner, {
    String? plannedSessionId,
  }) async {
    if (journalId.isEmpty || owner.kind == GpsOwnerKind.legacyUnassigned) {
      throw StateError('New session needs explicit ownership');
    }
    final id = DriveSourceProvenance.newUuidV4();
    final sourceIdentity = DriveSourceProvenance.newUuidV4();
    final now = DateTime.now().microsecondsSinceEpoch;
    final row = <String, Object?>{
      'reservation_id': id,
      'version': 1,
      'journal_id': journalId,
      'session_id': null,
      'kind': owner.wireKind,
      'user_id': owner.userId,
      'target_store': owner.targetStore,
      'source_identity': sourceIdentity,
      'source_identity_version': 1,
      'planned_session_id': plannedSessionId,
      'state': 'prepared',
      'created_us': now,
      'updated_us': now,
    };
    await db.transaction((tx) async {
      await tx.insert('ownership', row);
      await beforeCommit?.call('ownership_prepare');
    });
    return GpsOwnershipManifest(await _reservation(id));
  }

  Future<Map<String, Object?>> _reservation(String id) async => (await db.query(
    'ownership',
    where: 'reservation_id=?',
    whereArgs: [id],
  )).single;

  Future<GpsOwnershipManifest> bind(
    String reservationId,
    String sessionId,
  ) async {
    if (sessionId.isEmpty) throw StateError('Missing session identity');
    await db.transaction((tx) async {
      final row = (await tx.query(
        'ownership',
        where: 'reservation_id=?',
        whereArgs: [reservationId],
      )).single;
      if (row['state'] == 'ready') {
        if (row['session_id'] != sessionId) {
          throw StateError('Session conflict');
        }
        return;
      }
      final plannedSessionId = row['planned_session_id'] as String?;
      if (plannedSessionId != null && plannedSessionId != sessionId) {
        throw StateError('Planned session identity conflict');
      }
      await tx.update(
        'ownership',
        {
          'session_id': sessionId,
          'state': 'ready',
          'planned_session_id': null,
          'updated_us': DateTime.now().microsecondsSinceEpoch,
        },
        where: 'reservation_id=?',
        whereArgs: [reservationId],
      );
      await beforeCommit?.call('ownership_bind');
    });
    return GpsOwnershipManifest(await _reservation(reservationId));
  }

  Future<GpsOwnershipManifest?> get(String journalId, String sessionId) async {
    final rows = await db.query(
      'ownership',
      where: 'journal_id=? AND (session_id=? OR planned_session_id=?)',
      whereArgs: [journalId, sessionId, sessionId],
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1) throw StateError('Ownership binding conflict');
    return GpsOwnershipManifest(rows.single);
  }

  Future<GpsOwner> recoveryOwner(String journalId, String sessionId) async {
    final manifest = await get(journalId, sessionId);
    return manifest?.state == 'ready'
        ? manifest!.owner
        : const GpsOwner.legacy();
  }

  /// Completes the durable pre-journal reservation only if the journal proves
  /// that the preselected session ID actually exists. This repairs a crash
  /// after journal creation but before the original ready-state commit.
  Future<GpsOwnershipManifest?> recoverBinding(
    String journalId,
    String sessionId, {
    required bool journalSessionExists,
  }) async {
    final manifest = await get(journalId, sessionId);
    if (manifest == null || manifest.state == 'ready') return manifest;
    if (!journalSessionExists || manifest.sessionId != sessionId) return null;
    return bind(manifest.reservationId, sessionId);
  }

  Future<String> beginTransfer(
    GpsOwnershipManifest manifest,
    String target,
  ) async {
    final session = manifest.sessionId;
    final saved = session == null
        ? null
        : await get(manifest.journalId, session);
    if (saved == null ||
        saved.reservationId != manifest.reservationId ||
        saved.state != 'ready' ||
        target != saved.targetStore) {
      throw StateError('Transfer ownership conflict');
    }
    final op = jsonEncode([
      'gps_transfer_v1',
      manifest.journalId,
      session,
      target,
    ]);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'transfers',
        where: 'journal_id=? AND session_id=?',
        whereArgs: [manifest.journalId, session],
      );
      if (rows.isNotEmpty) {
        if (rows.single['operation_id'] != op ||
            rows.single['target_store'] != target) {
          throw StateError('Transfer conflict');
        }
        return;
      }
      await tx.insert('transfers', {
        'operation_id': op,
        'journal_id': manifest.journalId,
        'session_id': session,
        'target_store': target,
        'state': 'intent',
        'created_us': DateTime.now().microsecondsSinceEpoch,
        'verified_us': null,
      });
      await beforeCommit?.call('transfer_intent');
    });
    return op;
  }

  Future<void> verifyTransfer(String op) => db.transaction((tx) async {
    final row = (await tx.query(
      'transfers',
      where: 'operation_id=?',
      whereArgs: [op],
    )).single;
    if (row['state'] == 'verified') return;
    await tx.update(
      'transfers',
      {
        'state': 'verified',
        'verified_us': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'operation_id=?',
      whereArgs: [op],
    );
    await beforeCommit?.call('transfer_receipt');
  });
  Future<bool> verified(String journalId, String sessionId) async {
    final rows = await db.query(
      'transfers',
      where: 'journal_id=? AND session_id=?',
      whereArgs: [journalId, sessionId],
    );
    return rows.length == 1 && rows.single['state'] == 'verified';
  }

  Future<void> close() => db.close();
}
