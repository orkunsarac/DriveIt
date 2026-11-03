import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/drive_score/services/drive_score_calculator.dart';
import '../../features/world_publish/models/world_publish.dart';
import '../../features/world_publish/services/published_drive_source_builder.dart';
import '../../features/world_publish/services/world_publish_processing_service.dart';
import '../../features/world_publish/services/world_publish_service.dart';
import '../../features/world_publish/services/world_publish_source_upload_service.dart';
import '../../features/world_publish/services/world_publish_submission_service.dart';
import '../../models/canonical_telemetry_point.dart';
import '../../models/drive_score_record.dart';
import '../../models/drive_session.dart';
import '../../models/route_point.dart';
import '../../services/drive_source_provenance.dart';
import '../../services/local_source_bundle.dart';
import '../../services/owner_drive_sync_client.dart';
import '../../services/owner_profile_gateway.dart';
import '../../services/owner_session_vault.dart';
import '../../services/owner_sync_canonical_json.dart';
import '../../services/supabase_owner_drive_sync_adapter.dart';
import 'manual_dev_acceptance_policy.dart';

const _manualBuild = bool.fromEnvironment('DRIVEIT_MANUAL_DEV_ACCEPTANCE');
const _isolatedBuild = bool.fromEnvironment('DRIVEIT_ISOLATED_ANDROID_TEST');
const _devUrl = ManualDevAcceptancePolicy.projectUrl;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff07101d),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff12e6df),
          brightness: Brightness.dark,
          surface: const Color(0xff101c2c),
        ),
        useMaterial3: true,
      ),
      home:
          ManualDevAcceptancePolicy.buildPermits(
            manualBuild: _manualBuild,
            isolatedBuild: _isolatedBuild,
            // Android Gradle refuses the manual target without the isolated
            // applicationId. The APK is independently checked before install.
            installedApplicationId: ManualDevAcceptancePolicy.applicationId,
            url: _devUrl,
          )
          ? const ManualDevAcceptanceScreen()
          : const _RefusedBuildScreen(),
    ),
  );
}

class _RefusedBuildScreen extends StatelessWidget {
  const _RefusedBuildScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Bu test ekranı yalnız izole DriveIt DEV APK’sında kullanılabilir.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _SyntheticDrive {
  const _SyntheticDrive({
    required this.drive,
    required this.telemetry,
    required this.score,
    required this.provenance,
  });

  final DriveSession drive;
  final DriveTelemetryRecord telemetry;
  final DriveScoreRecord score;
  final DriveSourceProvenance provenance;
}

class _Outcome {
  const _Outcome(this.state, this.code, this.at);
  final String state;
  final String code;
  final DateTime at;
}

class ManualDevAcceptanceScreen extends StatefulWidget {
  const ManualDevAcceptanceScreen({super.key});
  @override
  State<ManualDevAcceptanceScreen> createState() =>
      _ManualDevAcceptanceScreenState();
}

class _ManualDevAcceptanceScreenState extends State<ManualDevAcceptanceScreen> {
  final _keyController = TextEditingController();
  final _emailA = TextEditingController();
  final _passwordA = TextEditingController();
  final _emailB = TextEditingController();
  final _passwordB = TextEditingController();
  final _vault = OwnerSessionVault(const AndroidOwnerSessionStorage());
  final Map<String, _Outcome> _outcomes = {};
  SupabaseClient? _client;
  String? _publishableKey;
  String? _activeOwner;
  String? _accountAOwner;
  String? _accountBOwner;
  int _ownerEpoch = 0;
  bool _busy = false;
  _SyntheticDrive? _synthetic;
  String? _remoteSourceIdentity;
  String? _remoteIntentId;

  @override
  void dispose() {
    _keyController.dispose();
    _emailA.dispose();
    _passwordA.dispose();
    _emailB.dispose();
    _passwordB.dispose();
    final client = _client;
    if (client != null) client.dispose();
    super.dispose();
  }

  void _setActiveOwner(String? uid) {
    if (_activeOwner != uid) _ownerEpoch++;
    _activeOwner = uid;
  }

  SupabaseClient get _requireClient {
    final value = _client;
    if (value == null) throw StateError('client_not_connected');
    return value;
  }

