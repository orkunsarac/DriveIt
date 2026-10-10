import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/drive_session.dart';
import '../models/drive_score_record.dart';
import 'local_source_bundle.dart';
import 'drive_time_analysis.dart';
import 'career_statistics_service.dart';

/// Append-only contribution identities. No GPS geometry is kept in Career.
/// Legacy activation is explicit, conservative, and never runs at startup.
class CareerContributionRepository {
  static const boxName = 'career_contributions_v1';
  CareerContributionRepository(this.box);
  final Box<dynamic> box;
  static Future<void> open(HiveInterface hive) =>
      hive.openBox<dynamic>(boxName);
  static final Map<String, Future<void>> _queues = {};

  Future<void> add(LocalSourceBundle source, {bool legacy = false}) {
    final key = box.path ?? box.name;
    final prior = _queues[key] ?? Future<void>.value();
    final future = prior.then((_) async {
      source.validate();
      final id = 'drive:${source.drive.id}';
      final content = _content(source, legacy: legacy);
      final raw = box.get(id) as String?;
      if (raw != null) {
        final proposed = jsonDecode(content) as Map<String, dynamic>;
        final existing = jsonDecode(raw) as Map<String, dynamic>;
        // Never rewrite the accounting basis of a committed contribution.
        proposed['useReliableMetrics'] = existing['useReliableMetrics'];
        if (raw != jsonEncode(proposed)) {
          throw StateError('Immutable Career contribution conflict');
        }
      } else {
        await box.put(id, content);
        await box.flush();
        if (box.get(id) != content) {
          throw StateError('Career verification failed');
        }
      }
      // A secondary score may finish after the primary receipt. Attach it
      // once as a separate append-only record, without rewriting contribution
      // metrics or counting the drive again.
      if (source.score != null) {
        await _attachScore(source.score!);
      }
      await box.flush();
    });
    _queues[key] = future.then((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  /// Does not need the removed History payload and cannot create a contribution.
  Future<void> attachScore(DriveScoreRecord record) {
    final key = box.path ?? box.name;
    final prior = _queues[key] ?? Future<void>.value();
    final future = prior.then((_) async {
      if (!box.containsKey('drive:${record.driveId}')) return;
      await _attachScore(record);
    });
    _queues[key] = future.then((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  Future<void> _attachScore(DriveScoreRecord record) async {
    final scoreKey = 'score:${record.driveId}:v${record.algorithmVersion}';
    final score = jsonEncode({
      'driveId': record.driveId,
      'algorithm': record.algorithmVersion,
      'telemetryVersion': record.telemetryDataVersion,
      'calculatedAt': record.calculatedAt.toIso8601String(),
      'total': record.totalScore,
      'confidence': record.overallConfidence,
      'categories': record.categories.map((c) => c.toMap()).toList(),
    });
    final priorScore = box.get(scoreKey) as String?;
    if (priorScore == score) {
      await box.flush();
      return;
    }
    if (priorScore != null) {
      final previous = jsonDecode(priorScore) as Map;
      if (DateTime.parse(
        previous['calculatedAt'] as String,
      ).isAfter(record.calculatedAt)) {
        return;
      }
      final prefix = '$scoreKey:revision:';
      final retained = box.keys
          .whereType<String>()
          .where((key) => key.startsWith(prefix))
          .any((key) => box.get(key) == priorScore);
      if (!retained) {
        await box.put('$prefix${box.length}', priorScore);
        await box.flush();
      }
    }
    await box.put(scoreKey, score);
    await box.flush();
  }

  String _content(LocalSourceBundle source, {required bool legacy}) {
    final m = source.toMap();
    final drive = Map<String, dynamic>.from(m['drive']);
    drive['route'] = <dynamic>[];
    final timing = source.telemetry == null
        ? null
        : DriveTimeAnalysis.fromRecord(source.telemetry!);
    // Preserve original recorded values alongside explicit reliable counters.
    // Unknown historical time remains null, not an invented measurement.
    return jsonEncode({
      'version': 1,
      'useReliableMetrics': !legacy,
      'bundle': {
        ...m,
        'drive': drive,
        'telemetry': null,
        'score': null,
        'roads': <dynamic>[],
      },
      'measuredMicros': timing?.timingKnown == true
          ? timing!.measuredMicros
          : null,
      'movingMicros': timing?.timingKnown == true ? timing!.movingMicros : null,
      'reliableDistance': timing?.timingKnown == true
          ? timing!.distanceMeters
          : null,
    });
  }

  /// Returns false if archived/deleted contributions or inconsistent old totals
  /// prevent reconstruction of *all* existing Career metrics. Known totals are
  /// retained verbatim; no missing drive, score, date or record is fabricated.
  Future<bool> prepareLegacy({
    required List<LocalSourceBundle> sources,
    required Map<String, dynamic> totals,
    Future<void> Function()? afterContributions,
  }) async {
    final baseline = jsonEncode(totals);
    final previous = box.get('baseline') as Map?;
    if (previous != null && previous['payload'] != baseline) {
      throw StateError('Career baseline conflict');
    }
    await box.put('baseline', {
      'version': 1,
      'payload': baseline,
      'ready': false,
    });
    await box.flush();
    final ids = (totals['countedIds'] as List? ?? []).cast<String>();
    final byId = {for (final s in sources) s.drive.id: s};
    if (ids.toSet().length != ids.length ||
        ids.any((id) => !byId.containsKey(id)) ||
        byId.length != ids.length ||
        !totals.containsKey('totalDistance') ||
        !totals.containsKey('totalDuration')) {
      return false;
    }
    final distance = sources.fold<double>(
      0,
      (sum, s) => sum + s.drive.distance,
    );
    final duration = sources.fold<int>(
      0,
      (sum, s) => sum + s.drive.durationSeconds,
    );
    // Conservative exact check: ambiguous accumulation stays on the old UI.
    if (distance != totals['totalDistance'] ||
        duration != totals['totalDuration']) {
      return false;
    }
    for (final source in sources) {
      final existing = box.get('drive:${source.drive.id}') as String?;
      if (existing != null &&
          (jsonDecode(existing) as Map)['useReliableMetrics'] == true &&
          (jsonDecode(existing) as Map)['measuredMicros'] != null) {
        // Switching an old cumulative total onto a different accounting basis
        // could lower Career. Keep the baseline inactive instead.
        return false;
      }
      await add(source, legacy: true);
    }
    await afterContributions?.call();
    await box.put('baseline', {
      'version': 1,
      'payload': baseline,
      'ready': true,
    });
    await box.flush();
    return true;
  }

  bool get legacyReady => (box.get('baseline') as Map?)?['ready'] == true;

  /// Opt-in consumer for Phase 3B. The existing Career screen is not switched
  /// until a complete, verified legacy baseline is available.
  CareerStatistics? statistics({bool historyOrder = false}) {
    if (!legacyReady) return null;
    final bundles = <String, LocalSourceBundle>{};
    final drives = <DriveSession>[];
    for (final key in box.keys.whereType<String>().where(
      (k) => k.startsWith('drive:'),
    )) {
      final m = jsonDecode(box.get(key) as String) as Map<String, dynamic>;
      if (m['version'] != 1) {
        throw StateError('Unsupported Career contribution');
      }
      final bundle = Map<String, dynamic>.from(m['bundle']);
      final driveId = (bundle['drive'] as Map)['id'];
      final score = box.get('score:$driveId:v1') as String?;
      if (score != null) bundle['score'] = jsonDecode(score);
      final b = LocalSourceBundle.fromMap(bundle);
      b.validate();
      if (key != 'drive:${b.drive.id}') {
        throw StateError('Career identity mismatch');
      }
      bundles[b.drive.id] = b;
      final drive = b.drive;
      if (m['useReliableMetrics'] == true && m['measuredMicros'] != null) {
        drive.durationSeconds = (m['measuredMicros'] as int) ~/ 1000000;
        drive.stoppedSeconds =
            ((m['measuredMicros'] as int) - (m['movingMicros'] as int)) ~/
            1000000;
        drive.distance = (m['reliableDistance'] as num).toDouble();
      }
      drives.add(drive);
    }
    if (historyOrder) {
      // Preserve the old History projection's newest-insertion-first record
      // tie-breaking, including after the original Hive drives disappear.
      final baseline =
          jsonDecode((box.get('baseline') as Map)['payload'] as String) as Map;
      final legacyIds = (baseline['countedIds'] as List).cast<String>();
      final legacy = legacyIds.toSet();
      final order = [
        ...drives
            .where((d) => !legacy.contains(d.id))
            .map((d) => d.id)
            .toList()
            .reversed,
        ...legacyIds.reversed,
      ];
      final positions = {for (var i = 0; i < order.length; i++) order[i]: i};
      drives.sort((a, b) => positions[a.id]!.compareTo(positions[b.id]!));
    }
    return const CareerStatisticsService().calculate(
      drives: drives,
      scoreLoader: (id) => bundles[id]?.score,
    );
  }
}
