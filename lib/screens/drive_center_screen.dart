import 'package:flutter/material.dart';
import 'drive_recovery_screen.dart';

class DriveCenterScreen extends StatefulWidget {
  const DriveCenterScreen({super.key});

  @override
  State<DriveCenterScreen> createState() => _DriveCenterScreenState();
}

class _DriveCenterScreenState extends State<DriveCenterScreen> {
  @override
  Widget build(BuildContext context) =>
      const DriveRecoveryScreen(allowNewDrive: true);
}
