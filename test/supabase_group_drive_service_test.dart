import 'dart:convert';
import 'dart:io';

import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/features/group_drive/group_drive_models.dart';
import 'package:driveit_project/features/group_drive/group_drive_map.dart';
import 'package:driveit_project/features/group_drive/group_drive_service.dart';
import 'package:driveit_project/features/group_drive/supabase_group_drive_service.dart';
import 'package:driveit_project/services/local_owner_lifecycle.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as maps;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_owner_integration_test.dart' show TestAuth, a, b;
import 'group_drive_map_fake.dart';

/// Uses the installed SDK's real frame decoder and channel callback. Only
/// HTTP and socket connectivity are synthetic; no remote security acceptance
/// is implied by these host tests.
class _SdkGroupFixture {
  final now = DateTime.utc(2026, 10, 17, 12);
  int generation = 7;
  bool paused = false;
  int tokenLifetime = 3600;
  int tokenRequests = 0;
  bool rejectRefresh = false;
  bool liveClock = false;
  String? phase = 'running';
  String? rpcFailureCode, rpcFailureMessage;
  bool left = false;
  String ownMembership = 'member-a';
  final commands = <String>[];
  late Directory root;
  final auth = TestAuth();
  late LocalOwnerLifecycle runtime;
  late SupabaseClient supabase;
  late GroupDriveClient client;
  late GroupDriveSnapshot initial;

  static Future<_SdkGroupFixture> create() async {
    final fixture = _SdkGroupFixture();
    await fixture._open();
    return fixture;
  }

