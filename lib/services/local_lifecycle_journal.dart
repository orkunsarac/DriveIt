import 'package:hive/hive.dart';
import '../features/my_world/models/active_world_trace.dart';
import '../features/my_world/config/my_world_rules.dart';

/// Minimal durable local deletion intents, not a trash/recovery payload store.
class LocalLifecycleJournal {
  static const boxName = 'local_lifecycle_v1';
  static Future<void> open(HiveInterface hive) =>
      hive.openBox<dynamic>(boxName);
  static bool get available => Hive.isBoxOpen(boxName);
  static Box<dynamic> get box => Hive.box<dynamic>(boxName);
  static bool worldDeleted(String id) =>
      available && box.containsKey('world:$id');
  static bool historyDeleted(String id) =>
      available && box.containsKey('history:$id');
  static bool worldHasDeletion(String sourceId) =>
      worldDeleted(sourceId) ||
      (available &&
          box.keys
              .whereType<String>()
              .where((k) => k.startsWith('worldTrace:'))
              .any((k) => (box.get(k) as Map)['sourceId'] == sourceId));

  static Future<void> traceIntent(ActiveWorldTrace trace) =>
      serialized(() async {
        final key = 'worldTrace:${trace.id}';
        if (box.containsKey(key)) {
          await box.flush();
          return;
        }
        await box.put(key, {
          'version': 1,
          'state': 'prepared',
          'sourceId': trace.sourceDriveSessionId,
          'roadId': trace.validatedRoadId,
          'sectionId': trace.matchedSectionId,
          'start': trace.startOffsetMeters,
          'end': trace.endOffsetMeters,
        });
        await box.flush();
      });

  /// Canonical section-local/cumulative coordinates are never converted or
  /// rounded here. Only the existing trace identity formatting is reused.
  static List<ActiveWorldTrace> filterTraces(List<ActiveWorldTrace> traces) {
    if (!available) return traces;
    final deleted = box.keys
        .whereType<String>()
        .where((k) => k.startsWith('worldTrace:'))
        .map((k) => box.get(k) as Map)
        .toList();
    final result = <ActiveWorldTrace>[];
    for (final trace in traces) {
      if (worldDeleted(trace.sourceDriveSessionId)) continue;
      var spans = <(double, double)>[
        (trace.startOffsetMeters, trace.endOffsetMeters),
      ];
      for (final cut in deleted.where(
        (d) =>
            d['sourceId'] == trace.sourceDriveSessionId &&
            d['roadId'] == trace.validatedRoadId &&
            d['sectionId'] == trace.matchedSectionId,
      )) {
        final from = (cut['start'] as num).toDouble();
        final to = (cut['end'] as num).toDouble();
        final next = <(double, double)>[];
        for (final span in spans) {
          if (to <= span.$1 || from >= span.$2) {
            next.add(span);
            continue;
          }
          if (from > span.$1) next.add((span.$1, from));
          if (to < span.$2) next.add((to, span.$2));
        }
        spans = next;
      }
      for (final span in spans) {
        if (span.$2 - span.$1 < MyWorldRules.minimumActiveTraceMeters) continue;
        if (span.$1 == trace.startOffsetMeters &&
            span.$2 == trace.endOffsetMeters) {
          result.add(trace);
        } else {
          result.add(
            trace.copyWith(
              id: '${trace.sourceDriveSessionId}:${trace.validatedRoadId}:${trace.matchedSectionId}:${span.$1.toStringAsFixed(3)}:${span.$2.toStringAsFixed(3)}',
              startOffsetMeters: span.$1,
              endOffsetMeters: span.$2,
            ),
          );
        }
      }
    }
    return result;
  }

  static Future<void> _tail = Future<void>.value();

  /// Shares the local critical section with World pointer commits. No network
  /// or rebuild is awaited inside this lock; stale generation remains a CAS.
  static Future<T> serialized<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Future<void> intent(String kind, String id) => serialized(() async {
    if (!available) throw StateError('Yerel silme günlüğü hazır değil.');
    final key = '$kind:$id';
    if (!box.containsKey(key)) {
      await box.put(key, {'version': 1, 'state': 'prepared'});
    }
    await box.flush();
  });

  static Future<void> complete(String kind, String id) async {
    final key = '$kind:$id';
    final prior = box.get(key) as Map?;
    if (prior == null) throw StateError('Silme işlemi günlüğü bulunamadı.');
    await box.put(key, {...prior, 'state': 'completed'});
    await box.flush();
  }

  static List<String> pending(String kind) => !available
      ? []
      : box.keys
            .whereType<String>()
            .where(
              (key) =>
                  key.startsWith('$kind:') &&
                  (box.get(key) as Map)['state'] != 'completed',
            )
            .map((key) => key.substring(kind.length + 1))
            .toList();
}
