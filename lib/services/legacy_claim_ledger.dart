import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'gps_session_ownership.dart';
import 'legacy_asset_transfer.dart';

class LegacyClaim {
  LegacyClaim(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  String get operationId => row['operation_id'] as String;
  String get namespace => row['source_namespace'] as String;
  String get fingerprint => row['fingerprint'] as String;
  GpsOwner get owner => GpsOwner.account(row['owner_uuid'] as String);
  bool get completed => row['state'] == 'completed';
}

/// Separate WAL/FULL claim ledger (claims schema v1, database schema v2),
/// never an acquisition-journal migration.
/// The source namespace (derived from canonical source path) is UNIQUE across
/// owners and fingerprints. Reservation cannot be reassigned or deleted.
class LegacyClaimLedger {
  LegacyClaimLedger._(this.db);
  final Database db;
  static Future<LegacyClaimLedger> open({
    required DatabaseFactory factory,
    required String path,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 2,
        onConfigure: (db) async {
          final wal = await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=FULL');
          await db.rawQuery('PRAGMA busy_timeout=5000');
          await db.execute('PRAGMA foreign_keys=ON');
          final full = await db.rawQuery('PRAGMA synchronous');
          if (wal.single.values.single.toString().toLowerCase() != 'wal' ||
              full.single.values.single != 2) {
            throw const ImportFailure('ledger_durability_unavailable');
          }
        },
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE claims (
          source_namespace TEXT PRIMARY KEY, version INTEGER NOT NULL CHECK(version=1),
          fingerprint TEXT NOT NULL, owner_uuid TEXT NOT NULL,
          operation_id TEXT NOT NULL UNIQUE,
          state TEXT NOT NULL CHECK(state IN ('reserved','copying','completed')),
          attempts INTEGER NOT NULL, created_us INTEGER NOT NULL,
          updated_us INTEGER NOT NULL, completed_us INTEGER,
          evidence TEXT, error_code TEXT,
          CHECK((state='completed' AND evidence IS NOT NULL AND completed_us IS NOT NULL)
            OR (state!='completed' AND completed_us IS NULL)))''');
          await db.execute(
            '''CREATE TRIGGER immutable_claim BEFORE UPDATE ON claims
          WHEN NEW.source_namespace!=OLD.source_namespace OR NEW.version!=OLD.version
          OR NEW.fingerprint!=OLD.fingerprint OR NEW.owner_uuid!=OLD.owner_uuid
          OR NEW.operation_id!=OLD.operation_id OR OLD.state='completed'
          BEGIN SELECT RAISE(ABORT,'Immutable legacy claim'); END''',
          );
          await db.execute(
            '''CREATE TRIGGER retain_claim BEFORE DELETE ON claims
          BEGIN SELECT RAISE(ABORT,'Legacy claim retained'); END''',
          );
          await db.execute('''CREATE TABLE record_receipts (
          operation_id TEXT NOT NULL REFERENCES claims(operation_id),
          source_group TEXT NOT NULL, source_key TEXT NOT NULL,
          target_key TEXT NOT NULL, source_sha TEXT NOT NULL, target_sha TEXT NOT NULL,
          PRIMARY KEY(operation_id,source_group,source_key),
          UNIQUE(operation_id,source_group,target_key))''');
          await db.execute('''CREATE TABLE asset_receipts (
          operation_id TEXT NOT NULL REFERENCES claims(operation_id),
          asset_id TEXT NOT NULL, sha256 TEXT NOT NULL, bytes INTEGER NOT NULL,
          relative_path TEXT NOT NULL, PRIMARY KEY(operation_id,asset_id))''');
          for (final table in ['record_receipts', 'asset_receipts']) {
            for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
              final reference = action == 'DELETE' ? 'OLD' : 'NEW';
              final oldGuard = action == 'UPDATE'
                  ? " OR (SELECT state FROM claims WHERE operation_id=OLD.operation_id)='completed'"
                  : '';
              await db.execute(
                '''CREATE TRIGGER ${table}_${action.toLowerCase()}_guard
              BEFORE $action ON $table
              WHEN (SELECT state FROM claims WHERE operation_id=$reference.operation_id)='completed' $oldGuard
              BEGIN SELECT RAISE(ABORT,'Completed import evidence immutable'); END''',
              );
            }
          }
          await _createOwnerRevisionSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createOwnerRevisionSchema(db);
        },
      ),
    );
    return LegacyClaimLedger._(db);
  }

  Future<LegacyClaim?> get(
    String namespace, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? db).query(
      'claims',
      where: 'source_namespace=?',
      whereArgs: [namespace],
    );
    return rows.isEmpty ? null : LegacyClaim(rows.single);
  }

  static void match(LegacyClaim claim, String fingerprint, GpsOwner owner) {
    if (claim.fingerprint != fingerprint ||
        claim.owner.targetStore != owner.targetStore) {
      throw const ImportFailure('legacy_claim_conflict');
    }
  }

  Future<LegacyClaim> reserve(
    String namespace,
    String fingerprint,
    GpsOwner owner,
  ) async {
    if (namespace.isEmpty || fingerprint.isEmpty || owner.userId == null) {
      throw const ImportFailure('invalid_claim_identity');
    }
    return db.transaction((tx) async {
      var prior = await get(namespace, executor: tx);
      if (prior == null) {
        final operation = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  'legacy_import_v1',
                  namespace,
                  fingerprint,
                  owner.targetStore,
                ]),
              ),
            )
            .toString();
        final now = DateTime.now().microsecondsSinceEpoch;
        await tx.insert('claims', {
          'source_namespace': namespace,
          'version': 1,
          'fingerprint': fingerprint,
          'owner_uuid': owner.userId,
          'operation_id': operation,
          'state': 'reserved',
          'attempts': 0,
          'created_us': now,
          'updated_us': now,
        });
        prior = await get(namespace, executor: tx);
      }
      match(prior!, fingerprint, owner);
      return prior;
    });
  }

  Future<void> attempt(LegacyClaim claim) => db.transaction((tx) async {
    final current = (await get(claim.namespace, executor: tx))!;
    match(current, claim.fingerprint, claim.owner);
    if (current.completed) return;
    await tx.rawUpdate(
      '''UPDATE claims SET state='copying', attempts=attempts+1,
      updated_us=?, error_code=NULL WHERE source_namespace=?''',
      [DateTime.now().microsecondsSinceEpoch, claim.namespace],
    );
  });

  /// Holds a SQLite write transaction across staging/verification. This is a
  /// deliberate local-phase tradeoff: cross-isolate/process retries cannot
  /// concurrently write the same Hive workspace. Busy means safe retry, not a
  /// stale lock takeover. Process death releases the SQLite transaction lock.
  Future<void> commit(
    LegacyClaim claim,
    Future<Map<String, Object?>> Function(Transaction) copyAndVerify, {
    Future<void> Function()? beforeCommit,
  }) => db.transaction((tx) async {
    // Acquire the writer lock before touching Hive/files, including same-owner
    // retries through another database connection.
    await tx.rawUpdate(
      'UPDATE claims SET updated_us=? WHERE source_namespace=? '
      "AND state!='completed'",
      [DateTime.now().microsecondsSinceEpoch, claim.namespace],
    );
    final current = (await get(claim.namespace, executor: tx))!;
    match(current, claim.fingerprint, claim.owner);
    if (current.completed) return;
    final evidence = await copyAndVerify(tx);
    await beforeCommit?.call();
    final now = DateTime.now().microsecondsSinceEpoch;
    await tx.update(
      'claims',
      {
        'state': 'completed',
        'evidence': jsonEncode(evidence),
        'completed_us': now,
        'updated_us': now,
        'error_code': null,
      },
      where: 'source_namespace=?',
      whereArgs: [claim.namespace],
    );
  });
  Future<void> close() => db.close();

  /// Completed imports are discoverable by immutable target UUID. This is
  /// discovery only; callers must still reopen and verify each partition.
  Future<List<LegacyClaim>> completedForOwner(String ownerUuid) async {
    final owner = GpsOwner.account(ownerUuid);
    final rows = await db.query(
      'claims',
      where: "owner_uuid=? AND state='completed'",
      whereArgs: [owner.userId],
      orderBy: 'completed_us, source_namespace',
    );
    return rows.map(LegacyClaim.new).toList(growable: false);
  }

  static Future<void> _createOwnerRevisionSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS owner_revisions (
      revision_id TEXT PRIMARY KEY,
      version INTEGER NOT NULL CHECK(version=1),
      owner_uuid TEXT NOT NULL,
      base_revision_id TEXT,
      source_revision TEXT NOT NULL,
      source_fingerprint TEXT NOT NULL,
      source_namespace TEXT NOT NULL,
      import_fingerprint TEXT NOT NULL,
      plan_fingerprint TEXT NOT NULL,
      state TEXT NOT NULL CHECK(state IN ('preparing','verified','published')),
      record_count INTEGER NOT NULL,
      asset_count INTEGER NOT NULL,
      evidence TEXT,
      created_us INTEGER NOT NULL,
      updated_us INTEGER NOT NULL,
      UNIQUE(owner_uuid,source_namespace,import_fingerprint,plan_fingerprint),
      CHECK((state='preparing' AND evidence IS NULL) OR
        (state IN ('verified','published') AND evidence IS NOT NULL)))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS owner_revision_records (
      revision_id TEXT NOT NULL REFERENCES owner_revisions(revision_id),
      record_id TEXT NOT NULL,
      group_name TEXT NOT NULL,
      logical_key TEXT NOT NULL,
      source_identity TEXT NOT NULL,
      origin TEXT NOT NULL CHECK(origin IN ('owner','legacy')),
      content_sha256 TEXT NOT NULL,
      payload BLOB NOT NULL,
      PRIMARY KEY(revision_id,record_id),
      UNIQUE(revision_id,group_name,source_identity,logical_key))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS owner_revision_assets (
      revision_id TEXT NOT NULL REFERENCES owner_revisions(revision_id),
      source_namespace TEXT NOT NULL,
      asset_id TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      bytes INTEGER NOT NULL CHECK(bytes>=0),
      relative_path TEXT NOT NULL,
      PRIMARY KEY(revision_id,source_namespace,asset_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS owner_revision_pointer (
      owner_uuid TEXT PRIMARY KEY,
      revision_id TEXT NOT NULL REFERENCES owner_revisions(revision_id),
      generation INTEGER NOT NULL CHECK(generation>0),
      updated_us INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS import_visibility (
      source_namespace TEXT PRIMARY KEY REFERENCES claims(source_namespace),
      fingerprint TEXT NOT NULL,
      owner_uuid TEXT NOT NULL,
      revision_id TEXT NOT NULL REFERENCES owner_revisions(revision_id),
      operation_id TEXT NOT NULL UNIQUE REFERENCES claims(operation_id),
      generation INTEGER NOT NULL CHECK(generation>0),
      visible_us INTEGER NOT NULL)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS owner_revisions_owner_state
      ON owner_revisions(owner_uuid,state,created_us)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS import_visibility_owner
      ON import_visibility(owner_uuid,visible_us)''');
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      final ref = action == 'DELETE' ? 'OLD' : 'NEW';
      final protected = action == 'UPDATE'
          ? "(SELECT state FROM owner_revisions WHERE revision_id=OLD.revision_id)!='preparing' OR "
                "(SELECT state FROM owner_revisions WHERE revision_id=NEW.revision_id)!='preparing'"
          : "(SELECT state FROM owner_revisions WHERE revision_id=$ref.revision_id)!='preparing'";
      await db.execute(
        '''CREATE TRIGGER IF NOT EXISTS revision_record_${action.toLowerCase()}_guard
        BEFORE $action ON owner_revision_records
        WHEN $protected
        BEGIN SELECT RAISE(ABORT,'Verified owner revision is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER IF NOT EXISTS revision_asset_${action.toLowerCase()}_guard
        BEFORE $action ON owner_revision_assets
        WHEN $protected
        BEGIN SELECT RAISE(ABORT,'Verified owner revision assets are immutable'); END''',
      );
    }
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS owner_revision_identity_guard
      BEFORE UPDATE ON owner_revisions
      WHEN NEW.revision_id!=OLD.revision_id OR NEW.version!=OLD.version OR
      NEW.owner_uuid!=OLD.owner_uuid OR NEW.base_revision_id IS NOT OLD.base_revision_id OR
      NEW.source_revision!=OLD.source_revision OR NEW.source_fingerprint!=OLD.source_fingerprint OR
      NEW.source_namespace!=OLD.source_namespace OR NEW.import_fingerprint!=OLD.import_fingerprint OR
      NEW.plan_fingerprint!=OLD.plan_fingerprint OR NEW.record_count!=OLD.record_count OR
      NEW.asset_count!=OLD.asset_count OR OLD.state='published' OR
      (OLD.state='verified' AND NEW.evidence IS NOT OLD.evidence) OR
      (OLD.state='verified' AND NEW.state!='published') OR
      (OLD.state='preparing' AND NEW.state NOT IN ('preparing','verified'))
      BEGIN SELECT RAISE(ABORT,'Owner revision identity/state conflict'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS owner_revision_pointer_target_insert
      BEFORE INSERT ON owner_revision_pointer
      WHEN NEW.generation!=1 OR NOT EXISTS(SELECT 1 FROM owner_revisions r WHERE r.revision_id=NEW.revision_id
        AND r.owner_uuid=NEW.owner_uuid AND r.state='published')
      BEGIN SELECT RAISE(ABORT,'Owner revision pointer target invalid'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS owner_revision_pointer_target_update
      BEFORE UPDATE ON owner_revision_pointer
      WHEN NOT EXISTS(SELECT 1 FROM owner_revisions r WHERE r.revision_id=NEW.revision_id
        AND r.owner_uuid=NEW.owner_uuid AND r.state='published')
      BEGIN SELECT RAISE(ABORT,'Owner revision pointer target invalid'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS owner_revision_pointer_identity_guard
      BEFORE UPDATE ON owner_revision_pointer
      WHEN NEW.owner_uuid!=OLD.owner_uuid OR NEW.generation!=OLD.generation+1
      BEGIN SELECT RAISE(ABORT,'Owner revision pointer conflict'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER IF NOT EXISTS import_visibility_insert_guard
      BEFORE INSERT ON import_visibility
      WHEN NOT EXISTS(SELECT 1 FROM claims c WHERE c.source_namespace=NEW.source_namespace
        AND c.operation_id=NEW.operation_id AND c.fingerprint=NEW.fingerprint
        AND c.owner_uuid=NEW.owner_uuid AND c.state='completed') OR
        NOT EXISTS(SELECT 1 FROM owner_revisions r WHERE r.revision_id=NEW.revision_id
        AND r.owner_uuid=NEW.owner_uuid AND r.source_namespace=NEW.source_namespace
        AND r.import_fingerprint=NEW.fingerprint AND r.state='published')
      BEGIN SELECT RAISE(ABORT,'Import visibility evidence invalid'); END''',
    );
    await db.execute('''CREATE TRIGGER IF NOT EXISTS import_visibility_immutable
      BEFORE UPDATE ON import_visibility
      BEGIN SELECT RAISE(ABORT,'Import visibility is immutable'); END''');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS import_visibility_retained
      BEFORE DELETE ON import_visibility
      BEGIN SELECT RAISE(ABORT,'Import visibility is retained'); END''');
  }
}
