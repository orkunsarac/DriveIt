import 'dart:async';
import 'dart:io' show Platform;
import 'config/local_ownership_gate.dart';
import 'services/local_ownership_bootstrap.dart';
import 'services/device_drive_archive.dart';
import 'services/android_device_archive_authorizer.dart';
import 'services/local_owner_lifecycle.dart';
import 'widgets/owner_personal_navigator.dart';
import 'features/account/widgets/driveit_account_section.dart';

import 'services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/route_point.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/drive_session.dart';
import 'features/my_world/persistence/my_world_hive.dart';
import 'features/my_world/services/my_world_settings_service.dart';
import 'services/drive_score_storage_service.dart';
import 'services/drive_telemetry_storage_service.dart';
import 'services/profile_storage_service.dart';
import 'config/supabase_bootstrap.dart';
import 'services/supabase_account_service.dart';
import 'features/my_world/services/my_world_runtime.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/drive_recovery_screen.dart';
import 'services/drive_recovery_status.dart';
import 'services/career_contribution_repository.dart';
import 'services/local_lifecycle_journal.dart';
import 'features/world_publish/segments/planet_segment_outbox.dart';
import 'features/my_world/repositories/world_source_snapshot_repository.dart';

void main() async {
  await startDriveIt();
}

/// The application entry point is shared by main and isolated acceptance.
/// Production remains OFF; an enabled gate requires the complete composition.
Future<ControlledOwnershipRuntime?> startDriveIt({
  LocalOwnershipGate gate = LocalOwnershipGate.production,
  ControlledOwnershipDependencies? controlled,
  SavedDriveArchiveSource? archiveSource,
  Future<Set<String>> Function()? unfinishedArchiveDrives,
  Future<bool> Function()? confirmGuest,
  DeviceArchiveAuthorizer? archiveAuthorizer,
  void Function(Widget) mountApplication = runApp,
  Future<void> Function()? legacyBootstrap,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!gate.enabled) {
    return LocalOwnershipBootstrap.run(
      gate: gate,
      legacyBootstrap: legacyBootstrap ?? _legacyBootstrap,
    );
  }
  // Controlled Android activation is test-only and cannot run in the real
  // application's sandbox, even if a caller supplies synthetic dependencies.
  if (Platform.isAndroid) {
    if (!SupabaseBootstrap.isIsolatedAndroidTest ||
        await const MethodChannel(
              'driveit/device_archive_security',
            ).invokeMethod<bool>('isIsolatedDebugRuntime') !=
            true) {
      throw StateError('Controlled Android runtime requires isolated package');
    }
  }
  if (controlled == null ||
      archiveSource == null ||
      unfinishedArchiveDrives == null ||
      controlled.writerFence == null) {
    throw StateError('Owner application dependencies incomplete');
  }
  // Restore the SDK/session before opening ANY personal store. Failure never
  // resolves to a guest. The explicit choice is required only for a null session.
  final auth = await controlled.restoreAuth();
  if (auth.userId == null && !await (confirmGuest ?? _confirmGuest)()) {
    throw StateError('Explicit guest choice required');
  }
  LocalOwnerLifecycle.ownerFor(auth.userId);
  if ((await unfinishedArchiveDrives()).isNotEmpty) {
    throw StateError('Legacy GPS recovery required before owner activation');
  }
  final dependencies = ControlledOwnershipDependencies(
    restoreAuth: () async => auth,
    descriptor: controlled.descriptor,
    databaseFactory: controlled.databaseFactory,
    openStore: controlled.openStore,
    producerRunning: controlled.producerRunning,
    attachForeground: controlled.attachForeground,
    detachForeground: controlled.detachForeground,
    writerFence: controlled.writerFence,
    worldRoadMatching: controlled.worldRoadMatching,
  );
  final runtime = (await LocalOwnershipBootstrap.run(
    gate: gate,
    legacyBootstrap: () async => throw StateError('Shared storage forbidden'),
    controlled: dependencies,
  ))!;
  try {
    // A supplied attach callback must actually bind this runtime. Never inspect
    // the legacy global journal when the controlled composition is incomplete.
    ForegroundService.requireOwnerLease(runtime.owner.lease);
    await initializeDateFormatting('tr_TR');
    await ForegroundService.init();
    SupabaseAccountService.instance.startIdentitySync();
    final recovery = await ForegroundService.inspectRecovery();
    mountApplication(
      DriveItApp(
        ownerRuntime: runtime,
        ownerInitialRoute:
            recovery.canStartNewDrive &&
                runtime.owner.lease.pendingDriveFinalizations().isEmpty
            ? '/'
            : '/drive',
        deviceArchiveLoader: (lease) => runtime.owner.withOwnerOperation((
          current,
        ) async {
          lease.requireCurrent();
          if (!identical(current, lease)) {
            throw StateError('Archive owner changed');
          }
          final archive = await DeviceDriveArchiveSnapshot.prepare(
            source: archiveSource,
            writers: controlled.writerFence!,
            unfinishedDriveIds: () async => {
              ...await unfinishedArchiveDrives(),
              ...((await runtime.gps.journal.recoverableSessions()).map(
                (s) => s.id,
              )),
              if (await runtime.gps.journal.active() case final session?)
                session.id,
              if (await controlled.producerRunning()) 'native_producer_running',
            },
          );
          lease.requireCurrent();
          return DeviceDriveArchiveAccess(
            gate: gate,
            snapshot: archive,
            authorizer: archiveAuthorizer ?? AndroidDeviceArchiveAuthorizer(),
          );
        }),
      ),
    );
    return runtime;
  } catch (_) {
    // Never detach or close a running producer on a failed UI composition.
    // Its immutable journal remains the recovery authority.
    if (!await controlled.producerRunning()) {
      await runtime.closeAfterProducerDetached();
    }
    rethrow;
  }
}

