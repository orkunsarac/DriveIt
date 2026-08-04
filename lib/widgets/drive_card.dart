import 'package:flutter/material.dart';

import '../models/drive_session.dart';
import 'route_preview.dart';

class DriveCard extends StatelessWidget {
  final DriveSession drive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DriveCard({
    super.key,
    required this.drive,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "${hours}s ${minutes}dk";
    }

    return "${minutes}dk ${secs}sn";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: drive.id,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: RoutePreview(
                  route: drive.route,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${drive.date.day}.${drive.date.month}.${drive.date.year}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      )
                    ],
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.route,
                          label: "Mesafe",
                          value:
                              "${(drive.distance / 1000).toStringAsFixed(2)} km",
                        ),
                      ),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.timer,
                          label: "Süre",
                          value: _formatDuration(
                            drive.durationSeconds,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.speed,
                          label: "Ort. Hız",
                          value:
                              "${drive.averageSpeed.toStringAsFixed(1)} km/h",
                        ),
                      ),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.flash_on,
                          label: "Maks.",
                          value:
                              "${drive.maxSpeed.toStringAsFixed(1)} km/h",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.pause_circle_outline,
                          label: 'Duruş Sayısı',
                          value: '${drive.stopCount}',
                        ),
                      ),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.hourglass_bottom,
                          label: 'Bekleme Süresi',
                          value: '${drive.stoppedSeconds} sn',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
