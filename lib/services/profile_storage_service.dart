import 'dart:typed_data';

import 'package:hive/hive.dart';

/// Small, independent preferences; no DriveSession or adapter changes.
class ProfileStorageService {
  ProfileStorageService(this._box);

  static const boxName = 'profile';
  static const maximumNameLength = 40;
  static const maximumPhotoBytes = 2 * 1024 * 1024;
  static const _nameKey = 'display_name';
  static const _photoKey = 'avatar_bytes';
  final Box<dynamic> _box;

  static Future<ProfileStorageService> open() async =>
      ProfileStorageService(await Hive.openBox<dynamic>(boxName));

  String? get name {
    final value = _box.get(_nameKey);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Uint8List? get photo {
    final value = _box.get(_photoKey);
    if (value is Uint8List && value.isNotEmpty) return value;
    if (value is List<int> && value.isNotEmpty) return Uint8List.fromList(value);
    return null;
  }

  Future<void> saveName(String input) async {
    final value = input.trim();
    if (value.isEmpty || value.runes.length > maximumNameLength) {
      throw ArgumentError('İsim 1–40 karakter arasında olmalı.');
    }
    await _box.put(_nameKey, value);
  }

  Future<void> savePhoto(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maximumPhotoBytes) {
      throw ArgumentError('Lütfen 2 MB altında bir fotoğraf seç.');
    }
    // Persist bytes, not a gallery/cache path that Android can later remove.
    await _box.put(_photoKey, Uint8List.fromList(bytes));
  }
}