  Future<void> _open() async {
    root = await Directory.systemTemp.createTemp('group_sdk_envelope_');
    runtime = LocalOwnerLifecycle(
      gate: LocalOwnershipGate.synthetic(),
      auth: auth,
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      driveInProgress: () async => false,
    );
    await runtime.start();
    supabase = SupabaseClient(
      'https://group-contract.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object? response;
        if (request.url.path.endsWith('/token')) {
          tokenRequests++;
          if (rejectRefresh) {
            return http.Response(
              jsonEncode({
                'error': 'invalid_grant',
                'error_description': 'synthetic refresh rejection',
              }),
              400,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          response = {
            'access_token':
                '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': a, 'aud': 'authenticated', 'role': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + tokenLifetime})))}.synthetic',
            'refresh_token': 'synthetic-refresh-token',
            'token_type': 'bearer',
            'expires_in': tokenLifetime,
            'user': {
              'id': a,
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else {
          final action = (jsonDecode(request.body) as Map)['p_action'];
          if (action is String) commands.add(action);
          if (action == 'join' && rpcFailureCode != null) {
            return http.Response(
              jsonEncode({
                'code': rpcFailureCode,
                'message': rpcFailureMessage,
                'details': null,
                'hint': null,
              }),
              409,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (action == 'leave') {
            left = true;
            generation++;
          }
          if (action == 'join' && left) {
            left = false;
            generation++;
            ownMembership = 'member-a-rejoined';
          }
          if (action == 'start') phase = 'running';
          if (action == 'share_pause') {
            paused = true;
            generation++;
          }
          response = {
            'id': 'test-group',
            'generation': generation,
            'observedAt': (liveClock ? DateTime.now().toUtc() : now)
                .toIso8601String(),
            'createdAt': now.toIso8601String(),
            'expiresAt': now.add(const Duration(hours: 12)).toIso8601String(),
            'status': 'active',
            if (phase != null) 'phase': phase,
            'extensionCount': 0,
            'revision': generation,
            'inviteCode': '00000000-0000-4000-8000-000000000001',
            if (action == 'share_start')
              'grant': {
                'membershipId': 'member-a',
                'publicationId': 'synthetic-publication',
                'generation': generation,
                'startedAt': DateTime.now().toUtc().toIso8601String(),
              },
            'members': [
              for (final (id, account, order) in [
                (ownMembership, a, 0),
                ('member-b', b, 1),
              ])
                {
                  'membershipId': id,
                  'accountId': account,
                  'displayName': order == 0 ? 'A' : 'B',
                  'joinedAt': now.toIso8601String(),
                  'joinOrder': order,
                  'role': order == 0 ? 'administrator' : 'member',
                  'sharingStatus': paused && order == 0 ? 'paused' : 'sharing',
                  'location': null,
                  'colorIndex': order,
                },
            ],
          };
          if (action == 'current' && left) response = null;
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await supabase.auth.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic',
    );
    // Keep the actual SDK dispatcher but avoid opening any network transport.
    supabase.realtime.connState = SocketStates.open;
    client = SupabaseGroupDriveService(supabase).forOwner(runtime.lease);
    initial = (await client.current())!;
  }

  String get topic => 'realtime:driveit:group:test-group:$generation';
  Map<String, Object?> point({
    String member = 'member-a',
    int sequence = 1,
  }) => {
    'generation': generation,
    'membershipId': member,
    'latitude': 10.0,
    'longitude': 20.0,
    'accuracyMeters': 12.0,
    'sequence': sequence,
    'recordedAt': now.subtract(const Duration(seconds: 1)).toIso8601String(),
  };

  void send(
    Object? payload, {
    String? topic,
    String event = 'location',
    String type = 'broadcast',
  }) {
    // Protocol 2 frame -> SDK decoder -> Broadcast envelope -> service callback.
    supabase.realtime.onConnMessage(
      jsonEncode([
        null,
        null,
        topic ?? this.topic,
        'broadcast',
        {'type': type, 'event': event, 'payload': payload},
      ]),
    );
  }

  Future<void> close() async {
    supabase.realtime.connState = SocketStates.closed;
    await client.close();
    await supabase.dispose();
    await runtime.close();
    runtime.dispose();
    await auth.events.close();
    await root.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SDK 2.13 production Realtime callback', () {
    late _SdkGroupFixture fixture;
    setUp(() async => fixture = await _SdkGroupFixture.create());
    tearDown(() => fixture.close());

    test(
      'membership RPC errors stay distinct from transport and Realtime failures',
      () async {
        for (final (code, message, expected) in [
          ('42501', 'membership_banned', 'membership_banned'),
          ('23505', 'duplicate membership', 'membership_conflict'),
          ('PT409', 'group_full', 'group_full'),
          ('P0002', 'invite_unavailable', 'invite_unavailable'),
        ]) {
          fixture.rpcFailureCode = code;
          fixture.rpcFailureMessage = message;
          await expectLater(
            fixture.client.join(fixture.initial.invite),
            throwsA(
              isA<GroupDriveException>().having(
                (e) => e.code,
                'code',
                expected,
              ),
            ),
          );
        }
      },
    );

    test(
      'leave/rejoin replaces channel and rejects callbacks from previous generation and membership',
      () async {
        final changes = <GroupDriveSnapshot?>[];
        final watch = fixture.client.changes.listen(changes.add);
        try {
          final oldTopic = fixture.topic;
          fixture.send(fixture.point());
          expect(changes.last!.members.first.location, isNotNull);
          await fixture.client.leave('test-group');
          expect(changes.last, isNull);
          final rejoined = await fixture.client.join(fixture.initial.invite);
          expect(rejoined.members.first.membershipId, 'member-a-rejoined');
          expect(rejoined.members.first.location, isNull);
          final count = changes.length;
          fixture.send(fixture.point(sequence: 2), topic: oldTopic);
          fixture.send(fixture.point(sequence: 2));
          expect(changes.length, count);
          fixture.send(fixture.point(member: 'member-a-rejoined'));
          expect(changes.length, count + 1);
          expect(changes.last!.members.first.location, isNotNull);
        } finally {
          await watch.cancel();
        }
      },
    );

    test(
      'V2 phase uses server start and rejects a backend without the contract',
      () async {
        fixture.phase = 'lobby';
        expect((await fixture.client.current())!.phase, GroupRidePhase.lobby);
        final started = await fixture.client.startRide('test-group');
        expect(fixture.commands.last, 'start');
        expect(started.phase, GroupRidePhase.running);
        expect(fixture.commands, isNot(contains('share_start')));
        fixture.phase = null;
        await expectLater(
          fixture.client.current(),
          throwsA(
            isA<GroupDriveException>().having(
              (e) => e.code,
              'code',
              'backend_upgrade_required',
            ),
          ),
        );
      },
    );

    test(
      'active grant heartbeat continues over HTTP while Flutter is paused',
      () async {
        fixture.liveClock = true;
        await fixture.client.startSharing('test-group', consent: true);
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        try {
          // Existing five-second polling and a ten-second minimum heartbeat
          // interval can place the first renewal on the third poll.
          await Future<void>.delayed(const Duration(seconds: 16));
          expect(fixture.commands, contains('share_heartbeat'));
        } finally {
          TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
      },
    );

    test(
      'paused foreground consumer explicitly refreshes expiring Auth before HTTP heartbeat/snapshot',
      () async {
        fixture.tokenLifetime = 1;
        await fixture.supabase.auth.refreshSession();
        fixture.tokenLifetime = 3600;
        final before = fixture.tokenRequests;
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        try {
          expect(await fixture.client.current(), isNotNull);
          expect(fixture.tokenRequests, before + 1);
          fixture.tokenLifetime = 1;
          await fixture.supabase.auth.refreshSession();
          fixture.rejectRefresh = true;
          await expectLater(
            fixture.client.current(),
            throwsA(isA<GroupDriveException>()),
          );
        } finally {
          TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
      },
    );

    test(
      'envelope reaches member cache and changes; bad/revoked data is rejected',
      () async {
        final received = <GroupDriveSnapshot?>[];
        final subscription = fixture.client.changes.listen(received.add);
        try {
          final oldTopic = fixture.topic;
          fixture.send({
            ...fixture.point(),
            'accuracyMeters': 75,
            'recordedAt': fixture.now
                .subtract(const Duration(seconds: 14))
                .toIso8601String(),
          });
          expect(received.single!.members.first.location!.accuracyMeters, 75);
          fixture.send(fixture.point(sequence: 2));
          fixture.send(fixture.point(member: 'member-b'));
          expect(received.last!.members.map((m) => m.location?.sequence), [
            2,
            1,
          ]);

          // A normal RPC contains location:null; keep only fresh transient data.
          final refreshed = (await fixture.client.current())!;
          expect(refreshed.members.every((m) => m.location != null), isTrue);
          expect(refreshed.observedAt, fixture.now);
          final count = received.length;
          for (final invalid in <Object?>[
            null,
            [],
            'invalid',
            {},
            {...fixture.point(sequence: 3), 'generation': 6},
            {...fixture.point(sequence: 3), 'generation': 7.5},
            {...fixture.point(sequence: 3), 'membershipId': 'not-a-member'},
            {...fixture.point(sequence: 3), 'sequence': 2.5},
            {...fixture.point(sequence: 3), 'recordedAt': 'bad-date'},
            {...fixture.point(sequence: 3), 'accuracyMeters': 75.1},
            {
              ...fixture.point(sequence: 3),
              'recordedAt': fixture.now
                  .subtract(const Duration(seconds: 16))
                  .toIso8601String(),
            },
            {
              ...fixture.point(sequence: 3),
              'recordedAt': fixture.now
                  .add(const Duration(seconds: 4))
                  .toIso8601String(),
            },
            fixture.point(),
            fixture.point(sequence: 2),
            {
              ...fixture.point(sequence: 3),
              'recordedAt': fixture.now
                  .subtract(const Duration(seconds: 2))
                  .toIso8601String(),
            },
          ]) {
            fixture.send(invalid);
            expect(
              received,
              hasLength(count),
              reason: 'Invalid message must not emit a snapshot',
            );
          }
          fixture.send(
            fixture.point(sequence: 3),
            topic: 'realtime:driveit:group:other:7',
          );
          fixture.send(fixture.point(sequence: 3), event: 'other');
          fixture.send(fixture.point(sequence: 3), type: 'presence');
          // A flat fallback would hide the original envelope decoding defect.
          fixture.supabase.realtime.onConnMessage(
            jsonEncode([
              null,
              null,
              oldTopic,
              'broadcast',
              {...fixture.point(sequence: 3), 'event': 'location'},
            ]),
          );
          expect(received, hasLength(count));

          await fixture.client.pauseSharing('test-group');
          await Future<void>.delayed(Duration.zero);
          expect(
            received.last!.members.every((m) => m.location == null),
            isTrue,
          );
          final pausedCount = received.length;
          fixture.send({
            ...fixture.point(sequence: 4),
            'generation': 7,
          }, topic: oldTopic);
          fixture.send({...fixture.point(sequence: 4), 'generation': 7});
          fixture.send(
            fixture.point(sequence: 4),
          ); // Current generation, paused member.
          expect(received, hasLength(pausedCount));
          expect(
            (await fixture.client.current())!.members.first.location,
            isNull,
          );
          fixture.send(fixture.point(member: 'member-b', sequence: 2));
          expect(received.last!.members.last.location, isNotNull);

          final ownerCount = received.length;
          fixture.auth.emit(b);
          await fixture.runtime.settled;
          fixture.send(fixture.point(sequence: 5), topic: oldTopic);
          expect(received, hasLength(ownerCount));
        } finally {
          await subscription.cancel();
        }
      },
    );

    testWidgets(
      'SDK envelope changes snapshot renders two actual GoogleMap markers',
      (tester) async {
        final oldMaps = maps.GoogleMapsFlutterPlatform.instance;
        final mapFake = GroupMapFake();
        maps.GoogleMapsFlutterPlatform.instance = mapFake;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: SizedBox(
                height: 400,
                child: StreamBuilder<GroupDriveSnapshot?>(
                  initialData: fixture.initial,
                  stream: fixture.client.changes,
                  builder: (context, snapshot) => GroupDriveMap(
                    lease: fixture.runtime.lease,
                    group: snapshot.data!,
                    isSimulation: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();
          expect(
            tester.widget<GoogleMap>(find.byType(GoogleMap)).markers,
            isEmpty,
          );
          fixture.send(fixture.point());
          fixture.send(fixture.point(member: 'member-b'));
          await tester.pump();
          final markers = tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers;
          expect(markers.map((m) => m.markerId.value).toSet(), {
            'member-a',
            'member-b',
          });
          expect(
            markers.every((m) => m.position == const LatLng(10, 20)),
            isTrue,
          );
          expect(find.text('Canlı GPS • 2 görünür üye'), findsNothing);
          expect(find.byKey(const Key('group_marker_count')), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        } finally {
          mapFake.clearHandlers();
          maps.GoogleMapsFlutterPlatform.instance = oldMaps;
        }
      },
    );
  });

  test('server time estimate is independent of receiver wall-clock offset', () {
    final serverTime = DateTime.utc(2026, 10, 16, 12);
    final receivedPoint = serverTime.subtract(const Duration(seconds: 2));
    // Whether this device's wall clock is a minute fast or slow is irrelevant:
    // only monotonic time since receiving the server snapshot advances it.
    final estimatedNow = estimateGroupServerTime(
      serverTime,
      const Duration(seconds: 4),
    );

    expect(estimatedNow, DateTime.utc(2026, 10, 16, 12, 0, 4));
    expect(isGroupGpsTimestampFresh(receivedPoint, estimatedNow), isTrue);
    expect(
      isGroupGpsTimestampFresh(
        serverTime.subtract(const Duration(seconds: 16)),
        estimatedNow,
      ),
      isFalse,
    );
  });

  test(
    'normal server snapshots retain only fresh authorized transient points',
    () {
      final observedAt = DateTime.utc(2026, 10, 16, 12);
      final point = GroupGpsLocation(
        latitude: 41.0,
        longitude: 29.0,
        accuracyMeters: 12,
        sequence: 3,
        recordedAt: observedAt.subtract(const Duration(seconds: 2)),
      );
      final snapshot = GroupDriveSnapshot(
        id: 'group-id',
        createdAt: observedAt.subtract(const Duration(minutes: 1)),
        observedAt: observedAt,
        expiresAt: observedAt.add(const Duration(hours: 12)),
        status: GroupDriveStatus.active,
        extensionCount: 0,
        revision: 4,
        invite: GroupDriveInvite('00000000-0000-4000-8000-000000000001'),
        members: [
          GroupDriveMember(
            membershipId: 'member-sharing',
            accountId: a,
            displayName: 'A',
            joinedAt: observedAt.subtract(const Duration(minutes: 1)),
            joinOrder: 0,
            role: GroupDriveRole.administrator,
            sharingStatus: GroupSharingStatus.sharing,
          ),
          GroupDriveMember(
            membershipId: 'member-paused',
            accountId: b,
            displayName: 'B',
            joinedAt: observedAt.subtract(const Duration(minutes: 1)),
            joinOrder: 1,
            role: GroupDriveRole.member,
            sharingStatus: GroupSharingStatus.paused,
          ),
        ],
      );

      final merged = withFreshGroupLocations(
        snapshot: snapshot,
        locations: {'member-sharing': point, 'member-paused': point},
        referenceTime: estimateGroupServerTime(
          observedAt,
          const Duration(seconds: 3),
        ),
      );

      expect(merged.observedAt, observedAt);
      expect(merged.members.first.location, same(point));
      expect(merged.members.last.location, isNull);
      final expired = withFreshGroupLocations(
        snapshot: snapshot,
        locations: {
          'member-sharing': GroupGpsLocation(
            latitude: 41.0,
            longitude: 29.0,
            accuracyMeters: 12,
            sequence: 2,
            recordedAt: observedAt.subtract(const Duration(seconds: 16)),
          ),
        },
        referenceTime: observedAt,
      );
      expect(expired.members.first.location, isNull);
    },
  );

  for (final offset in [
    const Duration(seconds: -5),
    const Duration(seconds: 20),
  ]) {
    test('proven server clock skew $offset rejects before publication', () async {
      final root = await Directory.systemTemp.createTemp('group_clock_');
      final auth = TestAuth();
      final runtime = LocalOwnerLifecycle(
        gate: LocalOwnershipGate.synthetic(),
        auth: auth,
        openStore: (owner) =>
            OwnerScopedLocalStore.open(root: root.path, owner: owner),
        driveInProgress: () async => false,
      );
      await runtime.start();
      final actions = <String>[];
      final supabase = SupabaseClient(
        'https://group-contract.invalid',
        'synthetic-public-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object response;
          if (request.url.path.endsWith('/token')) {
            response = {
              'access_token':
                  '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': a, 'aud': 'authenticated', 'role': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.synthetic',
              'refresh_token': 'synthetic-refresh-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': a,
                'aud': 'authenticated',
                'created_at': '2026-01-01T00:00:00Z',
              },
            };
          } else {
            final action =
                (jsonDecode(request.body) as Map)['p_action'] as String;
            actions.add(action);
            response = {
              'id': 'test-group',
              'phase': 'running',
              'observedAt': DateTime.now()
                  .toUtc()
                  .add(offset)
                  .toIso8601String(),
            };
          }
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await supabase.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      final client = SupabaseGroupDriveService(
        supabase,
      ).forOwner(runtime.lease);
      try {
        await expectLater(
          client.startSharing('test-group', consent: false),
          throwsA(
            isA<GroupDriveException>().having(
              (e) => e.code,
              'code',
              'consent_required',
            ),
          ),
        );
        expect(actions, isEmpty);
        await expectLater(
          client.startSharing('test-group', consent: true),
          throwsA(
            isA<GroupDriveException>().having(
              (e) => e.code,
              'code',
              'device_clock_out_of_sync',
            ),
          ),
        );
        expect(actions, ['current']); // No share_start or GPS publication.
        auth.emit(b);
        await runtime.settled;
        await expectLater(client.current(), throwsA(anything));
        expect(actions, ['current']);
      } finally {
        await client.close();
        await supabase.dispose();
        await runtime.close();
        runtime.dispose();
        await auth.events.close();
        await root.delete(recursive: true);
      }
    });
  }
}
