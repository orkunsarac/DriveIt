import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import '../config/local_ownership_gate.dart';
import 'legacy_source_writer_fence.dart';

class _WriterTicket {
  bool active = true;
}

/// One admission/drain boundary for controlled source writers. It does NOT
/// stop GPS: an active/unreadable native producer makes import unavailable.
class LocalSourceWriterFence implements RegisteredSourceWriterFence {
  LocalSourceWriterFence({
    required this.gate,
    required this.gpsBusy,
    required Set<String> provenCategories,
    required List<String> sourceRoots,
    this.timeout = const Duration(seconds: 15),
  }) : provenCategories = Set.unmodifiable(provenCategories),
       sourceRoots = List.unmodifiable(sourceRoots);
  final LocalOwnershipGate gate;
  final Future<bool> Function() gpsBusy;
  final Set<String> provenCategories;
  final List<String> sourceRoots;
  final Duration timeout;
  static const requiredCategories = {
    'history',
    'gps_transfer',
    'career',
    'world_source',
    'world_index',
    'world_jobs',
    'lifecycle',
    'poster',
    'profile',
    'planet',
    'settings',
    'telemetry',
    'score',
    'scoped',
  };
  final Set<Future<Object?>> _pending = {};
  final Object _zoneKey = Object();
  bool _paused = false;
  bool _draining = false;
  bool _poisoned = false;
  bool get paused => _paused;
  int get pendingCount => _pending.length;
  @override
  void requireRegistered() {
    if (!identical(SourceWriterBoundary._fence, this) || sourceRoots.isEmpty) {
      throw StateError('Source writers not installed');
    }
  }

  bool isSource(String path) {
    String normalized(String value) {
      final entity = FileSystemEntity.typeSync(value);
      final resolved = entity == FileSystemEntityType.directory
          ? Directory(value).resolveSymbolicLinksSync()
          : entity != FileSystemEntityType.notFound
          ? File(value).resolveSymbolicLinksSync()
          : File(value).absolute.path;
      final path = resolved.replaceAll('\\', '/');
      return Platform.isWindows ? path.toLowerCase() : path;
    }

    final value = normalized(path);
    return sourceRoots.any((root) {
      final base = normalized(root).replaceAll(RegExp(r'/+$'), '');
      return value == base || value.startsWith('$base/');
    });
  }

  Future<T> write<T>(
    String category,
    Future<T> Function() action, {
    String? path,
  }) {
    if (!gate.enabled) return action();
    if (path != null && !isSource(path)) return action();
    if (!provenCategories.contains(category)) {
      _poisoned = true;
      return Future.error(StateError('Unregistered source writer'));
    }
    final parent = Zone.current[_zoneKey];
    final admittedParent = parent is _WriterTicket && parent.active;
    if (_paused && !admittedParent) {
      return Future.error(StateError('Source writes paused'));
    }
    final ticket = _WriterTicket();
    final future = runZoned(
      () => Future<T>.sync(action),
      zoneValues: {_zoneKey: ticket},
    );
    late Future<Object?> observed;
    observed = future.then<Object?>(
      (value) => value,
      onError: (Object error, StackTrace stack) {
        _poisoned = true;
        Error.throwWithStackTrace(error, stack);
      },
    );
    _pending.add(observed);
    return observed
        .whenComplete(() {
          ticket.active = false;
          _pending.remove(observed);
        })
        .then((value) => value as T);
  }

  @override
  Future<void> pauseAndDrain() async {
    if (!gate.enabled ||
        _paused ||
        _poisoned ||
        !provenCategories.containsAll(requiredCategories)) {
      throw StateError('Source writer coverage/drain unavailable');
    }
    if (Zone.current[_zoneKey] case final _WriterTicket ticket
        when ticket.active) {
      throw StateError('Import cannot drain its own source write');
    }
    _paused = true; // Reject admission BEFORE checking native producer.
    _draining = true;
    try {
      if (await gpsBusy().timeout(timeout)) {
        throw StateError('GPS session must finish before import');
      }
      Future<void> drain() async {
        // A admitted operation may enqueue an unawaited background job while
        // draining. Track nested writes independently and re-check the set.
        while (_pending.isNotEmpty) {
          await Future.wait(_pending.toList());
        }
      }

      await drain().timeout(timeout);
      if (_poisoned || await gpsBusy().timeout(timeout)) {
        throw StateError('Source writer drain not proven');
      }
    } catch (_) {
      _paused =
          false; // Import never started; existing writes retain their data.
      rethrow;
    } finally {
      _draining = false;
    }
  }

