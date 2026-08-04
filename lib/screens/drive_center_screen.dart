import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/foreground_service.dart';
import 'map_screen.dart';

class DriveCenterScreen extends StatefulWidget {
  const DriveCenterScreen({super.key});

  @override
  State<DriveCenterScreen> createState() => _DriveCenterScreenState();
}

class _DriveCenterScreenState extends State<DriveCenterScreen> {
  late final Future<bool> _active = _checkActiveDrive();

  Future<bool> _checkActiveDrive() async {
    return await ForegroundService.isDriveActive() || await FlutterForegroundTask.isRunningService;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _active,
        builder: (context, snapshot) => MapScreen(resumeDrive: snapshot.data == true),
      );
}
