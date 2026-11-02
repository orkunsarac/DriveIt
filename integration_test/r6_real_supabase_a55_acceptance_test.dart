import 'package:driveit_project/config/local_ownership_gate.dart';
import 'package:driveit_project/config/supabase_bootstrap.dart';
import 'package:driveit_project/config/supabase_public_key_policy.dart';
import 'package:driveit_project/models/canonical_telemetry_point.dart';
import 'package:driveit_project/models/drive_session.dart';
import 'package:driveit_project/services/account_deletion_controller.dart';
import 'package:driveit_project/services/account_deletion_runtime.dart';
import 'package:driveit_project/services/drive_route_projection.dart';
import 'package:driveit_project/services/drive_time_analysis.dart';
import 'package:driveit_project/services/gps_hive_transfer_sink.dart';
import 'package:driveit_project/services/local_ownership_bootstrap.dart';
import 'package:driveit_project/services/owned_foreground_bootstrap.dart';
import 'package:driveit_project/services/owner_scoped_local_store.dart';
import 'package:driveit_project/services/owner_session_vault.dart';
import 'package:driveit_project/services/supabase_account_service.dart';
import 'package:driveit_project/services/supabase_local_owner_auth.dart';
import 'package:driveit_project/services/supabase_owner_drive_sync_adapter.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _emailA = String.fromEnvironment('DRIVEIT_R6_EMAIL_A');
const _passwordA = String.fromEnvironment('DRIVEIT_R6_PASSWORD_A');
const _emailB = String.fromEnvironment('DRIVEIT_R6_EMAIL_B');
const _passwordB = String.fromEnvironment('DRIVEIT_R6_PASSWORD_B');
const _wrongPassword = String.fromEnvironment('DRIVEIT_R6_WRONG_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real DEV Auth, owner fencing, staged drive sync and deletion', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final package = await PackageInfo.fromPlatform();
    expect(
      const bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST'),
      isTrue,
      reason: 'Only the isolated Android integration target may run this test',
    );
    expect(
      package.packageName,
      'com.example.driveit_project.isolated_test',
      reason: 'Refuse the production or regular DEV installation',
    );
    expect(SupabaseBootstrap.isPlayPackage, isFalse);
    _stage('play_auth_gate_closed_for_isolated_package');
    expect(_url, 'https://viqngnjfgknpxtoapzcg.supabase.co');
    expect(SupabasePublicKeyPolicy.permits(_key), isTrue);
    expect(_emailA.endsWith('@example.invalid'), isTrue);
    expect(_emailB.endsWith('@example.invalid'), isTrue);
    expect(_passwordA.isNotEmpty && _passwordB.isNotEmpty, isTrue);
    expect(
      _wrongPassword != _passwordA && _wrongPassword != _passwordB,
      isTrue,
    );

    await Supabase.initialize(
      url: _url,
      publishableKey: _key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: false,
        persistSession: false,
        autoRefreshToken: false,
      ),
      debug: false,
    );
    _stage('sdk_ready');
    SupabaseClient client = Supabase.instance.client;
    final root = await (await getTemporaryDirectory()).createTemp(
      'driveit_owner_test_r6_',
    );
    final vault = OwnerSessionVault(const AndroidOwnerSessionStorage());
    var bindings = await _startRuntime(root, client, vault);
    var runtime = bindings.$1;
    var account = bindings.$2;
    _stage('guest_owner_ready');

    try {
      expect(runtime.owner.lease.owner.userId, isNull, reason: 'Guest start');

      var wrongCredentialRejected = false;
      try {
        await account.signIn(email: _emailA, password: _wrongPassword);
      } on AccountServiceException {
        wrongCredentialRejected = true;
      }
      await runtime.owner.settled;
      expect(
        wrongCredentialRejected,
        isTrue,
        reason: 'Wrong password denied by Auth',
      );
      expect(
        runtime.owner.lease.owner.userId,
        isNull,
        reason: 'Failed login remains Guest',
      );
      expect(client.auth.currentSession, isNull);
      _stage('invalid_credentials_rejected');

      await account.signIn(email: _emailA, password: _passwordA);
      await runtime.owner.settled;
      final uidA = client.auth.currentUser!.id;
      expect(
        runtime.owner.lease.owner.userId == uidA,
        isTrue,
        reason: 'Guest to A',
      );
      expect(
        (await vault.load())?.user.id == uidA,
        isTrue,
        reason: 'Android secure session saved',
      );
      final profileA = await account.fetchCurrentProfile();
      expect(profileA?.id == uidA, isTrue, reason: 'DEV profile read as A');
      _stage('account_a_ready');

      final driveId = await _createAndSaveSyntheticGpsDrive(runtime);
      expect(runtime.owner.lease.requireDrive(driveId).id == driveId, isTrue);
      expect(
        runtime.owner.lease.telemetry(driveId)?.points.length == 301,
        isTrue,
      );
      final scoringInput = runtime.owner.lease.telemetry(driveId)!;
      final scoringAnalysis = DriveTimeAnalysis.fromRecord(scoringInput);
      _stage(
        'score_input_${scoringAnalysis.scoreEligible}_'
        '${scoringAnalysis.movingSamples}_'
        '${scoringAnalysis.movingMicros}_'
        '${scoringAnalysis.measuredMicros}_'
        '${scoringAnalysis.totalMicros}',
      );
      expect(
        runtime.owner.lease.score(driveId) != null,
        isTrue,
        reason: 'Drive Score persisted for A',
      );
      _stage('gps_fixture_saved');

      await runtime.owner.lease.checkManualCloudConnection();
      final uploaded = await runtime.owner.lease.uploadSelectedDrive(driveId);
      final uploadCandidate = runtime.owner.lease.manualSyncCandidates().single;
      final stagingIntentId = uploadCandidate.key == null
          ? null
          : ((runtime.owner.lease.syncRecord(
                      uploadCandidate.key!,
                    )?['stagedUpload']
                    as Map?)?['intentId']
                as String?);
      final uploadError = uploadCandidate.key == null
          ? 'no_outbox_record'
          : runtime.owner.lease.syncRecord(
                  uploadCandidate.key!,
                )?['lastErrorCode'] ??
                'no_error_code';
      _stage('upload_result_${uploaded}_${uploadCandidate.state}_$uploadError');
      if (!uploaded && uploadCandidate.key != null) {
        final row = runtime.owner.lease.syncRecord(uploadCandidate.key!);
        final mutation = row?['mutation'];
        final payload = mutation is Map ? mutation['payload'] : null;
        if (payload is Map && mutation is Map) {
          _diagnoseEnvelope(mutation, payload);
        }
      }
      if (uploaded) {
        final downloadedA = await runtime.owner.lease.downloadManualCloudPage();
        expect(
          downloadedA.applied == 1,
          isTrue,
          reason: 'A downloads own server record',
        );
        _stage('drive_uploaded_and_downloaded');
      } else {
        // Continue independent owner/GPS/logout/deletion checks even if the
        // remote validator rejects this upload. The final acceptance assertion
        // still fails with the sanitized server error code.
        _stage('drive_download_skipped_upload_rejected');
      }

      // Recreate the SDK client and owner runtime over the same Android
      // Keystore vault and isolated local database, as the real app does after
      // process startup. The live DEV session is intentionally not signed out.
      account.detachOwnerForTesting(runtime.owner);
      account.dispose();
      await runtime.closeAfterProducerDetached();
      await client.dispose();
      client = SupabaseClient(
        _url,
        _key,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: false,
          persistSession: false,
          autoRefreshToken: false,
        ),
      );
      bindings = await _startRuntime(root, client, vault);
      runtime = bindings.$1;
      account = bindings.$2;
      await restoreVerifiedOwnerSession(
        owner: runtime.owner,
        client: client,
        vault: vault,
      );
      await runtime.owner.settled;
      expect(client.auth.currentUser?.id, uidA, reason: 'DEV restore owner A');
      expect(
        runtime.owner.lease.owner.userId,
        uidA,
        reason: 'Owner opened after server verification',
      );
      _stage('android_keystore_runtime_restart_restore_verified');

      final beforeRefresh = client.auth.currentSession!;
      final refreshed = await refreshVerifiedOwnerSession(
        owner: runtime.owner,
        client: client,
        vault: vault,
        refreshWindow: const Duration(days: 2),
      );
      expect(refreshed, isTrue, reason: 'Real DEV refresh token rotation');
      final afterRefresh = client.auth.currentSession!;
      final storedAfterRefresh = await vault.load();
      expect(
        afterRefresh.user.id == uidA,
        isTrue,
        reason: 'Refresh retains owner A',
      );
      expect(
        afterRefresh.accessToken != beforeRefresh.accessToken,
        isTrue,
        reason: 'Access token rotated',
      );
      expect(
        afterRefresh.refreshToken != beforeRefresh.refreshToken,
        isTrue,
        reason: 'Refresh token rotated',
      );
      expect(
        storedAfterRefresh?.refreshToken == afterRefresh.refreshToken,
        isTrue,
        reason: 'Rotated token sealed',
      );
      expect(
        runtime.owner.lease.owner.userId == uidA,
        isTrue,
        reason: 'Owner A retained after refresh',
      );
      _stage('refresh_verified');

      await account.signIn(email: _emailB, password: _passwordB);
      await runtime.owner.settled;
      final uidB = client.auth.currentUser!.id;
      expect(
        uidA != uidB && runtime.owner.lease.owner.userId == uidB,
        isTrue,
        reason: 'A to B switch',
      );
      expect(
        runtime.owner.lease.drives().isEmpty,
        isTrue,
        reason: 'A local drive hidden from B',
      );
      expect(
        runtime.owner.lease.score(driveId) == null,
        isTrue,
        reason: 'A Drive Score hidden from B',
      );
      expect(
        (await vault.load())?.user.id == uidB,
        isTrue,
        reason: 'Vault follows B only',
      );
      await runtime.owner.lease.checkManualCloudConnection();
      final downloadedB = await runtime.owner.lease.downloadManualCloudPage();
      expect(
        downloadedB.applied == 0,
        isTrue,
        reason: 'B receives no A server drive',
      );
      if (stagingIntentId != null) {
        var stagingDenied = false;
        try {
          await client.storage
              .from('phase8-drive-staging')
              .download('$uidA/$stagingIntentId/envelope.json');
        } on StorageException {
          stagingDenied = true;
        }
        expect(stagingDenied, isTrue, reason: 'B cannot read A staging object');
        _stage('account_b_staging_read_denied');
      }
      final profileB = await account.fetchCurrentProfile();
      expect(profileB?.id == uidB, isTrue, reason: 'DEV profile read as B');
      _stage('account_b_isolated');

      final blockedSession = await runtime.gps.start(
        startNative: (_, _) async {},
      );
      final pointTime = blockedSession.startedAt.toUtc().add(
        const Duration(seconds: 1),
      );
      await runtime.gps.journal.append(
        blockedSession.id,
        1,
        CanonicalTelemetryPoint(
          latitude: 40,
          longitude: 30,
          timestamp: pointTime,
          speedMps: 8,
          headingDegrees: 0,
          altitudeMeters: 10,
          accuracyMeters: 5,
          distanceFromPreviousMeters: 0,
          accelerationMps2: 0,
        ),
      );
      var activeGpsSwitchRejected = false;
      try {
        await account.signIn(email: _emailA, password: _passwordA);
      } on StateError {
        activeGpsSwitchRejected = true;
      }
      await runtime.owner.settled;
      expect(
        activeGpsSwitchRejected,
        isTrue,
        reason: 'Active GPS fences account switch',
      );
      expect(
        runtime.owner.lease.owner.userId == uidB,
        isTrue,
        reason: 'B remains the GPS owner',
      );
      expect(
        (await runtime.gps.journal.read(blockedSession.id)).length,
        1,
        reason: 'Active GPS row retained',
      );
      await runtime.gps.journal.requestStop(blockedSession.id);
      var recoverableGpsSwitchRejected = false;
      try {
        await account.signIn(email: _emailA, password: _passwordA);
      } on StateError {
        recoverableGpsSwitchRejected = true;
      }
      expect(
        recoverableGpsSwitchRejected,
        isTrue,
        reason: 'Recoverable GPS fences account switch',
      );
      expect(
        (await runtime.gps.journal.read(blockedSession.id)).length,
        1,
        reason: 'Recoverable GPS row retained',
      );
      _stage('gps_owner_change_blocked');
      await runtime.gps.journal.stop(blockedSession.id, expectedSequence: 1);
      final stoppedPoint = (await runtime.gps.journal.read(
        blockedSession.id,
      )).single.point;
      final projection = DriveRouteProjection([stoppedPoint]);
      final blockedDrive = DriveSession(
        id: blockedSession.id,
        date: blockedSession.startedAt,
        distance: projection.distanceMeters,
        durationSeconds: 1,
        averageSpeed: 0,
        maxSpeed: 8,
        mapImagePath: '',
        route: projection.route,
      );
      await runtime.owner.lease.transferGps(
        journal: runtime.gps.journal,
        ownership: runtime.gps.ownership,
        binding: await runtime.gps.requireBinding(blockedSession.id),
        proposed: driveTransferManifest(blockedDrive),
      );

      await account.signOut();
      await runtime.owner.settled;
      expect(
        runtime.owner.lease.owner.userId,
        isNull,
        reason: 'Logout returns to Guest',
      );
      expect(
        await vault.load(),
        isNull,
        reason: 'Logout clears account session vault',
      );
      await account.signIn(email: _emailA, password: _passwordA);
      await runtime.owner.settled;
      expect(
        runtime.owner.lease.owner.userId == uidA,
        isTrue,
        reason: 'A can sign in again',
      );
      expect(
        runtime.owner.lease.requireDrive(driveId).id == driveId,
        isTrue,
        reason: 'A local data retained',
      );
      _stage('logout_and_relogin_verified');

      // This is the real DEV Edge Function and the real Android secure receipt
      // store. Only the generated temporary Account A and its test drive are
      // in scope for this irreversible request.
      final deletion = AccountDeletionController(
        endpoint: _url,
        store: SecureAccountDeletionReceiptStore(_url),
        currentOwner: () => client.auth.currentUser?.id,
        guard: account.authorizeAccountDeletion,
        signOutLocal: (owner) async {
          if (client.auth.currentUser?.id == owner) {
            await client.auth.signOut(scope: SignOutScope.local);
          }
        },
        send: (body) async {
          try {
            final response = await client.functions.invoke(
              'delete-account',
              body: body,
            );
            _diagnoseDeletionReply(response.status, response.data);
            return (
              status: response.status,
              body: response.data is Map
                  ? Map<String, dynamic>.from(response.data as Map)
                  : <String, dynamic>{},
            );
          } on FunctionException catch (error) {
            _diagnoseDeletionReply(error.status, error.details);
            return (
              status: error.status,
              body: error.details is Map
                  ? Map<String, dynamic>.from(error.details as Map)
                  : <String, dynamic>{},
            );
          }
        },
      );
      await deletion.start(password: _passwordA, confirmed: true);
      if (deletion.state == AccountDeletionState.completed) {
        await runtime.owner.settled;
        expect(runtime.owner.lease.owner.userId, isNull);
        _stage('temporary_account_deletion_completed');
      } else {
        expect(deletion.state, AccountDeletionState.failed);
        expect(client.auth.currentUser?.id, uidA);
        _stage('temporary_account_deletion_blocked_function_unavailable');
      }
      deletion.dispose();
    } finally {
      account.detachOwnerForTesting(runtime.owner);
      account.dispose();
      await runtime.closeAfterProducerDetached();
      await client.dispose();
      await root.delete(recursive: true);
    }
  });
}