Future<bool> _confirmGuest() {
  final choice = Completer<bool>();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Misafir sürüşleri bu cihazda ayrı tutulur. Hesaba giriş yapmak '
                'bu kayıtları otomatik aktarmaz.',
              ),
              const DriveItAccountSection(),
              FilledButton(
                onPressed: () {
                  if (!choice.isCompleted) choice.complete(true);
                },
                child: const Text('Devam Et / Misafir Olarak Kullan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return choice.future;
}

Future<void> _legacyBootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  await Hive.initFlutter();

  Hive.registerAdapter(DriveSessionAdapter());
  Hive.registerAdapter(RoutePointAdapter());
  DriveTelemetryHive.registerAdapters(Hive);
  DriveScoreHive.registerAdapters(Hive);
  MyWorldHive.registerAdapters(Hive);

  await Hive.openBox<DriveSession>('drives');
  await Hive.openBox<dynamic>('career_totals');
  await Hive.openBox<dynamic>('symbolic_routes');
  // Drive names live in their own box so the existing DriveSession adapter
  // and all previously stored field indexes remain untouched.
  await Hive.openBox<dynamic>('drive_names');
  await Hive.openBox<dynamic>(ProfileStorageService.boxName);
  await DriveTelemetryHive.openBox(Hive);
  await DriveScoreHive.openBox(Hive);
  await MyWorldHive.openBoxes(Hive);
  // Additive stores only: no legacy backfill or consumer activation at startup.
  await WorldSourceSnapshotRepository.open(Hive);
  await CareerContributionRepository.open(Hive);
  await LocalLifecycleJournal.open(Hive);
  await PlanetSegmentOutbox.open(Hive);
  await HiveMyWorldSettingsStore.openBox(Hive);

  // Apply World rule/index migrations before the first screen can read the
  // active snapshot. The operation is local and reuses stored validated roads;
  // it never triggers a Mapbox request.
  await MyWorldRuntime.ensureCurrentWorldIndex();

  await initializeDateFormatting('tr_TR');

  await ForegroundService.init();
  final recovery = await ForegroundService.isDriveActive();
  final profile = await ProfileStorageService.open();
  await SupabaseBootstrap.initializeIfConfigured();
  SupabaseAccountService.instance.startIdentitySync();
  final onboardingCompleted = profile.onboardingCompleted;
  runApp(
    DriveItApp(
      recoveryStatus: onboardingCompleted ? recovery : null,
      initialScreen: onboardingCompleted
          ? const HomeScreen()
          : const OnboardingScreen(),
    ),
  );
  // Do not block app startup; pending World jobs are durable and retryable.
  // Diagnostics remain available through the explicit debug tool rather than
  // scanning and printing the entire World projection on every launch.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(MyWorldRuntime.drainPendingJobs());
  });
}

class DriveItApp extends StatefulWidget {
  final ControlledOwnershipRuntime? ownerRuntime;
  final String ownerInitialRoute;
  final DeviceDriveArchiveSnapshot? deviceArchiveSnapshot;
  final Future<DeviceDriveArchiveAccess> Function(LocalOwnerLease)?
  deviceArchiveLoader;
  final Widget initialScreen;
  final bool resumeDrive;
  final DriveRecoveryStatus? recoveryStatus;
  const DriveItApp({
    super.key,
    this.initialScreen = const HomeScreen(),
    this.resumeDrive = false,
    this.recoveryStatus,
    this.ownerRuntime,
    this.ownerInitialRoute = '/',
    this.deviceArchiveSnapshot,
    this.deviceArchiveLoader,
  });

