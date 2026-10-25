import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/models/route_point.dart';
import 'package:driveit_project/screens/history_screen.dart';
import 'package:driveit_project/screens/home_screen.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/local_source_bundle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/widgets/local_owner_view.dart';
import 'package:driveit_project/widgets/neon_route_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'local_owner_integration_test.dart' show TestAuth, b;

const _asset = 'assets/branding/driveit_drives_route.png';
const _assetKey = Key('home_drives_route_asset');

DriveSession _drive(int index) => DriveSession(
  id: 'synthetic-$index',
  date: DateTime(2026, 1, index + 1),
  distance: 1000.0 * (index + 1),
  durationSeconds: 60,
  averageSpeed: 30,
  maxSpeed: 40,
  mapImagePath: '',
  route: [
    RoutePoint(latitude: 1.0 + index, longitude: 1),
    RoutePoint(latitude: 1.1 + index, longitude: 1.2),
  ],
);

Future<void> _home(
  WidgetTester tester, {
  LocalOwnerLease? lease,
  String? expectedGreeting,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: HomeScreen(ownerLease: lease),
    ),
  );
  await tester.pump();
  final image = tester.widget<Image>(find.byKey(_assetKey));
  expect(image.image, const AssetImage(_asset));
  expect(image.fit, BoxFit.contain);
  expect(image.excludeFromSemantics, isTrue);
  if (expectedGreeting != null) {
    expect(find.text('Merhaba, $expectedGreeting'), findsOneWidget);
  }
  expect(
    tester
        .getSize(
          find
              .ancestor(
                of: find.byKey(_assetKey),
                matching: find.byType(SizedBox),
              )
              .first,
        )
        .height,
    68,
  );
  expect(tester.takeException(), isNull);
}

void _expectPersonalPreview(WidgetTester tester, DriveSession drive) {
  final previews = tester.widgetList<NeonRoutePreview>(
    find.byType(NeonRoutePreview),
  );
  expect(previews, hasLength(1));
  expect(
    previews.single.route.map((p) => p.latitude),
    drive.route.map((p) => p.latitude),
  );
  expect(
    previews.single.route.map((p) => p.longitude),
    drive.route.map((p) => p.longitude),
  );
}

