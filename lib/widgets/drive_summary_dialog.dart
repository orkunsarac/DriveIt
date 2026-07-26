import '../models/route_point.dart';
import '../models/drive_session.dart';
import '../services/drive_storage_service.dart';
import 'package:flutter/material.dart';

class DriveSummaryDialog {
  static Future<void> show(
    BuildContext context, {
    required double totalDistance,
    required Duration driveDuration,
    required double averageSpeed,
    required double maxSpeed,
    required String mapImagePath,
    required List<RoutePoint> route,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Center(
          child: Text(
            "🏁 Sürüş Tamamlandı",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_car,
                size: 60,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("Toplam Mesafe"),
                      const SizedBox(height: 8),
                      Text(
                        "${(totalDistance / 1000).toStringAsFixed(2)} km",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("Sürüş Süresi"),
                      const SizedBox(height: 8),
                      Text(
                        "${driveDuration.inMinutes} dk ${driveDuration.inSeconds % 60} sn",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text("Ortalama Hız"),
                  trailing: Text(
                    "${averageSpeed.toStringAsFixed(1)} km/h",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: const Text("Maksimum Hız"),
                  trailing: Text(
                    "${maxSpeed.toStringAsFixed(1)} km/h",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text("Kapat"),
),

ElevatedButton.icon(
  onPressed: () async {
  final drive = DriveSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    date: DateTime.now(),
    distance: totalDistance,
    durationSeconds: driveDuration.inSeconds,
    averageSpeed: averageSpeed,
    maxSpeed: maxSpeed,
    mapImagePath: mapImagePath,
    route: route,
  );

  await DriveStorageService.saveDrive(drive);

  if (context.mounted) {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Sürüş başarıyla kaydedildi"),
      ),
    );
  }
},
  icon: const Icon(Icons.save),
  label: const Text("Sürüşü Kaydet"),
),
        ],
      ),
    );
  }
}