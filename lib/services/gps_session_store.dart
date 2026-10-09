import 'dart:convert';
import 'dart:math';
import 'package:sqflite_common/sqlite_api.dart';
import '../models/canonical_telemetry_point.dart';
import 'gps_failure.dart';

class GpsSession {
  const GpsSession(
    this.id,
    this.startedAt,
    this.state,
    this.error, {
    this.stoppedAt,
  });
  final DateTime? stoppedAt;
  final String id;
  final DateTime startedAt;
  final String state;
  final String? error;
  factory GpsSession.fromRow(Map<String, Object?> row) => GpsSession(
    row['id'] as String,
    DateTime.fromMicrosecondsSinceEpoch(row['started_us'] as int),
    row['state'] as String,
    row['error'] as String?,
    stoppedAt: row['stopped_us'] == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(row['stopped_us'] as int),
  );
}

class GpsJournalPoint {
  const GpsJournalPoint(
    this.sessionId,
    this.sequence,
    this.point, {
    this.checkpoint,
  });
  final Map<String, dynamic>? checkpoint;
  final String sessionId;
  final int sequence;
  final CanonicalTelemetryPoint point;
  Map<String, dynamic> toMap() => {
    ...point.toMap(),
    'timeMicros': point.timestamp.microsecondsSinceEpoch,
    'timeIsUtc': point.timestamp.isUtc,
    'sessionId': sessionId,
    'sequence': sequence,
    if (checkpoint != null) 'filterCheckpoint': checkpoint,
  };
  factory GpsJournalPoint.fromRow(
    Map<String, Object?> row, {
    bool includeCheckpoint = true,
  }) {
    final value = Map<String, dynamic>.from(
      jsonDecode(row['payload'] as String) as Map,
    );
    return GpsJournalPoint(
      row['session_id'] as String,
      row['sequence'] as int,
      CanonicalTelemetryPoint.fromMap(value)!,
      checkpoint: !includeCheckpoint || value['filterCheckpoint'] == null
          ? null
          : Map<String, dynamic>.from(value['filterCheckpoint'] as Map),
    );
  }
}