  @override
  Future<void> resume() async {
    if (_draining) throw StateError('Source drain still in progress');
    _paused = false;
  }
}

/// No installation in production. Constructors/getters preserve original Box
/// identity when OFF. Controlled bootstrap installs BEFORE opening sources.
abstract final class SourceWriterBoundary {
  static LocalSourceWriterFence? _fence;
  static void installForTesting(LocalSourceWriterFence fence) {
    if (!LocalOwnershipGate.debugBuild ||
        !fence.gate.enabled ||
        _fence != null) {
      throw StateError('Controlled writer fence unavailable');
    }
    _fence = fence;
  }

  static Future<void> detachForTesting(LocalSourceWriterFence fence) async {
    if (!identical(_fence, fence) || fence.paused || fence.pendingCount != 0) {
      throw StateError('Writer fence still in use');
    }
    _fence = null;
  }

  static Future<T> run<T>(
    String category,
    Future<T> Function() action, {
    String? path,
  }) => _fence?.write(category, action, path: path) ?? action();
  static Box<T> box<T>(String category, Box<T> box) =>
      _fence == null || box is _WriterBox<T> ? box : _WriterBox(category, box);
}

/// Flush is included in every admitted mutation; reads are untouched. Complete
/// multi-step operations must ALSO use run(), so drain cannot split a commit.
class _WriterBox<T> implements Box<T> {
  _WriterBox(this.category, this.inner);
  final String category;
  final Box<T> inner;
  Future<R> _mutate<R>(Future<R> Function() action) =>
      SourceWriterBoundary.run(category, () async {
        final result = await action();
        await inner.flush();
        return result;
      }, path: inner.path);
  @override
  String get name => inner.name;
  @override
  bool get isOpen => inner.isOpen;
  @override
  String? get path => inner.path;
  @override
  bool get lazy => inner.lazy;
  @override
  Iterable<dynamic> get keys => inner.keys;
  @override
  Iterable<T> get values => inner.values;
  @override
  int get length => inner.length;
  @override
  bool get isEmpty => inner.isEmpty;
  @override
  bool get isNotEmpty => inner.isNotEmpty;
  @override
  dynamic keyAt(int index) => inner.keyAt(index);
  @override
  bool containsKey(dynamic key) => inner.containsKey(key);
  @override
  T? get(dynamic key, {T? defaultValue}) =>
      inner.get(key, defaultValue: defaultValue);
  @override
  T? getAt(int index) => inner.getAt(index);
  @override
  Map<dynamic, T> toMap() => inner.toMap();
  @override
  Iterable<T> valuesBetween({dynamic startKey, dynamic endKey}) =>
      inner.valuesBetween(startKey: startKey, endKey: endKey);
  @override
  Stream<BoxEvent> watch({dynamic key}) => inner.watch(key: key);
  @override
  Future<void> put(dynamic key, T value) =>
      _mutate(() => inner.put(key, value));
  @override
  Future<void> putAt(int index, T value) =>
      _mutate(() => inner.putAt(index, value));
  @override
  Future<void> putAll(Map<dynamic, T> entries) =>
      _mutate(() => inner.putAll(entries));
  @override
  Future<int> add(T value) => _mutate(() => inner.add(value));
  @override
  Future<Iterable<int>> addAll(Iterable<T> values) =>
      _mutate(() => inner.addAll(values));
  @override
  Future<void> delete(dynamic key) => _mutate(() => inner.delete(key));
  @override
  Future<void> deleteAt(int index) => _mutate(() => inner.deleteAt(index));
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) =>
      _mutate(() => inner.deleteAll(keys));
  @override
  Future<int> clear() => _mutate(inner.clear);
  @override
  Future<void> compact() =>
      SourceWriterBoundary.run(category, inner.compact, path: inner.path);
  @override
  Future<void> deleteFromDisk() =>
      Future.error(StateError('Source disk deletion not permitted'));
  @override
  Future<void> flush() => inner.flush();
  @override
  Future<void> close() =>
      SourceWriterBoundary.run(category, inner.close, path: inner.path);
}
