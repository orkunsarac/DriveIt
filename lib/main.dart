import 'services/foreground_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/route_point.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/drive_session.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(DriveSessionAdapter());
  Hive.registerAdapter(RoutePointAdapter());

  await Hive.openBox<DriveSession>('drives');

  await initializeDateFormatting('tr_TR');

  await ForegroundService.init();
  final activeDrive = await ForegroundService.isDriveActive();
  final stopRequested = await ForegroundService.consumeStopRequest();
  runApp(DriveItApp(
    resumeDrive: activeDrive || stopRequested,
    initialScreen: const HomeScreen(),
  ));
}

class DriveItApp extends StatefulWidget {
  final Widget initialScreen;
  final bool resumeDrive;
  const DriveItApp({super.key, this.initialScreen = const HomeScreen(), this.resumeDrive = false});

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
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Noto Sans',
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ).copyWith(
          bodyMedium: const TextStyle(fontSize: 14, letterSpacing: -0.15),
          bodySmall: const TextStyle(fontSize: 12, letterSpacing: -0.1),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.25),
        ),
      ),
      home: widget.initialScreen,
    );
  }
}