/// Separate acquisition journal. Existing Hive boxes are never opened here.
/// WAL + FULL durability; all sequence allocation and insertion is atomic.
class GpsSessionStore {
  GpsSessionStore(this.db);
  final Database db;
  static Future<GpsSessionStore> open({
    required DatabaseFactory factory,
    String? path,
  }) async {
    try {
      final backend = factory;
      final location =
          path ?? '${await backend.getDatabasesPath()}/driveit_gps_sessions.db';
      final db = await backend.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 3,
          singleInstance: false,
          onConfigure: (db) async {
            final mode = await db.rawQuery('PRAGMA journal_mode=WAL');
            if (mode.isEmpty ||
                mode.single.values.single.toString().toLowerCase() != 'wal') {
              throw StateError('Durable GPS WAL could not be enabled');
            }
            await db.execute('PRAGMA synchronous=FULL');
            await db.execute('PRAGMA foreign_keys=ON');
            await db.rawQuery('PRAGMA busy_timeout=5000');
            final timeout = await db.rawQuery('PRAGMA busy_timeout');
            final sync = await db.rawQuery('PRAGMA synchronous');
            final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
            if (timeout.single.values.single != 5000 ||
                sync.single.values.single != 2 ||
                foreignKeys.single.values.single != 1) {
              throw GpsFailure(GpsErrorCode.sqliteOpen);
            }
          },
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE sessions (id TEXT PRIMARY KEY, started_us INTEGER NOT NULL, stopped_us INTEGER, state TEXT NOT NULL, error TEXT, saved_drive_id TEXT)',
            );
            await db.execute(
              'CREATE TABLE current_session (singleton INTEGER PRIMARY KEY CHECK(singleton=1), session_id TEXT NOT NULL REFERENCES sessions(id))',
            );
            await db.execute(
              'CREATE TABLE points (session_id TEXT NOT NULL REFERENCES sessions(id), sequence INTEGER NOT NULL CHECK(sequence>0), timestamp_us INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(session_id,sequence), UNIQUE(session_id,timestamp_us))',
            );
            await db.execute(
              "CREATE TRIGGER points_no_update BEFORE UPDATE ON points BEGIN SELECT RAISE(ABORT,'GPS journal is append-only'); END",
            );
            await db.execute(
              "CREATE TRIGGER points_no_delete BEFORE DELETE ON points BEGIN SELECT RAISE(ABORT,'GPS journal is append-only'); END",
            );
            await _createEvents(db);
            await _createLifecycle(db);
          },
          onUpgrade: (db, old, _) async {
            if (old < 2) await _createEvents(db);
            if (old < 3) await _createLifecycle(db);
          },
        ),
      );
      return GpsSessionStore(db);
    } catch (error) {
      final failure = GpsFailure.from(error, GpsErrorCode.sqliteOpen);
      failure.report('open');
      throw failure;
    }
  }

  static Future<void> _createEvents(DatabaseExecutor db) => db.execute(
    'CREATE TABLE session_events (session_id TEXT NOT NULL REFERENCES sessions(id), kind TEXT NOT NULL, occurred_us INTEGER NOT NULL, sequence INTEGER, PRIMARY KEY(session_id,kind))',
  );

  static Future<void> _createLifecycle(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE session_transfers (session_id TEXT PRIMARY KEY REFERENCES sessions(id), drive_id TEXT NOT NULL UNIQUE, manifest TEXT NOT NULL, final_sequence INTEGER NOT NULL, attempted_us INTEGER NOT NULL, verified_us INTEGER)',
    );
    await db.execute(
      'CREATE TABLE journal_maintenance (session_id TEXT PRIMARY KEY, drive_id TEXT NOT NULL, final_sequence INTEGER NOT NULL, verified_us INTEGER NOT NULL, removed_us INTEGER NOT NULL)',
    );
    // Scoped maintenance authorization is a permanent audit receipt. Normal
    // update/delete remains prohibited; no trigger is disabled during cleanup.
    await db.execute('DROP TRIGGER IF EXISTS points_no_delete');
    await db.execute(
      "CREATE TRIGGER IF NOT EXISTS points_no_update BEFORE UPDATE ON points BEGIN SELECT RAISE(ABORT,'GPS journal is append-only'); END",
    );
    const authorized =
        "EXISTS (SELECT 1 FROM journal_maintenance m JOIN session_transfers t ON t.session_id=m.session_id JOIN sessions s ON s.id=m.session_id WHERE m.session_id=OLD.session_id AND s.state='saved' AND t.verified_us IS NOT NULL AND m.verified_us=t.verified_us AND m.final_sequence=t.final_sequence AND m.removed_us>=m.verified_us+2592000000000)";
    await db.execute(
      "CREATE TRIGGER points_no_delete BEFORE DELETE ON points WHEN NOT ($authorized) BEGIN SELECT RAISE(ABORT,'GPS journal is append-only'); END",
    );
    await db.execute(
      "CREATE TRIGGER events_no_delete BEFORE DELETE ON session_events WHEN NOT ($authorized) BEGIN SELECT RAISE(ABORT,'GPS events are protected'); END",
    );
    await db.execute(
      "CREATE TRIGGER events_no_update BEFORE UPDATE ON session_events BEGIN SELECT RAISE(ABORT,'GPS events are append-only'); END",
    );
    for (final operation in ['UPDATE', 'DELETE']) {
      await db.execute(
        "CREATE TRIGGER maintenance_no_${operation.toLowerCase()} BEFORE $operation ON journal_maintenance BEGIN SELECT RAISE(ABORT,'Maintenance audit is immutable'); END",
      );
    }
  }

  /// Lifecycle is derived without changing the acquisition state/sequence.
  Future<String> lifecycle(String id, {bool producerRunning = false}) =>
      gpsRead(() async {
        final s = await session(id);
        if (s == null) throw GpsFailure(GpsErrorCode.recovery);
        final transfer = await transferFor(id);
        if (s.state == 'saved') {
          return transfer?['verified_us'] != null
              ? 'VERIFIED'
              : 'RECOVERY_REQUIRED';
        }
        if (s.error != null) return 'RECOVERY_REQUIRED';
        if (s.state == 'stopped') {
          return transfer == null ? 'PENDING_SAVE' : 'SAVING';
        }
        if (s.state == 'recording') {
          return producerRunning ? 'ACTIVE' : 'RECOVERABLE';
        }
        return 'RECOVERY_REQUIRED';
      });

  Future<List<GpsSession>> recoverableSessions() => gpsRead(
    () async => (await db.query(
      'sessions',
      where: "state!='saved'",
      orderBy: 'started_us,id',
    )).map(GpsSession.fromRow).toList(),
  );

  /// Explicit user selection only. Never redirects a running acquisition into
  /// another session; a stopped pointer can be changed without deleting it.
  Future<void> selectRecovery(String id) => gpsWrite(
    () => db.transaction((tx) async {
      final chosen = await tx.query(
        'sessions',
        where: 'id=? AND state!=?',
        whereArgs: [id, 'saved'],
      );
      if (chosen.length != 1) throw GpsFailure(GpsErrorCode.recovery);
      final current = await tx.rawQuery(
        'SELECT s.* FROM sessions s JOIN current_session c ON c.session_id=s.id',
      );
      if (current.isNotEmpty &&
          current.single['id'] != id &&
          current.single['state'] == 'recording') {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      await tx.insert('current_session', {
        'singleton': 1,
        'session_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }),
  );

  Future<Map<String, Object?>?> transferFor(String id) => gpsRead(() async {
    final rows = await db.query(
      'session_transfers',
      where: 'session_id=?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single;
  });

  Future<Map<String, Object?>> beginTransfer(
    String id,
    String driveId,
    String manifest,
  ) => gpsWrite(
    () => db.transaction((tx) async {
      final rows = await tx.query('sessions', where: 'id=?', whereArgs: [id]);
      if (rows.length != 1 ||
          !['stopped', 'saved'].contains(rows.single['state'])) {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      final tail = await tx.rawQuery(
        'SELECT COUNT(*) AS n,MAX(sequence) AS last FROM points WHERE session_id=?',
        [id],
      );
      final n = tail.single['n'] as int;
      final last = tail.single['last'] as int? ?? 0;
      final drained = await tx.query(
        'session_events',
        where: 'session_id=? AND kind=?',
        whereArgs: [id, 'drained'],
      );
      if (n != last ||
          drained.length != 1 ||
          drained.single['sequence'] != last) {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      final existing = await tx.query(
        'session_transfers',
        where: 'session_id=?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty) {
        if (existing.single['drive_id'] != driveId ||
            existing.single['final_sequence'] != last) {
          throw GpsFailure(GpsErrorCode.recovery);
        }
        return existing.single;
      }
      if (rows.single['state'] == 'saved') {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      final intent = <String, Object?>{
        'session_id': id,
        'drive_id': driveId,
        'manifest': manifest,
        'final_sequence': last,
        'attempted_us': DateTime.now().microsecondsSinceEpoch,
      };
      await tx.insert('session_transfers', intent);
      await tx.insert('session_events', {
        'session_id': id,
        'kind': 'saving',
        'occurred_us': intent['attempted_us'],
        'sequence': last,
      });
      return intent;
    }),
  );

  /// Not scheduled by production. Caller must freshly verify Hive content and
  /// explicitly authorize this single archived session. Never accepts active,
  /// unverified legacy-saved, failed or partially transferred journals.
  Future<bool> maintenanceEligible(String id, DateTime now) =>
      gpsRead(() async {
        final s = await session(id);
        final t = await transferFor(id);
        final activeSession = await active();
        return s?.state == 'saved' &&
            s?.error == null &&
            activeSession?.id != id &&
            t?['verified_us'] != null &&
            now.microsecondsSinceEpoch - (t!['verified_us'] as int) >=
                const Duration(days: 30).inMicroseconds;
      });

  Future<void> removeVerifiedJournal(
    String id, {
    required DateTime now,
    required Future<bool> Function(Map<String, Object?> receipt) verifyHive,
  }) async {
    final receipt = await transferFor(id);
    if (receipt == null ||
        !await maintenanceEligible(id, now) ||
        !await verifyHive(receipt)) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    await gpsWrite(
      () => db.transaction((tx) async {
        final rows = await tx.rawQuery(
          "SELECT s.*,t.verified_us,t.final_sequence FROM sessions s JOIN session_transfers t ON t.session_id=s.id WHERE s.id=? AND s.state='saved' AND s.error IS NULL AND t.verified_us IS NOT NULL AND NOT EXISTS(SELECT 1 FROM current_session c WHERE c.session_id=s.id)",
          [id],
        );
        if (rows.length != 1 ||
            rows.single['verified_us'] != receipt['verified_us'] ||
            now.microsecondsSinceEpoch - (rows.single['verified_us'] as int) <
                const Duration(days: 30).inMicroseconds) {
          throw GpsFailure(GpsErrorCode.recovery);
        }
        await tx.insert('journal_maintenance', {
          'session_id': id,
          'drive_id': receipt['drive_id'],
          'final_sequence': receipt['final_sequence'],
          'verified_us': receipt['verified_us'],
          'removed_us': now.microsecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await tx.delete('points', where: 'session_id=?', whereArgs: [id]);
        await tx.delete(
          'session_events',
          where: 'session_id=?',
          whereArgs: [id],
        );
        // Bulk payload is no longer needed after explicitly verified cleanup.
        // Keep only compact session/transfer/audit tombstones.
        await tx.update(
          'session_transfers',
          {'manifest': '{}'},
          where: 'session_id=?',
          whereArgs: [id],
        );
        // Session + transfer + audit tombstones remain; unrelated sessions untouched.
      }),
    );
  }

  Future<List<Map<String, Object?>>> events(String id) => gpsRead(
    () => db.query(
      'session_events',
      where: 'session_id=?',
      whereArgs: [id],
      orderBy: 'occurred_us,kind',
    ),
  );

  Future<void> recordProducerEvent(
    String id,
    String kind,
    int epoch,
    int sequence,
  ) => gpsWrite(() async {
    if (![
      'producer_started',
      'producer_drained',
      'queue_overflow',
    ].contains(kind)) {
      throw GpsFailure(GpsErrorCode.recovery);
    }
    await db.insert('session_events', {
      'session_id': id,
      'kind': '$kind:$epoch',
      'occurred_us': DateTime.now().microsecondsSinceEpoch,
      'sequence': sequence,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  });

  Future<void> recordFlowEvent(String id, String kind, DateTime at) =>
      gpsWrite(() async {
        if (!const {
          'gps_waiting',
          'gps_resumed',
          'permission_blocked',
        }.contains(kind)) {
          throw GpsFailure(GpsErrorCode.recovery);
        }
        await db.insert('session_events', {
          'session_id': id,
          'kind': '$kind:${at.microsecondsSinceEpoch}',
          'occurred_us': at.microsecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      });

  Future<void> requestStop(String id, {DateTime? at}) => gpsWrite(
    () => db.transaction((tx) async {
      final rows = await tx.query('sessions', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) throw GpsFailure(GpsErrorCode.recovery);
      if (rows.single['state'] != 'recording') return;
      await tx.insert('session_events', {
        'session_id': id,
        'kind': 'stop_requested',
        'occurred_us': (at ?? DateTime.now()).microsecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }),
  );

  Future<GpsSession?> active() => gpsRead(() async {
    final rows = await db.rawQuery(
      'SELECT s.* FROM sessions s JOIN current_session c ON c.session_id=s.id WHERE c.singleton=1',
    );
    return rows.isEmpty ? null : GpsSession.fromRow(rows.single);
  });

  Future<GpsSession?> session(String id) => gpsRead(() async {
    final rows = await db.query('sessions', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : GpsSession.fromRow(rows.single);
  });

  Future<GpsSession> create() => gpsWrite(
    () => db.transaction((tx) async {
      final current = await tx.query('current_session');
      final unfinished = await tx.query(
        'sessions',
        where: "state!='saved'",
        limit: 1,
      );
      if (current.isNotEmpty || unfinished.isNotEmpty) {
        throw StateError('Önce tamamlanmamış sürüşü kurtar.');
      }
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final now = DateTime.now();
      await tx.insert('sessions', {
        'id': id,
        'started_us': now.microsecondsSinceEpoch,
        'state': 'recording',
      });
      await tx.insert('current_session', {'singleton': 1, 'session_id': id});
      await tx.insert('session_events', {
        'session_id': id,
        'kind': 'started',
        'occurred_us': now.microsecondsSinceEpoch,
        'sequence': 0,
      });
      return GpsSession(id, now, 'recording', null);
    }),
  );
  Future<List<GpsJournalPoint>> read(
    String id, {
    int after = 0,
    bool includeCheckpoints = true,
  }) => gpsRead(() async {
    if (includeCheckpoints) {
      return (await db.query(
        'points',
        where: 'session_id=? AND sequence>?',
        whereArgs: [id, after],
        orderBy: 'sequence',
      )).map((row) => GpsJournalPoint.fromRow(row)).toList();
    }
    // Transfer/UI don't need thousands of duplicated checkpoint windows.
    // Paginate payloads without JSON1; durable data is never changed.
    final result = <GpsJournalPoint>[];
    var cursor = after;
    while (true) {
      final page = await db.query(
        'points',
        where: 'session_id=? AND sequence>?',
        whereArgs: [id, cursor],
        orderBy: 'sequence',
        limit: 128,
      );
      for (final row in page) {
        result.add(GpsJournalPoint.fromRow(row, includeCheckpoint: false));
      }
      if (page.length < 128) {
        return result;
      }
      cursor = result.last.sequence;
    }
  });
  Future<GpsJournalPoint?> last(String id) => gpsRead(() async {
    final rows = await db.query(
      'points',
      where: 'session_id=?',
      whereArgs: [id],
      orderBy: 'sequence DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : GpsJournalPoint.fromRow(rows.single);
  });

  Future<int> append(
    String id,
    int sequence,
    CanonicalTelemetryPoint point, {
    Map<String, dynamic>? checkpoint,
  }) => gpsWrite(
    () => db.transaction((tx) async {
      final current = await tx.rawQuery(
        'SELECT s.state FROM sessions s JOIN current_session c ON c.session_id=s.id WHERE s.id=?',
        [id],
      );
      if (current.isEmpty || current.single['state'] != 'recording') {
        throw StateError('Session is not recording');
      }
      final payload = jsonEncode(
        GpsJournalPoint(id, sequence, point, checkpoint: checkpoint).toMap(),
      );
      final duplicate = await tx.query(
        'points',
        where: 'session_id=? AND (sequence=? OR timestamp_us=?)',
        whereArgs: [id, sequence, point.timestamp.microsecondsSinceEpoch],
      );
      if (duplicate.isNotEmpty) {
        if (duplicate.single['payload'] == payload) {
          return duplicate.single['sequence'] as int;
        }
        throw StateError('Conflicting GPS sequence/timestamp');
      }
      final tail = await tx.rawQuery(
        'SELECT sequence,timestamp_us FROM points WHERE session_id=? ORDER BY sequence DESC LIMIT 1',
        [id],
      );
      final next = tail.isEmpty ? 1 : (tail.single['sequence'] as int) + 1;
      if (sequence != next ||
          (tail.isNotEmpty &&
              point.timestamp.microsecondsSinceEpoch <=
                  (tail.single['timestamp_us'] as int))) {
        throw StateError('Non-monotonic GPS append');
      }
      await tx.insert('points', {
        'session_id': id,
        'sequence': sequence,
        'timestamp_us': point.timestamp.microsecondsSinceEpoch,
        'payload': payload,
      });
      return sequence;
    }),
  );
  Future<void> setError(String id, String? code) => gpsWrite(
    () =>
        db.update('sessions', {'error': code}, where: 'id=?', whereArgs: [id]),
  );
  Future<void> stop(String id, {int? expectedSequence}) => gpsWrite(
    () => db.transaction((tx) async {
      final session = (await tx.query(
        'sessions',
        where: 'id=?',
        whereArgs: [id],
      )).single;
      final tail = await tx.rawQuery(
        'SELECT MAX(sequence) AS n FROM points WHERE session_id=?',
        [id],
      );
      final last = tail.single['n'] as int? ?? 0;
      if (expectedSequence != null && last != expectedSequence) {
        throw GpsFailure(GpsErrorCode.sqliteWrite);
      }
      if (session['state'] == 'saved') return;
      if (session['state'] == 'stopped') {
        // Legacy v1 stopped journals have no drain receipt. Validate their tail
        // and add a receipt only on an explicit finish/recovery action.
        await tx.insert('session_events', {
          'session_id': id,
          'kind': 'drained',
          'occurred_us': DateTime.now().microsecondsSinceEpoch,
          'sequence': last,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        return;
      }
      final requested = await tx.query(
        'session_events',
        where: 'session_id=? AND kind=?',
        whereArgs: [id, 'stop_requested'],
      );
      final now = DateTime.now().microsecondsSinceEpoch;
      await tx.update(
        'sessions',
        {
          'state': 'stopped',
          'stopped_us': requested.isEmpty
              ? now
              : requested.single['occurred_us'],
        },
        where: 'id=?',
        whereArgs: [id],
      );
      await tx.insert('session_events', {
        'session_id': id,
        'kind': 'drained',
        'occurred_us': now,
        'sequence': last,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }),
  );

  /// Only explicit successful Hive save releases the active pointer. Points
  /// remain archived; closing a summary or crashing cannot discard them.
  Future<void> acknowledgeSaved(
    String id,
    String driveId, {
    bool verified = false,
  }) => gpsWrite(
    () => db.transaction((tx) async {
      final rows = await tx.query('sessions', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty ||
          (rows.single['state'] != 'stopped' &&
              rows.single['state'] != 'saved')) {
        throw StateError('Only a drained session can be saved');
      }
      final transfers = await tx.query(
        'session_transfers',
        where: 'session_id=?',
        whereArgs: [id],
      );
      if (verified) {
        if (transfers.length != 1 || transfers.single['drive_id'] != driveId) {
          throw GpsFailure(GpsErrorCode.recovery);
        }
        await tx.update(
          'session_transfers',
          {
            'verified_us':
                transfers.single['verified_us'] ??
                DateTime.now().microsecondsSinceEpoch,
          },
          where: 'session_id=?',
          whereArgs: [id],
        );
        await tx.insert('session_events', {
          'session_id': id,
          'kind': 'verified',
          'occurred_us': DateTime.now().microsecondsSinceEpoch,
          'sequence': transfers.single['final_sequence'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else if (transfers.isNotEmpty &&
          transfers.single['verified_us'] == null) {
        throw GpsFailure(GpsErrorCode.recovery);
      }
      await tx.update(
        'sessions',
        {'state': 'saved', 'saved_drive_id': driveId},
        where: 'id=?',
        whereArgs: [id],
      );
      await tx.delete(
        'current_session',
        where: 'session_id=?',
        whereArgs: [id],
      );
    }),
  );
  Future<void> close() => db.close();
}
