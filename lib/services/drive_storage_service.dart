import 'package:hive/hive.dart';

import '../models/drive_session.dart';

class DriveStorageService {
  static Box<DriveSession> get _box => Hive.box<DriveSession>('drives');

  /// Yeni sürüş kaydet
  static Future<void> saveDrive(DriveSession drive) async {
    await _box.put(drive.id, drive);
  }

  /// Tüm sürüşler
  static List<DriveSession> getAllDrives() {
    if (!Hive.isBoxOpen('drives')) return [];
    return _box.values.toList().reversed.toList();
  }

  /// Sürüş sil
  static Future<void> deleteDrive(String id) async {
    await _box.delete(id);
  }

  /// Tek sürüş getir
  static DriveSession? getDrive(String id) {
    if (!Hive.isBoxOpen('drives')) return null;
    return _box.get(id);
  }
}