  void _requireOwner(String uid) {
    if (_activeOwner != uid || _requireClient.auth.currentUser?.id != uid) {
      throw StateError('owner_context_changed');
    }
  }

  OwnerProfileGateway _gateway(String uid) {
    _requireOwner(uid);
    final epoch = _ownerEpoch;
    return OwnerProfileGateway(
      authClient: _requireClient,
      url: _devUrl,
      publicKey: _publishableKey!,
      applicationId: ManualDevAcceptancePolicy.applicationId,
      strictDev: true,
      approvedOwner: () => _activeOwner,
      approvedEpoch: () => epoch,
      isLeaseCurrent: (candidate) =>
          candidate == _ownerEpoch &&
          _activeOwner == uid &&
          _client?.auth.currentUser?.id == uid,
    );
  }

  Future<void> _connect() async {
    final key = _keyController.text.trim();
    if (!ManualDevAcceptancePolicy.permits(
      manualBuild: _manualBuild,
      isolatedBuild: _isolatedBuild,
      installedApplicationId: ManualDevAcceptancePolicy.applicationId,
      url: _devUrl,
      publishableKey: key,
    )) {
      _record('DEV bağlantısı', 'FAIL', 'publishable_key_required');
      return;
    }
    await _run('DEV bağlantısı', () async {
      final previous = _client;
      _setActiveOwner(null);
      if (previous != null) await previous.dispose();
      _publishableKey = key;
      _keyController.clear();
      _client = SupabaseClient(
        _devUrl,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await _restoreVault(reportMissingAsPass: true);
      return _activeOwner == null
          ? 'dev_client_ready_signed_out'
          : 'session_restored';
    });
  }

  Future<String> _restoreVault({bool reportMissingAsPass = false}) async {
    final client = _requireClient;
    final stored = await _vault.load();
    if (stored == null) return 'secure_vault_empty';
    if (client.auth.currentSession != null) {
      _setActiveOwner(null);
      await client.auth.signOut(scope: SignOutScope.local);
    }
    if (stored.expiresAt == null) throw StateError('stored_expiry_missing');

    Session candidate = stored;
    if (stored.isExpired ||
        stored.expiresAt! <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60) {
      final response = await client.auth.refreshSession(stored.refreshToken);
      candidate =
          response.session ?? (throw StateError('refresh_session_missing'));
      if (candidate.user.id != stored.user.id) {
        await client.auth.signOut(scope: SignOutScope.local);
        throw StateError('refresh_owner_mismatch');
      }
    }

    // Ask Auth to verify the candidate with the DEV server before installing a
    // recovered session or enabling any owner-scoped operation.
    final verified = await client.auth.getUser(candidate.accessToken);
    if (verified.user?.id != stored.user.id ||
        verified.user?.isAnonymous != false ||
        client.auth.currentSession?.user.id != stored.user.id &&
            candidate != stored) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw StateError('server_owner_verification_failed');
    }
    if (client.auth.currentSession == null) {
      final recovered = await client.auth.recoverSession(
        jsonEncode(candidate.copyWith(user: verified.user!).toJson()),
      );
      if (recovered.session?.user.id != stored.user.id) {
        await client.auth.signOut(scope: SignOutScope.local);
        throw StateError('session_recovery_mismatch');
      }
    }
    final active = client.auth.currentSession;
    if (active?.user.id != stored.user.id ||
        active?.accessToken != candidate.accessToken ||
        active?.refreshToken != candidate.refreshToken) {
      await client.auth.signOut(scope: SignOutScope.local);
      throw StateError('recovered_session_changed');
    }
    final verifiedSession = candidate.copyWith(user: verified.user!);
    await _vault.save(verifiedSession);
    _setActiveOwner(stored.user.id);
    if (!reportMissingAsPass) {
      _record('Güvenli oturum restore', 'PASS', 'server_owner_verified');
    }
    return 'server_owner_verified';
  }