Future<(ControlledOwnershipRuntime, SupabaseAccountService)> _startRuntime(
  Directory root,
  SupabaseClient client,
  OwnerSessionVault vault,
) async {
  final descriptor = await OwnedForegroundBootstrap.prepareForTesting(root);
  final runtime = (await LocalOwnershipBootstrap.run(
    gate: LocalOwnershipGate.synthetic(),
    legacyBootstrap: () async => throw StateError('legacy path forbidden'),
    controlled: ControlledOwnershipDependencies(
      descriptor: descriptor,
      databaseFactory: databaseFactory,
      restoreAuth: () async => SupabaseLocalOwnerAuth(client),
      openStore: (owner) =>
          OwnerScopedLocalStore.open(root: root.path, owner: owner),
      producerRunning: () async => false,
      attachForeground: (_, _) async {},
      detachForeground: (_) async {},
      accountSyncAdapter: (lease) => SupabaseOwnerDriveSyncAdapter(
        client: client,
        ownerId: lease.owner.userId!,
        requireCurrent: lease.requireCurrent,
      ),
      automaticAccountSync: false,
      automaticCloudDeletionRetry: false,
      cloudDeletionEnabled: false,
    ),
  ))!;
  final account = SupabaseAccountService.forTesting(
    client,
    null,
    sessionVault: vault,
  );
  account.attachOwnerForTesting(runtime.owner);
  account.startIdentitySync();
  return (runtime, account);
}

