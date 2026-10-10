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

/// A separate v1 WAL/FULL ledger, never an acquisition-journal migration.
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
        version: 1,
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
}
