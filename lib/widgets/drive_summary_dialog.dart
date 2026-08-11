import '../models/route_point.dart';
import '../models/drive_session.dart';
import '../models/drive_metrics.dart';
import '../services/drive_storage_service.dart';
import 'package:flutter/material.dart';
import 'neon_route_preview.dart';

class DriveSummaryDialog {
  static Future<void> show(
    BuildContext context, {
    required double totalDistance,
    required Duration driveDuration,
    required double averageSpeed,
    required double maxSpeed,
    required String mapImagePath,
    required List<RoutePoint> route,
    int stopCount = 0,
    int stoppedSeconds = 0,
    required DriveMetrics metrics,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff0a1830),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text(
            "🏁 Sürüş Tamamlandı",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff071326),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xff248fff)),
                ),
                child: NeonRoutePreview(route: route),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _analysisCard(metrics),

              const SizedBox(height: 16),
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
                stopCount: stopCount,
                stoppedSeconds: stoppedSeconds,
                hardBrakeCount: metrics.hardBrakeCount,
                hardAccelerationCount: metrics.hardAccelerationCount,
                sharpTurnCount: metrics.sharpTurnCount,
                maxAccelerationG: metrics.maxAccelerationG,
                maxBrakingG: metrics.maxBrakingG,
                maxCorneringSpeed: metrics.maxCorneringSpeed,
                cornerCount: metrics.cornerCount,
                maxAltitude: metrics.maxAltitude,
                altitudeGain: metrics.altitudeGain,
                altitudeLoss: metrics.altitudeLoss,
                bestZeroToHundredSeconds: metrics.bestZeroToHundredSeconds,
                bestSixtyToHundredSeconds: metrics.bestSixtyToHundredSeconds,
              );

              await DriveStorageService.saveDrive(drive);

              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Sürüş başarıyla kaydedildi")),
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

  static Widget _analysisCard(DriveMetrics metrics) {
    String seconds(double? value) =>
        value == null ? 'Ölçülemedi' : '${value.toStringAsFixed(1)} sn';
    String measured(double value, String unit, {int fractionDigits = 1}) =>
        value > 0
        ? '${value.toStringAsFixed(fractionDigits)} $unit'
        : 'Veri yetersiz';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sürüş Analizi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _analysisRow('Sert fren', '${metrics.hardBrakeCount}'),
            _analysisRow('Ani hızlanma', '${metrics.hardAccelerationCount}'),
            _analysisRow(
              'Viraj / keskin dönüş',
              '${metrics.cornerCount} / ${metrics.sharpTurnCount}',
            ),
            _analysisRow(
              'Maksimum ivmelenme',
              measured(metrics.maxAccelerationG, 'G', fractionDigits: 2),
            ),
            _analysisRow(
              'En sert frenleme',
              measured(metrics.maxBrakingG, 'G', fractionDigits: 2),
            ),
            _analysisRow(
              'En yüksek viraj hızı',
              measured(metrics.maxCorneringSpeed, 'km/sa'),
            ),
            _analysisRow(
              'Maksimum rakım',
              metrics.maxAltitude == 0
                  ? 'Veri yetersiz'
                  : '${metrics.maxAltitude.toStringAsFixed(0)} m',
            ),
            _analysisRow(
              'Rakım kazanımı',
              metrics.maxAltitude == 0
                  ? 'Veri yetersiz'
                  : '${metrics.altitudeGain.toStringAsFixed(0)} m',
            ),
            _analysisRow(
              'En hızlı 0–100',
              seconds(metrics.bestZeroToHundredSeconds),
            ),
            _analysisRow(
              'En hızlı 60–100',
              seconds(metrics.bestSixtyToHundredSeconds),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _analysisRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
