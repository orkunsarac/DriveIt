import 'dart:async';
import 'config/local_ownership_gate.dart';
import 'services/local_ownership_bootstrap.dart';

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
  await LocalOwnershipBootstrap.run(
    gate: LocalOwnershipGate.production,
    legacyBootstrap: _legacyBootstrap,
  );
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
  final Widget initialScreen;
  final bool resumeDrive;
  final DriveRecoveryStatus? recoveryStatus;
  const DriveItApp({
    super.key,
    this.initialScreen = const HomeScreen(),
    this.resumeDrive = false,
    this.recoveryStatus,
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
      routes: {OnboardingScreen.previewRoute: (_) => const OnboardingScreen()},
      home: widget.initialScreen,
    );
  }
}
