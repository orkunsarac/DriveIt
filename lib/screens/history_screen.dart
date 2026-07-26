import 'drive_detail_screen.dart';
import 'package:flutter/material.dart';

import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';
import '../widgets/drive_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DriveSession> drives = [];

  @override
  void initState() {
    super.initState();
    _loadDrives();
  }

  void _loadDrives() {
    setState(() {
      drives = DriveStorageService.getAllDrives();
    });
  }

  Future<void> _deleteDrive(DriveSession drive) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sürüşü Sil"),
        content: const Text(
          "Bu sürüşü silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (result == true) {
      await DriveStorageService.deleteDrive(drive.id);
      _loadDrives();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sürüş silindi"),
          ),
        );
      }
    }
  }

  void _openDetail(DriveSession drive) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DriveDetailScreen(
        drive: drive,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sürüşlerim"),
      ),
      body: drives.isEmpty
          ? const Center(
              child: Text(
                "Henüz kayıtlı sürüş bulunmuyor.",
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: drives.length,
              itemBuilder: (context, index) {
                final drive = drives[index];

                return DriveCard(
                  drive: drive,
                  onTap: () => _openDetail(drive),
                  onDelete: () => _deleteDrive(drive),
                );
              },
            ),
    );
  }
}