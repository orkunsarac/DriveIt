import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment.dart';
import 'package:driveit_project/features/world_publish/segments/planet_segment_outbox.dart';
import '../test/planet_segment_test.dart' as fixtures;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android segment outbox survives reopen without duplicate submission',
    (_) async {
      final root = await Directory(
        '${await getDatabasesPath()}/planet_segments_${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      Hive.init(root.path);
      try {
        await PlanetSegmentOutbox.open(Hive);
        var box = Hive.box<dynamic>(PlanetSegmentOutbox.boxName);
        final gateway = fixtures.FakeGateway()..loseResponse = true;
        var outbox = PlanetSegmentOutbox(box, gateway: gateway);
        final preview = const PlanetSegmentBuilder().build(
          'drive',
          fixtures.fixture([8000, 4000, 12000]),
        );
        await outbox.prepare('synthetic-owner', preview.segments);
        expect(box.length, 2);
        await outbox.deliver('synthetic-owner', preview.eligible.first.id);
        expect(outbox.acceptedDistance('synthetic-owner'), 0);
        await Hive.close();
        await PlanetSegmentOutbox.open(Hive);
        box = Hive.box<dynamic>(PlanetSegmentOutbox.boxName);
        outbox = PlanetSegmentOutbox(box, gateway: gateway);
        await outbox.deliver('synthetic-owner', preview.eligible.first.id);
        expect(gateway.submits, 1);
        expect(outbox.acceptedDistance('synthetic-owner'), 8000);
        expect(
          outbox.entry('synthetic-owner', preview.eligible.last.id)!['state'],
          'queued',
        );
        await PlanetSegmentOutbox(
          box,
        ).deliver('synthetic-owner', preview.eligible.last.id);
        expect(gateway.submits, 1);
      } finally {
        await Hive.close();
        await root.delete(recursive: true);
      }
    },
  );
}
