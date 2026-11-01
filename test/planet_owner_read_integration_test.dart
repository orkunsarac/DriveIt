import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/services/owner_profile_gateway.dart';
import 'package:driveit_project/features/planet/services/planet_map_repository.dart';
import 'package:driveit_project/features/planet/services/planet_trace_detail_repository.dart';
import 'package:driveit_project/features/planet/services/planet_map_controller.dart';
import 'package:driveit_project/features/planet/models/planet_viewport.dart';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const url = 'https://arwnbogcswisfesayosy.supabase.co';
const trace = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const viewport = PlanetViewport(40, 40.1, 29, 29.1, 12);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SupabaseClient sdk;
  late LocalOwnerLifecycle owner;
  late OwnerProfileGateway gateway;
  late SupabasePlanetMapRepository map;
  late SupabasePlanetTraceDetailRepository detail;
  late Completer<void> entered;
  late Completer<void> release;
  late List<({String path, String? token})> requests;
  var uid = a;
  var token = 'synthetic-a';
  var hold = false;
  var denied = false;
  late http.Client transport;
  setUp(() async {
    uid = a;
    token = 'synthetic-a';
    hold = false;
    denied = false;
    requests = [];
    entered = Completer<void>();
    release = Completer<void>();
    root = await Directory.systemTemp.createTemp('driveit_planet_sdk_');
    sdk = SupabaseClient(
      url,
      'sb_publishable_synthetic',
      httpClient: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'synthetic',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': uid,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await sdk.auth.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic',
    );
    owner = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: SupabaseLocalOwnerAuth(sdk),
      openStore: (o) => OwnerScopedLocalStore.open(root: root.path, owner: o),
      driveInProgress: () async => false,
      automaticAccountSync: false,
      automaticAccountDownload: false,
      automaticCloudDeletionRetry: false,
    );
    await owner.start();
    final lease = owner.lease;
    transport = MockClient((r) async {
      requests.add((path: r.url.path, token: r.headers['authorization']));
      expect(r.url.host, 'arwnbogcswisfesayosy.supabase.co');
      expect([
        '/rest/v1/rpc/read_planet_viewport',
        '/functions/v1/planet-trace-detail',
      ], contains(r.url.path));
      if (hold) {
        if (requests.length >= 2 && !entered.isCompleted) entered.complete();
        await release.future;
      }
      if (denied) {
        return http.Response(
          '{"error_code":"unauthorized"}',
          401,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }
      final data = r.url.path.startsWith('/rest/')
          ? {
              'generation': '4',
              'state': 'ready',
              'traces': [
                {
                  'id': trace,
                  'style_key': 'style',
                  'distance_meters': '1000',
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [29, 40],
                      [29.01, 40.01],
                    ],
                  },
                },
              ],
              'privateGps': 'must never enter UI model',
            }
          : {
              'trace_id': trace,
              'generation': '4',
              'display_name': 'Shared driver',
              'username': 'shared',
              'drive_date': '2026-01-01T00:02:00Z',
              'distance_meters': 1000,
              'duration_seconds': 120,
              'average_speed_kmh': 30,
              'maximum_speed_kmh': 36,
              'ownership_distance_meters': 250,
              'score': null,
              'privateGps': 'must never enter UI model',
            };
      return http.Response(
        jsonEncode(data),
        200,
        request: r,
        headers: {'content-type': 'application/json'},
      );
    });
    gateway = OwnerProfileGateway(
      authClient: sdk,
      url: url,
      publicKey: 'sb_publishable_synthetic',
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => lease.owner.userId,
      approvedEpoch: () => lease.epoch,
      isLeaseCurrent: (e) => e == lease.epoch && lease.isCurrent,
      transport: transport,
    );
    map = SupabasePlanetMapRepository(gateway: gateway, ownerChanges: owner);
    detail = SupabasePlanetTraceDetailRepository(
      gateway: gateway,
      ownerChanges: owner,
    );
  });
  tearDown(() async {
    if (!release.isCompleted) release.complete();
    await owner.close();
    owner.dispose();
    await sdk.dispose();
    await root.delete(recursive: true);
  });
  test(
    'real repositories read only shared Planet contracts and retry denied requests',
    () async {
      expect((await map.read(viewport)).traces.single.id, trace);
      expect((await detail.read(trace)).displayName, 'Shared driver');
      expect(requests.every((r) => r.token == 'Bearer synthetic-a'), isTrue);
      expect(owner.lease.keys('drives'), isEmpty);
      denied = true;
      await expectLater(map.read(viewport), throwsA(isA<PlanetReadFailure>()));
      await expectLater(
        detail.read(trace),
        throwsA(isA<PlanetDetailFailure>()),
      );
      denied = false;
      expect((await detail.read(trace)).traceId, trace);
      expect(
        (await map.read(
          const PlanetViewport(40.1, 40.2, 29.1, 29.2, 12),
        )).traces.length,
        1,
      );
    },
  );
  for (final change in ['account', 'logout', 'epoch', 'refresh']) {
    test(
      'pending map/detail cannot cross $change owner credential boundary',
      () async {
        hold = true;
        final mapRead = map.read(viewport);
        final detailRead = detail.read(trace);
        final m = expectLater(mapRead, throwsA(isA<PlanetReadFailure>()));
        final d = expectLater(detailRead, throwsA(isA<PlanetDetailFailure>()));
        await entered.future;
        if (change == 'epoch') {
          await owner.retry();
        } else if (change == 'refresh') {
          token = 'synthetic-refresh';
          await sdk.auth.refreshSession();
        } else if (change == 'logout') {
          await sdk.auth.signOut();
        } else {
          uid = b;
          token = 'synthetic-b';
          await sdk.auth.signInWithPassword(
            email: 'b@example.invalid',
            password: 'synthetic',
          );
        }
        await Future<void>.delayed(Duration.zero);
        await owner.settled;
        hold = false;
        release.complete();
        await m;
        await d;
        expect(requests.every((r) => r.token == 'Bearer synthetic-a'), isTrue);
        if (change != 'refresh') {
          final count = requests.length;
          await expectLater(
            map.read(viewport),
            throwsA(isA<PlanetReadFailure>()),
          );
          await expectLater(
            detail.read(trace),
            throwsA(isA<PlanetDetailFailure>()),
          );
          expect(requests.length, count);
        } else {
          expect((await detail.read(trace)).traceId, trace);
          expect(requests.last.token, 'Bearer synthetic-refresh');
        }
      },
    );
  }
  for (final wrongProject in [true, false]) {
    test(
      'wrong ${wrongProject ? 'project' : 'owner'} rejects before HTTP',
      () async {
        final wrong = OwnerProfileGateway(
          authClient: sdk,
          url: wrongProject ? 'https://viqngnjfgknpxtoapzcg.supabase.co' : url,
          publicKey: 'sb_publishable_synthetic',
          applicationId: 'com.osaracx.driveit',
          approvedOwner: () => wrongProject ? a : b,
          approvedEpoch: () => owner.epoch,
          isLeaseCurrent: (e) => owner.lease.isCurrent,
          transport: transport,
        );
        await expectLater(
          SupabasePlanetMapRepository(gateway: wrong).read(viewport),
          throwsA(isA<PlanetReadFailure>()),
        );
        await expectLater(
          SupabasePlanetTraceDetailRepository(gateway: wrong).read(trace),
          throwsA(isA<PlanetDetailFailure>()),
        );
        expect(requests, isEmpty);
      },
    );
  }
  test('controller discards cached A map when real owner changes', () async {
    final controller = PlanetMapController(map);
    try {
      controller.cameraIdle(viewport);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.snapshot?.traces.length, 1);
      uid = b;
      token = 'synthetic-b';
      await sdk.auth.signInWithPassword(
        email: 'b@example.invalid',
        password: 'synthetic',
      );
      await Future<void>.delayed(Duration.zero);
      await owner.settled;
      expect(controller.snapshot, isNull);
      expect(controller.cachedRegionCount, 0);
    } finally {
      controller.dispose();
    }
  });
}