  @override
  State<DriveItApp> createState() => _DriveItAppState();
}

final GlobalKey<NavigatorState> driveNavigatorKey = GlobalKey<NavigatorState>();

class _DriveItAppState extends State<DriveItApp> {
  void _onTaskData(Object data) {
    if (data is Map && data['openDrive'] == true) {
      driveNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const DriveRecoveryScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.ownerRuntime != null) return;
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    final recovery = widget.recoveryStatus;
    if (widget.resumeDrive ||
        (recovery != null && !recovery.canStartNewDrive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        driveNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DriveRecoveryScreen(initialStatus: recovery),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveIt',
      navigatorKey: driveNavigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Noto Sans',
        textTheme: ThemeData.dark().textTheme
            .apply(
              fontFamily: 'Noto Sans',
              bodyColor: Colors.white,
              displayColor: Colors.white,
            )
            .copyWith(
              bodyMedium: const TextStyle(fontSize: 14, letterSpacing: -0.15),
              bodySmall: const TextStyle(fontSize: 12, letterSpacing: -0.1),
              titleMedium: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              titleLarge: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.25,
              ),
            ),
      ),
      routes: widget.ownerRuntime == null
          ? {OnboardingScreen.previewRoute: (_) => const OnboardingScreen()}
          : const {},
      home: widget.ownerRuntime == null
          ? widget.initialScreen
          : _OwnedApplicationHome(
              runtime: widget.ownerRuntime!,
              archive: widget.deviceArchiveSnapshot,
              archiveLoader: widget.deviceArchiveLoader,
              initialRoute: widget.ownerInitialRoute,
            ),
    );
  }
}

class _OwnedApplicationHome extends StatefulWidget {
  const _OwnedApplicationHome({
    required this.runtime,
    this.archive,
    this.archiveLoader,
    this.initialRoute = '/',
  });
  final ControlledOwnershipRuntime runtime;
  final String initialRoute;
  final DeviceDriveArchiveSnapshot? archive;
  final Future<DeviceDriveArchiveAccess> Function(LocalOwnerLease)?
  archiveLoader;
  @override
  State<_OwnedApplicationHome> createState() => _OwnedApplicationHomeState();
}

class _OwnedApplicationHomeState extends State<_OwnedApplicationHome>
    with WidgetsBindingObserver {
  int? _workerEpoch;
  int? _initialEpoch;
  GlobalKey<NavigatorState> _personalNavKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_taskData);
    widget.runtime.owner.addListener(_ownerChanged);
    _initialEpoch = widget.runtime.owner.epoch;
    _ownerChanged();
  }

  void _ownerChanged() {
    final owner = widget.runtime.owner;
    if (_workerEpoch != owner.epoch) {
      _personalNavKey = GlobalKey<NavigatorState>();
    }
    if (owner.state != LocalOwnerState.ready || _workerEpoch == owner.epoch) {
      return;
    }
    _workerEpoch = owner.epoch;
    owner.scheduleWorldJobs(owner.lease);
  }

  void _taskData(Object data) {
    if (data is Map &&
        data['openDrive'] == true &&
        widget.runtime.owner.state == LocalOwnerState.ready) {
      _personalNavKey.currentState?.pushNamed('/drive');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final owner = widget.runtime.owner;
    if (state == AppLifecycleState.resumed &&
        owner.state == LocalOwnerState.ready) {
      owner.scheduleWorldJobs(owner.lease);
    }
  }

  @override
  void dispose() {
    widget.runtime.owner.removeListener(_ownerChanged);
    FlutterForegroundTask.removeTaskDataCallback(_taskData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.runtime.owner,
    builder: (context, _) {
      final owner = widget.runtime.owner;
      return Column(
        children: [
          if (owner.state == LocalOwnerState.ready &&
              owner.lease.owner.userId == null)
            const SafeArea(
              bottom: false,
              child: Material(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Misafir sürüşleri bu cihazda '
                    'ayrı tutulur; hesaba otomatik aktarılmaz.',
                  ),
                ),
              ),
            ),
          if (owner.state == LocalOwnerState.ready &&
              owner.worldErrorCode != null)
            const Material(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Sürüş kaydedildi. Benim Dünyam işlemi bekliyor. '
                  'owner_world_retry_pending',
                ),
              ),
            ),
          Expanded(
            child: OwnerPersonalNavigator(
              runtime: owner,
              navigatorKey: _personalNavKey,
              initialRoute: owner.epoch == _initialEpoch
                  ? widget.initialRoute
                  : '/',
              deviceArchiveSnapshot: widget.archive,
              deviceArchiveLoader: widget.archiveLoader,
              legacyChild: const SizedBox.shrink(),
            ),
          ),
        ],
      );
    },
  );
}