  Future<void> _login({required bool accountA}) async {
    final label = accountA
        ? 'Hesap A giriş + profil'
        : 'Hesap B geçiş + izolasyon';
    final emailController = accountA ? _emailA : _emailB;
    final passwordController = accountA ? _passwordA : _passwordB;
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _record(label, 'FAIL', 'email_password_required');
      return;
    }
    passwordController.clear();
    await _run(label, () async {
      final response = await _requireClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      final session = response.session;
      if (user == null || session == null || user.id != session.user.id) {
        throw StateError('auth_response_mismatch');
      }
      if (user.isAnonymous) throw StateError('anonymous_account_rejected');
      if (accountA) {
        await _vault.save(session);
        _setActiveOwner(user.id);
        _accountAOwner = user.id;
        _accountBOwner = null;
      } else {
        if (_accountAOwner == null || _accountAOwner == user.id) {
          throw StateError('account_b_must_differ_from_a');
        }
        await _vault.save(session);
        _setActiveOwner(user.id);
        _accountBOwner = user.id;
      }
      await _verifyProfile(user.id);
      if (!accountA) await _verifyAccountAIsolation(user.id);
      return accountA
          ? 'auth_and_profile_verified'
          : 'account_b_isolated_from_a';
    });
  }

  Future<void> _verifyProfile(String uid) async {
    final gateway = _gateway(uid);
    final profile = await gateway.run((data, ownerId) async {
      if (ownerId != uid) throw StateError('profile_owner_mismatch');
      return data
          .from('profiles')
          .select('id,username,display_name')
          .eq('id', ownerId)
          .maybeSingle();
    });
    _requireOwner(uid);
    if (profile == null || profile['id'] != uid) {
      throw StateError('profile_row_missing');
    }
  }

  Future<void> _verifyAccountAIsolation(String uidB) async {
    final uidA = _accountAOwner;
    if (uidA == null || uidA == uidB) throw StateError('account_pair_invalid');
    final source = _remoteSourceIdentity;
    final adapter = _syncAdapter(uidB);
    final page = await adapter.download(
      ownerId: uidB,
      afterCursor: '',
      limit: 100,
    );
    _requireOwner(uidB);
    if (page.changes.any(
      (change) =>
          change.mutation.ownerId != uidB ||
          (source != null && change.mutation.sourceIdentity == source),
    )) {
      throw StateError('account_a_cloud_drive_visible_to_b');
    }
    final intentId = _remoteIntentId;
    if (intentId != null) {
      try {
        await _requireClient.storage
            .from(SupabaseOwnerDriveSyncAdapter.bucket)
            .download('$uidA/$intentId/envelope.json');
        throw StateError('account_a_storage_object_visible_to_b');
      } on StorageException catch (error) {
        final status = error.statusCode;
        final hidden =
            status == '401' ||
            status == '403' ||
            status == '404' ||
            (status == '400' &&
                (error.error ?? '').toLowerCase().contains('not found'));
        if (!hidden) {
          rethrow;
        }
      }
    }

    // A client pinned to A must refuse before making a request while B is live.
    if (source != null) {
      final aAdapter = _syncAdapter(uidA);
      try {
        await aAdapter.download(ownerId: uidA, afterCursor: '', limit: 10);
        throw StateError('stale_a_adapter_was_not_refused');
      } on OwnerSyncConflict catch (error) {
        if (error.code != 'authenticated_owner_mismatch') rethrow;
      }
    }
  }

