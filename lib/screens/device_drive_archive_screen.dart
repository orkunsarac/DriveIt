import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/drive_session.dart';
import '../models/route_point.dart';
import '../services/device_drive_archive.dart';
import '../widgets/neon_route_preview.dart';

class DeviceDriveArchiveScreen extends StatefulWidget {
  const DeviceDriveArchiveScreen({super.key, required this.archive});
  final DeviceDriveArchiveContext archive;
  @override
  State<DeviceDriveArchiveScreen> createState() =>
      _DeviceDriveArchiveScreenState();
}

class _DeviceDriveArchiveScreenState extends State<DeviceDriveArchiveScreen> {
  @override
  void dispose() {
    widget.archive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ArchiveBoundary(
    archive: widget.archive,
    builder: () => Scaffold(
      appBar: AppBar(title: const Text('Cihazdaki Eski Sürüşler')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cihaz arşivi • Salt okunur • Hiçbir hesaba aktarılmaz',
            ),
          ),
          for (final drive in widget.archive.drives())
            ListTile(
              title: Text(_date(drive.date)),
              subtitle: Text(_summary(drive)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceDriveArchiveDetailScreen(
                    archive: widget.archive,
                    driveId: drive.id,
                  ),
                ),
              ),
            ),
          if (widget.archive.drives().isEmpty)
            const ListTile(title: Text('Kayıtlı eski sürüş yok')),
        ],
      ),
    ),
  );
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.${date.year} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _summary(DriveSession drive) =>
    '${(drive.distance / 1000).toStringAsFixed(2)} km • ${drive.durationSeconds} sn';

/// Intentionally not the mutable normal detail screen: no profile, score
/// calculation, poster, publication, rebuild or storage service is invoked.
class DeviceDriveArchiveDetailScreen extends StatelessWidget {
  const DeviceDriveArchiveDetailScreen({
    super.key,
    required this.archive,
    required this.driveId,
  });
  final DeviceDriveArchiveContext archive;
  final String driveId;
  @override
  Widget build(BuildContext context) => _ArchiveBoundary(
    archive: archive,
    builder: () {
      final drive = archive.drive(driveId);
      return Scaffold(
        appBar: AppBar(title: const Text('Eski Sürüş Detayı')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Sürüş tarihi: ${_date(drive.date)}'),
            Text(_summary(drive)),
            Text('Ortalama hız: ${drive.averageSpeed} km/sa'),
            Text('Maksimum hız: ${drive.maxSpeed} km/sa'),
            const Text('Kayıt tarihi gerçek bitiş zamanı olarak yorumlanmaz.'),
            SizedBox(height: 220, child: NeonRoutePreview(route: drive.route)),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeviceDriveArchiveMapScreen(
                    archive: archive,
                    driveId: driveId,
                  ),
                ),
              ),
              child: const Text('GPS Rota Haritası'),
            ),
          ],
        ),
      );
    },
  );
}

class DeviceDriveArchiveMapScreen extends StatelessWidget {
  const DeviceDriveArchiveMapScreen({
    super.key,
    required this.archive,
    required this.driveId,
  });
  final DeviceDriveArchiveContext archive;
  final String driveId;
  @override
  Widget build(BuildContext context) => _ArchiveBoundary(
    archive: archive,
    builder: () {
      final route = archive.drive(driveId).route;
      return Scaffold(
        appBar: AppBar(title: const Text('GPS Rota Haritası')),
        body: route.isEmpty
            ? const Center(child: Text('Kayıtlı GPS rotası yok'))
            : GoogleMap(
                key: ValueKey('device-archive-map-$driveId'),
                initialCameraPosition: CameraPosition(
                  target: LatLng(route.first.latitude, route.first.longitude),
                  zoom: 12,
                ),
                polylines: {
                  for (final entry in routeSegments(route).asMap().entries)
                    Polyline(
                      polylineId: PolylineId('archive-${entry.key}'),
                      color: const Color(0xff42b4ff),
                      width: 5,
                      points: entry.value
                          .map((p) => LatLng(p.latitude, p.longitude))
                          .toList(),
                    ),
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('start'),
                    position: LatLng(
                      route.first.latitude,
                      route.first.longitude,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('end'),
                    position: LatLng(route.last.latitude, route.last.longitude),
                  ),
                },
                myLocationButtonEnabled: false,
              ),
      );
    },
  );
}

class _ArchiveBoundary extends StatelessWidget {
  const _ArchiveBoundary({required this.archive, required this.builder});
  final DeviceDriveArchiveContext archive;
  final Widget Function() builder;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: archive,
    builder: (_, _) => archive.isCurrent
        ? builder()
        : const Scaffold(
            body: Center(
              child: Text(
                'Arşiv erişimi sona erdi. Yeniden doğrulama gerekli.',
              ),
            ),
          ),
  );
}
