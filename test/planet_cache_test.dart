import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driveit_project/features/planet/models/planet_viewport.dart';
import 'package:driveit_project/features/planet/services/planet_map_controller.dart';
import 'package:driveit_project/features/planet/services/planet_map_repository.dart';
import 'package:driveit_project/features/planet/services/planet_map_presentation.dart';

class _Repository implements PlanetMapRepository {
  final viewports = <PlanetViewport>[];
  final replies = <Completer<PlanetSnapshot>>[];
  @override
  Future<PlanetSnapshot> read(PlanetViewport viewport) {
    viewports.add(viewport);
    final reply = Completer<PlanetSnapshot>();
    replies.add(reply);
    return reply.future;
  }
}

const a = PlanetViewport(40, 40.1, 29, 29.1, 12);
const b = PlanetViewport(41, 41.1, 30, 30.1, 12);
PlanetSnapshot result(int generation, List<String> ids) =>
    PlanetSnapshot(BigInt.from(generation), false, [
      for (final id in ids)
        PlanetTrace(id, id, 5000, const [LatLng(40, 29), LatLng(40.1, 29.1)]),
    ]);
Future<void> tick(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 301));
void main() {
  testWidgets(
    'persistent initial/background merge, dedup, return and failure',
    (tester) async {
      final repo = _Repository(), c = PlanetMapController(_Repository());
      c.dispose();
      final controller = PlanetMapController(repo);
      controller.cameraIdle(a);
      expect(controller.initialLoading, isTrue);
      await tick(tester);
      repo.replies.last.complete(result(4, ['one']));
      await tester.pump();
      final original = controller.snapshot;
      expect(original!.traces.length, 1);
      controller.cameraIdle(
        const PlanetViewport(40.005, 40.105, 29.005, 29.105, 11),
      );
      await tick(tester);
      expect(repo.replies.length, 1);
      expect(controller.snapshot, same(original));
      controller.cameraIdle(b);
      expect(controller.loading, isTrue);
      expect(controller.initialLoading, isFalse);
      expect(controller.snapshot, same(original));
      await tick(tester);
      repo.replies.last.complete(result(4, ['one', 'two']));
      await tester.pump();
      expect(controller.snapshot!.traces.map((t) => t.id), ['one', 'two']);
      controller.cameraIdle(a);
      await tick(tester);
      expect(repo.replies.length, 2);
      controller.cameraIdle(const PlanetViewport(42, 42.1, 31, 31.1, 12));
      await tick(tester);
      final previous = controller.snapshot;
      repo.replies.last.completeError(const PlanetReadFailure('Network error'));
      await tester.pump();
      expect(controller.snapshot, same(previous));
      expect(controller.error, 'Network error');
      controller.dispose();
    },
  );

  testWidgets('initial failure retry and dispose during request', (
    tester,
  ) async {
    final repo = _Repository(), controller = PlanetMapController(_Repository());
    controller.dispose();
    final c = PlanetMapController(repo);
    c.cameraIdle(a);
    await tick(tester);
    repo.replies.last.completeError(const PlanetReadFailure('offline'));
    await tester.pump();
    expect(c.snapshot, isNull);
    expect(c.loading, isFalse);
    c.retry();
    await tick(tester);
    c.dispose();
    repo.replies.last.complete(result(4, ['one']));
    await tester.pump();
    expect(c.snapshot, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'out of order ignored, generation replaces old regions atomically',
    (tester) async {
      final repo = _Repository(), c = PlanetMapController(_Repository());
      c.dispose();
      final controller = PlanetMapController(repo);
      controller.cameraIdle(a);
      await tick(tester);
      controller.cameraIdle(b);
      await tick(tester);
      repo.replies[1].complete(result(4, ['new']));
      await tester.pump();
      repo.replies[0].complete(result(3, ['stale']));
      await tester.pump();
      expect(controller.snapshot!.traces.single.id, 'new');
      controller.cameraIdle(a);
      await tick(tester);
      expect(controller.snapshot!.traces.single.id, 'new');
      repo.replies.last.complete(result(5, ['replacement']));
      await tester.pump();
      expect(controller.snapshot!.traces.single.id, 'replacement');
      expect(controller.cachedRegionCount, 1);
      controller.cameraIdle(b);
      await tick(tester);
      repo.replies.last.complete(result(4, ['older']));
      await tester.pump();
      expect(controller.snapshot!.generation, BigInt.from(5));
      expect(controller.error, isNotNull);
      controller.dispose();
    },
  );

  testWidgets('zoom nine displays cached traces without backend request', (
    tester,
  ) async {
    final repo = _Repository(), c = PlanetMapController(repo);
    c.cameraIdle(a);
    await tick(tester);
    repo.replies.last.complete(result(4, ['one']));
    await tester.pump();
    c.cameraIdle(const PlanetViewport(39.5, 40.5, 28.5, 29.5, 9));
    await tick(tester);
    expect(repo.replies.length, 1);
    expect(c.zoomIn, isTrue);
    expect(PlanetMapPresentation.draw(c.snapshot!, 9).polylines.length, 2);
    expect(PlanetMapPresentation.draw(c.snapshot!, 8.9).polylines, isEmpty);
    c.cameraIdle(a);
    await tick(tester);
    expect(repo.replies.length, 1);
    expect(c.zoomIn, isFalse);
    c.dispose();
  });

  testWidgets(
    'TTL refresh preserves drawing; LRU and vertex budgets evict coverage',
    (tester) async {
      var now = DateTime(2026);
      final repo = _Repository(),
          c = PlanetMapController(
            repo,
            maxRegions: 2,
            maxVertices: 4,
            now: () => now,
          );
      for (final view in [a, b, const PlanetViewport(42, 42.1, 31, 31.1, 12)]) {
        c.cameraIdle(view);
        await tick(tester);
        repo.replies.last.complete(result(4, ['trace${repo.replies.length}']));
        await tester.pump();
      }
      expect(c.cachedRegionCount, 2);
      expect(c.snapshot!.traces.length, 2);
      c.cameraIdle(a); // Evicted coverage must fetch again.
      await tick(tester);
      expect(repo.replies.length, 4);
      repo.replies.last.complete(result(4, ['trace1']));
      await tester.pump();
      now = now.add(const Duration(seconds: 61));
      final previous = c.snapshot;
      c.cameraIdle(a);
      expect(c.snapshot, same(previous));
      await tick(tester);
      repo.replies.last.complete(result(4, ['trace1']));
      await tester.pump();
      expect(c.snapshot, same(previous));
      c.dispose();
    },
  );

  testWidgets('ten city pans: persistent data, zoom redraw without empty set', (
    tester,
  ) async {
    final repo = _Repository(), c = PlanetMapController(repo);
    c.cameraIdle(a);
    await tick(tester);
    repo.replies.last.complete(result(4, ['one']));
    await tester.pump();
    final drawing = c.snapshot;
    var presentationDraws = 1;
    for (var i = 1; i <= 10; i++) {
      final delta = i * .001;
      c.cameraIdle(
        PlanetViewport(
          40 + delta,
          40.1 + delta,
          29 + delta,
          29.1 + delta,
          12 + i * .05,
        ),
      );
      expect(c.snapshot, same(drawing));
      expect(
        PlanetMapPresentation.draw(c.snapshot!, 12 + i * .05).polylines.length,
        2,
      );
      presentationDraws++;
      await tick(tester);
    }
    expect(c.requestCount, 1);
    expect(c.mergeCount, 1);
    expect(c.drawingSetChanges, 1);
    // Original exact-key implementation: 11 RPC, 22 snapshot transitions
    // (null + response). Initial load included in both measurements.
    debugPrint(
      'PLANET_CAMERA old_rpc=11 new_rpc=${c.requestCount} '
      'old_snapshot_transitions=22 new_data_updates=${c.drawingSetChanges} '
      'zoom_presentation_draws=$presentationDraws merges=${c.mergeCount}',
    );
    c.dispose();
  });

  test('buffer safety, dateline coverage and no unsafe wide query', () {
    final padded = a.buffered();
    expect(padded.contains(a), isTrue);
    expect(padded.canFetch, isTrue);
    const dateLine = PlanetViewport(0, .2, 179.9, -179.9, 12);
    expect(dateLine.buffered().contains(dateLine), isTrue);
    expect(dateLine.canFetch, isTrue);
    expect(const PlanetViewport(0, 1.1, 0, 1.1, 10).canFetch, isFalse);
  });
  testWidgets('same-ID metadata/geometry update without duplicate drawing', (
    tester,
  ) async {
    final repo = _Repository(), c = PlanetMapController(repo);
    c.cameraIdle(a);
    await tick(tester);
    repo.replies.last.complete(result(4, ['one']));
    await tester.pump();
    c.retry();
    await tick(tester);
    repo.replies.last.complete(
      PlanetSnapshot(BigInt.from(4), false, [
        PlanetTrace('one', 'changed', 6000, const [
          LatLng(40, 29),
          LatLng(40.2, 29.2),
        ]),
      ]),
    );
    await tester.pump();
    expect(c.snapshot!.traces.single.styleKey, 'changed');
    final drawing = PlanetMapPresentation.draw(c.snapshot!, 12);
    expect(drawing.polylines.length, 2);
    expect(drawing.circles.length, 2);
    c.dispose();
  });
  testWidgets(
    'pending coverage deduplicates and server zoom guard preserves drawing',
    (tester) async {
      final repo = _Repository(), c = PlanetMapController(repo);
      c.cameraIdle(a);
      await tick(tester);
      c.cameraIdle(const PlanetViewport(40.001, 40.101, 29.001, 29.101, 11));
      await tick(tester);
      expect(repo.replies.length, 1);
      repo.replies.last.complete(result(4, ['one']));
      await tester.pump();
      final previous = c.snapshot;
      c.cameraIdle(b);
      await tick(tester);
      repo.replies.last.complete(
        PlanetSnapshot(BigInt.from(5), true, const []),
      );
      await tester.pump();
      expect(c.snapshot, same(previous));
      expect(c.cachedRegionCount, 0);
      c.cameraIdle(a);
      await tick(tester);
      repo.replies.last.complete(result(5, ['authoritative']));
      await tester.pump();
      expect(c.snapshot!.traces.single.id, 'authoritative');
      c.dispose();
    },
  );
}