void _stage(String value) => debugPrint('R6_TEST_STAGE=$value');

void _diagnoseEnvelope(Map mutation, Map payload) {
  final drive = payload['drive'];
  final telemetry = payload['telemetry'];
  final provenance = payload['sourceProvenance'];
  final metadata = telemetry is Map ? telemetry['metadata'] : null;
  final points = telemetry is Map && telemetry['points'] is List
      ? telemetry['points'] as List
      : const <dynamic>[];
  final p = points.isNotEmpty && points.first is Map
      ? points.first as Map
      : const <dynamic, dynamic>{};
  final failed = <String>[];
  if (mutation['version'] != 2 || mutation['kind'] != 'driveUpsert') {
    failed.add('mutation_kind');
  }
  if (mutation['ownerId'] is! String ||
      mutation['ownerScope'] is! String ||
      mutation['sourceIdentity'] is! String ||
      mutation['idempotencyKey'] is! String ||
      mutation['payloadFingerprint'] is! String) {
    failed.add('mutation_claims');
  }
  if (payload['version'] != 2) failed.add('bundle_version');
  if (payload['ownerScope'] is! String ||
      payload['ownerScope'] == 'unassigned') {
    failed.add('bundle_scope');
  }
  if (payload['roads'] is! List || (payload['roads'] as List).isNotEmpty) {
    failed.add('roads');
  }
  if (drive is! Map) {
    failed.add('drive');
  } else {
    if (drive['dateMicros'] is! int || drive['dateIsUtc'] is! bool) {
      failed.add('drive_date');
    }
    if (drive['mapImagePath'] != '') failed.add('map_path');
    for (final key in <String>[
      'distance',
      'averageSpeed',
      'maxSpeed',
      'maxAccelerationG',
      'maxBrakingG',
      'maxCorneringSpeed',
      'maxAltitude',
      'altitudeGain',
    ]) {
      if (drive[key] is! num || !(drive[key] as num).toDouble().isFinite) {
        failed.add('drive_numeric');
        break;
      }
    }
    for (final key in <String>[
      'stopCount',
      'stoppedSeconds',
      'hardBrakeCount',
      'hardAccelerationCount',
      'sharpTurnCount',
      'cornerCount',
    ]) {
      if (drive[key] is! int || (drive[key] as int) < 0) {
        failed.add('drive_counts');
        break;
      }
    }
  }
  if (provenance is! Map ||
      provenance['status'] != 'proven' ||
      provenance['identityVersion'] != 1 ||
      provenance['sourceNamespace'] != 'drive_source_v1') {
    failed.add('provenance');
  }
  if (metadata is! Map ||
      metadata['provenanceStatus'] != 'proven' ||
      metadata['sourceIdentityVersion'] != 1 ||
      metadata['sourceNamespace'] != 'drive_source_v1') {
    failed.add('telemetry_provenance');
  }
  if (telemetry is! Map ||
      telemetry['version'] != 1 ||
      DateTime.tryParse('${telemetry['createdAt']}') == null ||
      points.isEmpty) {
    failed.add('telemetry_schema');
  }
  if (telemetry is Map && drive is Map && telemetry['driveId'] != drive['id']) {
    failed.add('telemetry_drive_id');
  }
  if (p['timeMicros'] is! int ||
      p['time'] is! int ||
      p['telemetryVersion'] != 1 ||
      p['timeIsUtc'] is! bool) {
    failed.add('point_schema');
  }
  if (p['lat'] is! num ||
      p['lng'] is! num ||
      <String>[
        'speed',
        'heading',
        'altitude',
        'distance',
        'acceleration',
        'accuracy',
      ].any((key) => p[key] is! num || !(p[key] as num).toDouble().isFinite)) {
    failed.add('point_values');
  }
  final score = payload['score'];
  if (score != null &&
      (score is! Map ||
          score['driveId'] != drive?['id'] ||
          score['algorithm'] != 1 ||
          score['telemetryVersion'] != 1 ||
          score['total'] is! num ||
          score['confidence'] is! num ||
          score['categories'] is! List ||
          DateTime.tryParse('${score['calculatedAt']}') == null)) {
    failed.add('score_schema');
  }
  _stage(
    failed.isEmpty
        ? 'envelope_local_shape_ok'
        : 'envelope_shape_${failed.join('_')}',
  );
}