Future<void> _openHistory(WidgetTester tester, DriveSession drive) async {
  await tester.ensureVisible(find.text('Sürüşlerim'));
  await tester.tap(find.text('Sürüşlerim'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(HistoryScreen), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(HistoryScreen),
      matching: find.byKey(_assetKey),
    ),
    findsNothing,
  );
  final historyRoutes = tester.widgetList<NeonRoutePreview>(
    find.descendant(
      of: find.byType(HistoryScreen),
      matching: find.byType(NeonRoutePreview),
    ),
  );
  expect(
    historyRoutes.any(
      (preview) => preview.route.first.latitude == drive.route.first.latitude,
    ),
    isTrue,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'branding PNG has fixed dimensions and no identifying metadata',
    () async {
      final bytes = await File(_asset).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 352);
      expect(frame.image.height, 272);
      var offset = 8;
      final chunks = <String>[];
      while (offset < bytes.length) {
        final length = bytes.buffer.asByteData().getUint32(offset);
        chunks.add(ascii.decode(bytes.sublist(offset + 4, offset + 8)));
        offset += length + 12;
      }
      // Flutter also writes color-space/bit-depth chunks; allow no text, EXIF,
      // timestamp or other chunks that could carry source identity/location.
      expect(
        chunks,
        everyElement(isIn(['IHDR', 'sBIT', 'sRGB', 'IDAT', 'IEND'])),
      );
      final pixels = await frame.image.toByteData();
      expect(
        pixels!.getUint8(3),
        0,
      ); // Transparent background, not a card image.
      frame.image.dispose();
      codec.dispose();
    },
  );

  group('legacy Home', () {
    late Directory root;
    late Box<DriveSession> drives;
    late Box<dynamic> symbolic;
    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'driveit_fixed_route_legacy_',
      );
      Hive.init(root.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DriveSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(RoutePointAdapter());
      }
      drives = await Hive.openBox<DriveSession>('drives');
      symbolic = await Hive.openBox<dynamic>('symbolic_routes');
      await Hive.openBox<dynamic>('profile');
    });
    tearDown(() async {
      await Hive.close();
      await root.delete(recursive: true);
    });

    testWidgets(
      'zero, one, multiple and removed drives keep the same asset without symbolic writes',
      (tester) async {
        await _home(tester);
        expect(find.text('Toplam Sürüş 0'), findsOneWidget);
        for (var i = 0; i < 2; i++) {
          final drive = _drive(i);
          await tester.runAsync(() => drives.put(drive.id, drive));
          await _home(tester);
          expect(find.text('Toplam Sürüş ${i + 1}'), findsOneWidget);
          _expectPersonalPreview(tester, drive);
          expect(symbolic.isEmpty, isTrue);
        }
        await _openHistory(tester, _drive(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => drives.clear());
        await _home(tester);
        expect(find.text('Toplam Sürüş 0'), findsOneWidget);
        expect(symbolic.isEmpty, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'existing symbolic Hive record is preserved and never used by the card',
      (tester) async {
        const stored = [
          {'lat': 2.0, 'lng': 3.0},
          {'lat': 4.0, 'lng': 5.0},
        ];
        await tester.runAsync(
          () => symbolic.put('driveit_symbolic_route', stored),
        );
        final before = jsonEncode(symbolic.toMap());
        await tester.runAsync(() => drives.put('synthetic-0', _drive(0)));
        await _home(tester);
        _expectPersonalPreview(tester, _drive(0));
        expect(jsonEncode(symbolic.toMap()), before);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  testWidgets(
    'owner Home keeps the asset across drive counts and owner changes; personal previews remain scoped',
    (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('driveit_fixed_route_owner_'),
      );
      final auth = TestAuth();
      late OwnerScopedLocalStore store;
      final runtime = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: auth,
        openStore: (owner) async {
          store = await OwnerScopedLocalStore.open(
            root: root!.path,
            owner: owner,
          );
          return store;
        },
        driveInProgress: () async => false,
      );
      try {
        await tester.runAsync(runtime.start);
        await tester.runAsync(
          () => runtime.lease.put('profile', 'display_name', 'Misafir Ada'),
        );
        await _home(
          tester,
          lease: runtime.lease,
          expectedGreeting: 'Misafir Ada',
        );
        expect(find.text('Toplam Sürüş 0'), findsOneWidget);
        for (var i = 0; i < 2; i++) {
          final drive = _drive(i);
          await tester.runAsync(
            () => runtime.lease.put('drives', drive.id, drive),
          );
          await _home(tester, lease: runtime.lease);
          expect(find.text('Toplam Sürüş ${i + 1}'), findsOneWidget);
          _expectPersonalPreview(tester, drive);
          expect(runtime.lease.keys('symbolic_routes'), isEmpty);
        }
        await _openHistory(tester, _drive(1));
        await _home(tester, lease: runtime.lease);
        await tester.runAsync(() async {
          auth.emit(b);
          await runtime.settled;
        });
        await tester.pump();
        expect(find.byType(OwnerAccessUnavailable), findsOneWidget);
        await _home(tester, lease: runtime.lease);
        expect(find.text('Toplam Sürüş 0'), findsOneWidget);
        await tester.runAsync(
          () => runtime.lease.put('drives', 'synthetic-2', _drive(2)),
        );
        await _home(tester, lease: runtime.lease);
        _expectPersonalPreview(tester, _drive(2));
        // Prepare the synthetic record's independent source and Career basis,
        // as required by the existing safe History deletion contract.
        await tester.runAsync(() async {
          final source = LocalSourceBundle(
            drive: _drive(2),
            ownerScope: store.scope,
          );
          final repositories = store.repositories(store.owner);
          await repositories.prepareSource(source);
          expect(
            await repositories.prepareCareerBaseline(
              [source],
              {
                'countedIds': [source.drive.id],
                'totalDistance': source.drive.distance,
                'totalDuration': source.drive.durationSeconds,
              },
            ),
            isTrue,
          );
        });
        await tester.runAsync(() => runtime.lease.deleteHistory('synthetic-2'));
        await _home(tester, lease: runtime.lease);
        expect(find.text('Toplam Sürüş 0'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await runtime.close();
          runtime.dispose();
          await auth.events.close();
          await root!.delete(recursive: true);
        });
      }
    },
  );
}
