import 'dart:async';

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
import 'features/my_world/services/my_world_runtime.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

void main() async {
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
  await HiveMyWorldSettingsStore.openBox(Hive);

  // Apply World rule/index migrations before the first screen can read the
  // active snapshot. The operation is local and reuses stored validated roads;
  // it never triggers a Mapbox request.
  await MyWorldRuntime.ensureCurrentWorldIndex();

  await initializeDateFormatting('tr_TR');

  await ForegroundService.init();
  final activeDrive = await ForegroundService.isDriveActive();
  final stopRequested = await ForegroundService.consumeStopRequest();
  runApp(
    DriveItApp(
      resumeDrive: activeDrive || stopRequested,
      initialScreen: const HomeScreen(),
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
  const DriveItApp({
    super.key,
    this.initialScreen = const HomeScreen(),
    this.resumeDrive = false,
  });

  @override
  State<DriveItApp> createState() => _DriveItAppState();
}

final GlobalKey<NavigatorState> driveNavigatorKey = GlobalKey<NavigatorState>();

class _DriveItAppState extends State<DriveItApp> {
  void _onTaskData(Object data) {
    if (data is Map && data['openDrive'] == true) {
      driveNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MapScreen(resumeDrive: true)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    if (widget.resumeDrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        driveNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MapScreen(resumeDrive: true)),
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
      home: widget.initialScreen,
    );
  }
}