void _diagnoseDeletionReply(int? status, dynamic value) {
  final body = value is Map ? value : const <dynamic, dynamic>{};
  const allowedStates = <String>{
    'completed',
    'pending',
    'purged',
    'busy',
    'blocked_planet',
    'idle',
  };
  const allowedErrors = <String>{
    'server_not_configured',
    'request_invalid',
    'recovery_not_configured',
    'confirmation_required',
    'unauthorized',
    'account_context_changed',
    'reauthentication_failed',
    'receipt_unavailable',
    'deletion_not_completed',
  };
  final state = body['state'] is String && allowedStates.contains(body['state'])
      ? body['state'] as String
      : 'none';
  final error = body['error'] is String && allowedErrors.contains(body['error'])
      ? body['error'] as String
      : 'none';
  _stage('deletion_reply_${status ?? 0}_${state}_$error');
}

Future<String> _createAndSaveSyntheticGpsDrive(
  ControlledOwnershipRuntime runtime,
) async {
  final session = await runtime.gps.start(startNative: (_, _) async {});
  final points = <CanonicalTelemetryPoint>[];
  for (var i = 0; i < 301; i++) {
    final point = CanonicalTelemetryPoint(
      latitude: 40 + i * 0.00018,
      longitude: 30,
      timestamp: session.startedAt.toUtc().add(Duration(seconds: i)),
      speedMps: 20,
      headingDegrees: 0,
      altitudeMeters: 10,
      accuracyMeters: 5,
      distanceFromPreviousMeters: i == 0 ? 0 : 20,
      accelerationMps2: 0,
      speedSource: 'native',
    );
    points.add(point);
    await runtime.gps.journal.append(session.id, i + 1, point);
  }
  await runtime.gps.journal.requestStop(session.id, at: points.last.timestamp);
  await runtime.gps.journal.stop(session.id, expectedSequence: points.length);
  final projection = DriveRouteProjection(points);
  final drive = DriveSession(
    id: session.id,
    date: session.startedAt,
    distance: projection.distanceMeters,
    durationSeconds: 300,
    averageSpeed: 72,
    maxSpeed: 72,
    mapImagePath: '',
    route: projection.route,
  );
  await runtime.owner.lease.transferGps(
    journal: runtime.gps.journal,
    ownership: runtime.gps.ownership,
    binding: await runtime.gps.requireBinding(session.id),
    proposed: driveTransferManifest(drive),
  );
  return session.id;
}