  Future<void> _createSyntheticDrive() async {
    final uid = _accountAOwner;
    if (uid == null) throw StateError('account_a_required');
    _requireOwner(uid);
    final sourceId = DriveSourceProvenance.newUuidV4();
    final driveId = DriveSourceProvenance.newUuidV4();
    final started = DateTime.now().toUtc();
    final points = <CanonicalTelemetryPoint>[];
    final route = <RoutePoint>[];
    const startLat = 39.925533;
    const startLon = 32.866287;
    const stepDegrees = 250 / 111195;
    for (var i = 0; i <= 25; i++) {
      final pointTime = started.add(Duration(seconds: i * 12));
      final point = CanonicalTelemetryPoint(
        latitude: startLat + i * stepDegrees,
        longitude: startLon,
        timestamp: pointTime,
        speedMps: 20,
        headingDegrees: 0,
        altitudeMeters: 900,
        accuracyMeters: 4,
        distanceFromPreviousMeters: i == 0 ? 0 : 250,
        accelerationMps2: 0,
        speedSource: 'native',
      );
      points.add(point);
      route.add(
        RoutePoint(latitude: point.latitude, longitude: point.longitude),
      );
    }
    final ended = points.last.timestamp;
    final scope = jsonEncode(['local_account_store_v1', 'account', uid]);
    final metadata = <String, dynamic>{
      'reliabilityPolicyVersion': 1,
      'startedAtMicros': started.microsecondsSinceEpoch,
      'stopRequestedAtMicros': ended.microsecondsSinceEpoch,
      'provenanceStatus': 'proven',
      'sourceIdentity': sourceId,
      'sourceIdentityVersion': 1,
      'sourceNamespace': 'drive_source_v1',
    };
    final telemetry = DriveTelemetryRecord(
      driveSessionId: driveId,
      dataVersion: DriveTelemetryRecord.currentDataVersion,
      createdAt: ended,
      points: List.unmodifiable(points),
      acquisitionMetadata: Map.unmodifiable(metadata),
    );
    final scoreResult = const DriveScoreCalculator().calculateReliable(
      telemetry: points,
    );
    final score = DriveScoreRecord.fromResult(
      driveId: driveId,
      telemetryDataVersion: telemetry.dataVersion,
      calculatedAt: ended,
      result: scoreResult,
    );
    if (score.totalScore < 0 || score.totalScore > 1000) {
      throw StateError('score_outside_contract');
    }
    final drive = DriveSession(
      id: driveId,
      date: ended,
      distance: 6250,
      durationSeconds: ended.difference(started).inSeconds,
      averageSpeed: 20,
      maxSpeed: 20,
      mapImagePath: '',
      route: List.unmodifiable(route),
    );
    final provenance = DriveSourceProvenance.proven(
      sourceIdentity: sourceId,
      ownerScope: scope,
    );
    _synthetic = _SyntheticDrive(
      drive: drive,
      telemetry: telemetry,
      score: score,
      provenance: provenance,
    );
  }

  SupabaseOwnerDriveSyncAdapter _syncAdapter(String uid) {
    final gateway = _gateway(uid);
    return SupabaseOwnerDriveSyncAdapter(
      client: _requireClient,
      ownerId: uid,
      requireCurrent: () => _requireOwner(uid),
      authenticatedUserId: () => _activeOwner,
      uploadGateway: gateway,
    );
  }

  Future<void> _uploadDownload() async {
    final uid = _accountAOwner;
    final synthetic = _synthetic;
    if (uid == null || synthetic == null) {
      throw StateError('account_a_drive_required');
    }
    _requireOwner(uid);
    final ownerScope = jsonEncode(['local_account_store_v1', 'account', uid]);
    final payload = LocalSourceBundle(
      drive: synthetic.drive,
      telemetry: synthetic.telemetry,
      score: synthetic.score,
      ownerScope: ownerScope,
      sourceProvenance: synthetic.provenance,
    ).toMap()..['roads'] = <dynamic>[];
    final fingerprint = canonicalOwnerSyncSha256(payload);
    final idempotencyKey =
        'owner-sync-v2:${sha256.convert(utf8.encode('$ownerScope|$uid|driveUpsert|${synthetic.provenance.sourceIdentity}'))}';
    final mutation = OwnerSyncMutation(
      version: OwnerDriveSyncClient.contractVersion,
      kind: OwnerSyncMutationKind.driveUpsert,
      ownerScope: ownerScope,
      ownerId: uid,
      idempotencyKey: idempotencyKey,
      payloadFingerprint: fingerprint,
      sourceIdentity: synthetic.provenance.sourceIdentity!,
      payload: payload,
    );
    final envelope = canonicalOwnerSyncBytes(mutation.toMap());
    final adapter = _syncAdapter(uid);
    await adapter.verifyBackend();
    final intent = await adapter.beginUpload(
      OwnerSyncUploadDescriptor(
        contractVersion: OwnerDriveSyncClient.contractVersion,
        ownerId: uid,
        ownerScope: ownerScope,
        sourceIdentity: mutation.sourceIdentity,
        idempotencyKey: idempotencyKey,
        payloadFingerprint: fingerprint,
        objectSha256: sha256.convert(envelope).toString(),
        objectBytes: envelope.length,
      ),
    );
    if (intent.state != OwnerSyncStagingState.finalized) {
      await adapter.uploadPrivateObject(
        intentId: intent.id,
        envelopeBytes: envelope,
      );
    }
    final receipt = intent.receipt ?? await adapter.finalizeUpload(intent.id);
    if (receipt.ownerScope != ownerScope ||
        receipt.payloadFingerprint != fingerprint ||
        receipt.idempotencyKey != idempotencyKey) {
      throw StateError('finalize_receipt_mismatch');
    }
    var cursor = '';
    var found = false;
    for (var pageIndex = 0; pageIndex < 20; pageIndex++) {
      final page = await adapter.download(
        ownerId: uid,
        afterCursor: cursor,
        limit: 100,
      );
      if (page.changes.any(
        (change) =>
            change.mutation.sourceIdentity == mutation.sourceIdentity &&
            (change.mutation.payload['drive'] as Map?)?['id'] ==
                synthetic.drive.id &&
            change.mutation.payloadFingerprint == fingerprint,
      )) {
        found = true;
        break;
      }
      if (!page.hasMore) break;
      cursor = page.nextCursor;
    }
    _requireOwner(uid);
    if (!found) throw StateError('finalized_drive_missing_from_download');
    _remoteSourceIdentity = mutation.sourceIdentity;
    _remoteIntentId = intent.id;
    _record(
      'DEV upload + finalize + download',
      'PASS',
      'owner_ack_and_payload_match',
    );
  }

