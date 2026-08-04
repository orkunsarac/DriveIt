import 'package:hive/hive.dart';

import '../models/drive_session.dart';
import '../models/route_point.dart';

class DriveStorageService {
  static Box<DriveSession> get _box => Hive.box<DriveSession>('drives');
  static Box<dynamic> get _careerBox => Hive.box<dynamic>('career_totals');
  static Box<dynamic> get _symbolicBox => Hive.box<dynamic>('symbolic_routes');
  static Box<dynamic> get _namesBox => Hive.box<dynamic>('drive_names');

  /// Yeni sürüş kaydet
  static Future<void> saveDrive(DriveSession drive) async {
    await _ensureCareerTotals();
    final counted = List<String>.from(
      _careerBox.get('countedIds', defaultValue: <String>[]),
    );
    if (!counted.contains(drive.id)) {
      await _careerBox.put(
        'totalDistance',
        (_careerBox.get('totalDistance', defaultValue: 0.0) as num).toDouble() +
            drive.distance,
      );
      await _careerBox.put(
        'totalDuration',
        (_careerBox.get('totalDuration', defaultValue: 0) as num).toInt() +
            drive.durationSeconds,
      );
      counted.add(drive.id);
      await _careerBox.put('countedIds', counted);
    }
    await _box.put(drive.id, drive);
  }

  static Future<void> _ensureCareerTotals() async {
    if (_careerBox.get('initialized') == true) return;
    final drives = _box.values.toList();
    await _careerBox.put(
      'totalDistance',
      drives.fold<double>(0, (sum, d) => sum + d.distance),
    );
    await _careerBox.put(
      'totalDuration',
      drives.fold<int>(0, (sum, d) => sum + d.durationSeconds),
    );
    await _careerBox.put('countedIds', drives.map((d) => d.id).toList());
    await _careerBox.put('initialized', true);
  }

  static double getCareerDistance() {
    if (!Hive.isBoxOpen('career_totals')) {
      if (!Hive.isBoxOpen('drives')) return 0;
      return _box.values.fold<double>(0, (sum, d) => sum + d.distance);
    }
    if (_careerBox.get('initialized') != true) {
      final drives = _box.values.toList();
      return drives.fold<double>(0, (sum, d) => sum + d.distance);
    }
    return (_careerBox.get('totalDistance', defaultValue: 0.0) as num)
        .toDouble();
  }

  static int getCareerDurationSeconds() {
    if (!Hive.isBoxOpen('career_totals')) {
      if (!Hive.isBoxOpen('drives')) return 0;
      return _box.values.fold<int>(0, (sum, d) => sum + d.durationSeconds);
    }
    if (_careerBox.get('initialized') != true) {
      final drives = _box.values.toList();
      return drives.fold<int>(0, (sum, d) => sum + d.durationSeconds);
    }
    return (_careerBox.get('totalDuration', defaultValue: 0) as num).toInt();
  }

  static List<RoutePoint> getSymbolicRoute(List<DriveSession> drives) {
    if (!Hive.isBoxOpen('symbolic_routes')) {
      return drives.isEmpty ? const <RoutePoint>[] : drives.last.route;
    }
    final stored = _symbolicBox.get('driveit_symbolic_route');
    if (stored is List && stored.isNotEmpty) {
      return stored
          .whereType<Map>()
          .map(
            (p) => RoutePoint(
              latitude: (p['lat'] as num).toDouble(),
              longitude: (p['lng'] as num).toDouble(),
            ),
          )
          .toList();
    }
    if (drives.isEmpty) return const <RoutePoint>[];
    final first = drives.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
    final encoded = first.route
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();
    _symbolicBox.put('driveit_symbolic_route', encoded);
    return first.route;
  }

  /// Tüm sürüşler
  static List<DriveSession> getAllDrives() {
    if (!Hive.isBoxOpen('drives')) return [];
    return _box.values.toList().reversed.toList();
  }

  /// Sürüş sil
  static Future<void> deleteDrive(String id) async {
    await _box.delete(id);
    if (Hive.isBoxOpen('drive_names')) {
      await _namesBox.delete(id);
    }
  }

  /// Tek sürüş getir
  static DriveSession? getDrive(String id) {
    if (!Hive.isBoxOpen('drives')) return null;
    return _box.get(id);
  }

  /// Returns the user-defined title for a drive, or an empty string when the
  /// drive has not been named yet.
  static String getDriveName(String id) {
    if (!Hive.isBoxOpen('drive_names')) return '';
    final value = _namesBox.get(id);
    final name = value is String ? value.trim() : '';
    return name;
  }

  /// Persists only the display name. DriveSession itself is intentionally not
  /// changed so old Hive data remains fully compatible.
  static Future<void> saveDriveName(String id, String name) async {
    if (!Hive.isBoxOpen('drive_names')) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _namesBox.delete(id);
    } else {
      await _namesBox.put(id, trimmed);
    }
  }
}
