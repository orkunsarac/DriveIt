import 'package:hive/hive.dart';

import '../models/drive_session.dart';

class DriveStorageService {
  static final Box<DriveSession> _box =
      Hive.box<DriveSession>('drives');

  /// Yeni sürüş kaydet
  static Future<void> saveDrive(DriveSession drive) async {
    await _box.put(drive.id, drive);
  }

  /// Tüm sürüşler
  static List<DriveSession> getAllDrives() {
    return _box.values.toList().reversed.toList();
  }

  /// Sürüş sil
  static Future<void> deleteDrive(String id) async {
    await _box.delete(id);
  }

  /// Tek sürüş getir
  static DriveSession? getDrive(String id) {
    return _box.get(id);
  }
}