  Future<void> _planetRead() async {
    final uid = _activeOwner;
    if (uid == null) throw StateError('account_required');
    final gateway = _gateway(uid);
    final rows = await gateway.run((data, ownerId) async {
      final value = await data
          .from('world_publishes')
          .select(worldPublishColumns)
          .eq('user_id', ownerId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(value);
    });
    _requireOwner(uid);
    if (rows.any((row) => row['user_id'] != uid)) {
      throw StateError('planet_read_owner_mismatch');
    }
    _record('Planet owner read', 'PASS', 'owner_rows_${rows.length}');
  }

  Future<void> _planetPublish() async {
    final uid = _accountAOwner;
    final synthetic = _synthetic;
    if (uid == null || synthetic == null) {
      throw StateError('account_a_drive_required');
    }
    _requireOwner(uid);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sentetik sürüşü DEV Planet’e yayınla?'),
        content: const Text(
          'Yalnız sentetik rota ve telemetri gönderilir. Sunucu bu veriyi işleyip DEV Planet’te gösterebilir. Bu ekranda otomatik silme yapılmaz; veriler sonradan ayrıca onaylanmış resmi akışla temizlenmelidir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      _record(
        'Planet schema2 publication',
        'SKIP',
        'publication_not_confirmed',
      );
      return;
    }
    await _run('Planet schema2 publish', () async {
      final gateway = _gateway(uid);
      final publishService = WorldPublishService(
        gateway: OwnerScopedWorldPublishGateway(gateway),
        savedDriveLookup: (id) {
          if (id != synthetic.drive.id) {
            throw StateError('synthetic_drive_id_mismatch');
          }
          return synthetic.drive;
        },
        telemetryLoader: (id) =>
            id == synthetic.drive.id ? synthetic.telemetry : null,
        scoreLoader: (id) => id == synthetic.drive.id ? synthetic.score : null,
        requireReliableNewPublish: true,
      );
      final builder = PublishedDriveSourceBuilder(
        telemetryLoader: (id) =>
            id == synthetic.drive.id ? synthetic.telemetry : null,
        scoreLoader: (id) => id == synthetic.drive.id ? synthetic.score : null,
      );
      final submission = WorldPublishSubmissionService(
        publishService: publishService,
        uploadService: WorldPublishSourceUploadService(
          gateway: OwnerScopedWorldPublishSourceGateway(gateway),
          builder: builder,
        ),
        processingService: WorldPublishProcessingService(
          gateway: OwnerScopedWorldPublishProcessingGateway(gateway),
        ),
        ownerDriveLookup: (id) {
          if (id != synthetic.drive.id) {
            throw StateError('synthetic_drive_id_mismatch');
          }
          return synthetic.drive;
        },
        requireOwnerCurrent: () => _requireOwner(uid),
      );
      final result = await submission.submitDriveForPlanet(
        synthetic.drive,
        confirmedFullDriveShare: true,
      );
      _requireOwner(uid);
      if (result.status != WorldPublishSubmissionStatus.success ||
          result.publish?.status != WorldPublishStatus.published ||
          result.publish?.sourceSchemaVersion != 2) {
        throw StateError(
          'planet_${result.status.name}_schema_${result.publish?.sourceSchemaVersion ?? 0}',
        );
      }
      _record(
        'Planet schema2 publication',
        'PASS',
        'published_and_read_back_v2',
      );
      return 'published_and_read_back_v2';
    });
  }

