import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../services/local_source_bundle.dart';
import '../config/my_world_rules.dart';
import '../models/validated_road.dart';

/// Additive preparation store. Never writes a source box or World index.
/// A complete payload is flushed before the ready marker; interruption before
/// promotion leaves a resumable staging entry, never an authoritative source.
class WorldSourceSnapshotRepository {
  static const boxName = 'my_world_source_snapshots_v1';
  WorldSourceSnapshotRepository(this.box);
  final Box<dynamic> box;
  static Future<void> open(HiveInterface hive) =>
      hive.openBox<dynamic>(boxName);
  static final Map<String, Future<void>> _queues = {};

  LocalSourceBundle? get(String id) {
    final raw = box.get(id);
    if (raw == null || (raw as Map)['ready'] != true) return null;
    if (raw['version'] != 1) throw StateError('Unsupported World snapshot');
    final bundle = LocalSourceBundle.fromMap(
      jsonDecode(raw['payload'] as String),
    );
    bundle.validate();
    if (bundle.drive.id != id) throw StateError('World snapshot key mismatch');
    return bundle;
  }

  List<LocalSourceBundle> getAll() => box.keys
      .whereType<String>()
      .map(get)
      .whereType<LocalSourceBundle>()
      .toList();

  Future<void> prepare(
    LocalSourceBundle source, {
    Future<void> Function()? afterStage,
  }) {
    final key = '${box.path}:${source.drive.id}';
    final previous = _queues[key] ?? Future<void>.value();
    final future = previous.then((_) => _prepare(source, afterStage));
    _queues[key] = future.then((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  Future<void> _prepare(
    LocalSourceBundle source,
    Future<void> Function()? afterStage,
  ) async {
    source.validate();
    final payload = jsonEncode(source.toMap());
    final existing = get(source.drive.id);
    if (existing != null) {
      final saved = existing.toMap();
      final proposed = source.toMap();
      if (existing.score != null &&
          source.score != null &&
          existing.score!.calculatedAt.isAfter(source.score!.calculatedAt)) {
        proposed['score'] = saved['score'];
      }
      final attachScore =
          proposed['score'] != null &&
          jsonEncode(saved['score']) != jsonEncode(proposed['score']);
      if (attachScore) saved['score'] = proposed['score'];
      if (proposed['score'] == null) proposed['score'] = saved['score'];
      if (source.roads.isEmpty) {
        saved['roads'] = <dynamic>[];
      }
      if (jsonEncode(saved) != jsonEncode(proposed)) {
        throw StateError('Immutable World source conflict');
      }
      if (attachScore) {
        final enriched = existing.toMap()..['score'] = proposed['score'];
        final text = jsonEncode(enriched);
        final checked = LocalSourceBundle.fromMap(jsonDecode(text));
        checked.validate();
        if (jsonEncode(checked.toMap()) != text) {
          throw StateError('Source score verification failed');
        }
        final prior = box.get(source.drive.id) as Map;
        final history = List<dynamic>.from(
          prior['scoreHistory'] as List? ?? [],
        );
        if (existing.score != null) history.add(existing.toMap()['score']);
        await box.put(source.drive.id, {
          ...prior,
          'payload': text,
          'scoreHistory': history,
        });
        await box.flush();
      }
      await box.flush();
      return;
    }
    final staged = box.get(source.drive.id) as Map?;
    if (staged != null && staged['payload'] != payload) {
      throw StateError('Staged World source conflict');
    }
    final entry = {
      'version': 1,
      'worldRulesVersion': MyWorldRules.worldRulesVersion,
      'ready': false,
      'payload': payload,
    };
    await box.put(source.drive.id, entry);
    await box.flush();
    await afterStage?.call();
    final stored = box.get(source.drive.id) as Map;
    final decoded = LocalSourceBundle.fromMap(
      jsonDecode(stored['payload'] as String),
    );
    decoded.validate();
    if (jsonEncode(decoded.toMap()) != payload) {
      throw StateError('World source verification failed');
    }
    await box.put(source.drive.id, {...entry, 'ready': true});
    await box.flush();
  }

  /// Enrich an already prepared new source after validation. This never
  /// backfills old drives automatically or replaces a canonical source.
  Future<void> attachRoad(ValidatedRoad road) {
    final key = '${box.path}:${road.driveSessionId}';
    final previous = _queues[key] ?? Future<void>.value();
    final future = previous.then((_) async {
      final source = get(road.driveSessionId);
      if (source == null) return;
      final bundle = LocalSourceBundle(
        drive: source.drive,
        telemetry: source.telemetry,
        score: source.score,
        ownerScope: source.ownerScope,
        roads: [...source.roads.where((r) => r.id != road.id), road],
      );
      bundle.validate();
      final payload = jsonEncode(bundle.toMap());
      final existing = source.roads.where((r) => r.id == road.id);
      if (existing.isNotEmpty) {
        if (jsonEncode(source.toMap()) == payload) {
          await box.flush();
          return;
        }
      }
      final decoded = LocalSourceBundle.fromMap(jsonDecode(payload));
      decoded.validate();
      if (jsonEncode(decoded.toMap()) != payload) {
        throw StateError('Validated source verification failed');
      }
      final prior = box.get(road.driveSessionId) as Map;
      // Provider retry may update the same validated-road ID. Preserve the
      // prior validation payload and advance only its derived revision;
      // canonical drive/telemetry/score source remains immutable.
      final history = List<dynamic>.from(
        prior['validationHistory'] ?? const [],
      );
      if (existing.isNotEmpty) history.add(source.toMap()['roads']);
      await box.put(road.driveSessionId, {
        'version': 1,
        'worldRulesVersion': MyWorldRules.worldRulesVersion,
        'ready': true,
        'payload': payload,
        'revision': (prior['revision'] as int? ?? 0) + 1,
        'validationHistory': history,
      });
      await box.flush();
    });
    _queues[key] = future.then((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }
}
