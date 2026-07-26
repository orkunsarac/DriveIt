import 'services/foreground_service.dart';
import 'models/route_point.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/drive_session.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(DriveSessionAdapter());
  Hive.registerAdapter(RoutePointAdapter());

  await Hive.openBox<DriveSession>('drives');

  await initializeDateFormatting('tr_TR');

  await ForegroundService.init();
  
  runApp(const DriveItApp());
}

class DriveItApp extends StatelessWidget {
  const DriveItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriveIt',
      home: const HomeScreen(),
    );
  }
}