  Future<void> _logout() async {
    final client = _client;
    if (client == null) {
      _record('Logout', 'FAIL', 'client_not_connected');
      return;
    }
    setState(() {
      _busy = true;
      _setActiveOwner(null);
    });
    try {
      await client.auth.signOut(scope: SignOutScope.local);
      await _vault.clear();
      _record('Logout', 'PASS', 'local_session_and_vault_cleared');
    } catch (error) {
      _record('Logout', 'FAIL', _safeCode(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreAfterFreshClient() async {
    final client = _client;
    if (client == null || _accountAOwner == null) {
      _record('A tekrar giriş + secure restore', 'FAIL', 'account_a_required');
      return;
    }
    await _run('A tekrar giriş + secure restore', () async {
      final response = await client.auth.signInWithPassword(
        email: _emailA.text.trim(),
        password: _passwordA.text,
      );
      _passwordA.clear();
      final session = response.session;
      if (response.user == null ||
          session == null ||
          response.user!.id != _accountAOwner) {
        throw StateError('account_a_reauth_mismatch');
      }
      await _vault.save(session);
      _setActiveOwner(null);
      await client.auth.signOut(scope: SignOutScope.local);
      await client.dispose();
      _client = SupabaseClient(
        _devUrl,
        _publishableKey!,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await _restoreVault();
      if (_activeOwner != _accountAOwner) {
        throw StateError('account_a_restore_mismatch');
      }
      return 'fresh_sdk_server_verified_owner_a';
    });
  }

  Future<void> _run(String label, Future<String> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await operation();
      _record(label, 'PASS', code);
    } catch (error) {
      _record(label, 'FAIL', _safeCode(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _safeCode(Object error) {
    final String? raw = switch (error) {
      AuthException e => e.code ?? e.statusCode,
      OwnerSyncConflict e => e.code,
      OwnerSyncTransportFailure e => e.code,
      PostgrestException e => e.code,
      StorageException e => e.statusCode,
      FunctionException e => 'function_http_${e.status}',
      _ => null,
    };
    if (raw != null && RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(raw)) {
      return raw.toLowerCase();
    }
    if (error is TimeoutException) return 'request_timeout';
    if (error is FormatException) return 'response_format_rejected';
    return error.runtimeType
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '')
        .toLowerCase();
  }

  void _record(String label, String state, String code) {
    final safe = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(code)
        ? code.toLowerCase()
        : 'result_recorded';
    if (!mounted) return;
    setState(() => _outcomes[label] = _Outcome(state, safe, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final clientReady = _client != null;
    final aReady = _accountAOwner != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriveIt • DEV kabul'),
        backgroundColor: const Color(0xff091524),
        actions: [
          if (_activeOwner != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _activeOwner == _accountAOwner
                      ? 'Hesap A'
                      : _activeOwner == _accountBOwner
                      ? 'Hesap B'
                      : 'Oturum',
                  style: const TextStyle(color: Color(0xff12e6df)),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          const _InfoCard(
            title: 'İzole test paketi',
            body:
                'Bu ekran yalnız DEV Supabase’e bağlanır. Publishable key bellekte tutulur; parola ve key derleme girdisi, dosya veya log değildir. Hiçbir otomatik hesap silme işlemi yoktur.',
          ),
          const SizedBox(height: 12),
          _section('DEV bağlantısı'),
          TextField(
            controller: _keyController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Supabase publishable key',
              hintText: 'sb_publishable_…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.link),
              label: Text(clientReady ? 'Key’i tekrar bağla' : 'DEV’e bağlan'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hedef sabit: $_devUrl',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _section('Geçici test hesapları'),
          _accountFields('Account A', _emailA, _passwordA),
          const SizedBox(height: 10),
          _accountFields('Account B', _emailB, _passwordB),
          const SizedBox(height: 12),
          _action(
            '1. Account A giriş + profil',
            icon: Icons.person_search,
            enabled: clientReady,
            onPressed: () => _login(accountA: true),
          ),
          _action(
            '2. Sentetik GPS sürüşü + Drive Score',
            icon: Icons.route,
            enabled: clientReady && aReady,
            onPressed: () => _run('Sentetik GPS + Drive Score', () async {
              await _createSyntheticDrive();
              return 'synthetic_drive_score_ready';
            }),
          ),
          _action(
            '3. DEV upload → finalize ACK → download',
            icon: Icons.cloud_sync,
            enabled:
                clientReady &&
                _synthetic != null &&
                _activeOwner == _accountAOwner,
            onPressed: () => _run('DEV upload + finalize + download', () async {
              await _uploadDownload();
              return 'owner_ack_and_payload_match';
            }),
          ),
          _action(
            '4. Account B’ye geç + Account A izolasyonu',
            icon: Icons.swap_horiz,
            enabled: clientReady && aReady,
            onPressed: () => _login(accountA: false),
          ),
          _action(
            '5. Account A tekrar giriş + güvenli restore',
            icon: Icons.restore,
            enabled: clientReady && aReady,
            onPressed: _restoreAfterFreshClient,
          ),
          _section('DriveIt Gezegeni'),
          _action(
            '6a. Kendi Planet kayıtlarını oku',
            icon: Icons.public,
            enabled: clientReady && _activeOwner != null,
            onPressed: () => _run('Planet owner read', () async {
              await _planetRead();
              return 'owner_rows_verified';
            }),
          ),
          _action(
            '6b. Sentetik sürüşü Planet’e yayınla (isteğe bağlı)',
            icon: Icons.publish,
            enabled:
                clientReady &&
                _synthetic != null &&
                _activeOwner == _accountAOwner,
            onPressed: _planetPublish,
          ),
          if (_synthetic != null)
            _InfoCard(
              title: 'Sentetik sürüş hazır',
              body:
                  'Mesafe: 6.25 km • örnekler: ${_synthetic!.telemetry.points.length} • Drive Score: ${_synthetic!.score.totalScore.round()}/1000. Bu rota cihaz GPS’inden alınmadı.',
            ),
          _action(
            '7. Logout (yalnız bu izole test oturumu)',
            icon: Icons.logout,
            enabled: clientReady && _activeOwner != null,
            onPressed: _logout,
          ),
          const SizedBox(height: 16),
          _section('Sonuçlar'),
          if (_outcomes.isEmpty) const Text('Henüz test çalıştırılmadı.'),
          for (final entry in _outcomes.entries.toList().reversed)
            _OutcomeTile(label: entry.key, outcome: entry.value),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _accountFields(
    String label,
    TextEditingController email,
    TextEditingController password,
  ) => Card(
    color: const Color(0xff101c2c),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Parola (yalnız bellekte)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xff12e6df),
      ),
    ),
  );

  Widget _action(
    String title, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      onPressed: !enabled || _busy ? null : onPressed,
      icon: Icon(icon),
      label: Align(alignment: Alignment.centerLeft, child: Text(title)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: Color(0x6637ded8)),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xff101c2c),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    ),
  );
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({required this.label, required this.outcome});
  final String label;
  final _Outcome outcome;
  @override
  Widget build(BuildContext context) {
    final pass = outcome.state == 'PASS';
    return Card(
      color: const Color(0xff101c2c),
      child: ListTile(
        leading: Icon(
          pass ? Icons.check_circle : Icons.error,
          color: pass ? const Color(0xff12e6df) : Colors.orangeAccent,
        ),
        title: Text(label),
        subtitle: Text('${outcome.state} • ${outcome.code}'),
        trailing: Text(
          '${outcome.at.hour.toString().padLeft(2, '0')}:${outcome.at.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}
