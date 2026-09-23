import 'dart:typed_data';

import 'package:hive/hive.dart';

/// Small, independent preferences; no DriveSession or adapter changes.
class ProfileStorageService {
  ProfileStorageService(this._box);

  static const boxName = 'profile';
  static const maximumNameLength = 40;
  static const maximumPhotoBytes = 2 * 1024 * 1024;
  static const _nameKey = 'display_name';
  static const _usernameKey = 'username';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _onboardingCompletedAtKey = 'onboarding_completed_at';
  static const _homeTourCompletedKey = 'home_tour_completed';
  static const _photoKey = 'avatar_bytes';
  final Box<dynamic> _box;

  static Future<ProfileStorageService> open() async =>
      ProfileStorageService(await Hive.openBox<dynamic>(boxName));

  String? get name {
    final value = _box.get(_nameKey);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  String? get username {
    final value = _box.get(_usernameKey);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  bool get onboardingCompleted =>
      _box.get(_onboardingCompletedKey, defaultValue: false) == true;

  DateTime? get onboardingCompletedAt {
    final value = _box.get(_onboardingCompletedAtKey);
    return value is String ? DateTime.tryParse(value) : null;
  }

  bool get hasCompleteProfile => name != null && username != null;

  bool get homeTourCompleted =>
      _box.get(_homeTourCompletedKey, defaultValue: false) == true;

  Uint8List? get photo {
    final value = _box.get(_photoKey);
    if (value is Uint8List && value.isNotEmpty) return value;
    if (value is List<int> && value.isNotEmpty) {
      return Uint8List.fromList(value);
    }
    return null;
  }

  Future<void> saveName(String input) async {
    final value = input.trim();
    if (value.isEmpty || value.runes.length > maximumNameLength) {
      throw ArgumentError('İsim 1–40 karakter arasında olmalı.');
    }
    await _box.put(_nameKey, value);
  }

  Future<void> saveProfile({
    required String displayName,
    required String username,
  }) async {
    final normalizedName = displayName.trim();
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedName.runes.length < 2 ||
        normalizedName.runes.length > maximumNameLength) {
      throw ArgumentError('İsim 2–40 karakter arasında olmalı.');
    }
    if (!RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(normalizedUsername)) {
      throw ArgumentError(
        'Kullanıcı adı 3–20 karakter olmalı; yalnızca harf, rakam, _ ve . içerebilir.',
      );
    }
    await _box.putAll(<String, dynamic>{
      _nameKey: normalizedName,
      _usernameKey: normalizedUsername,
    });
  }

  Future<void> markOnboardingCompleted({DateTime? completedAt}) async {
    final timestamp = (completedAt ?? DateTime.now()).toUtc();
    await _box.putAll(<String, dynamic>{
      _onboardingCompletedKey: true,
      _onboardingCompletedAtKey: timestamp.toIso8601String(),
    });
  }

  Future<void> markHomeTourCompleted() async {
    await _box.put(_homeTourCompletedKey, true);
  }

  Future<void> savePhoto(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maximumPhotoBytes) {
      throw ArgumentError('Lütfen 2 MB altında bir fotoğraf seç.');
    }
    // Persist bytes, not a gallery/cache path that Android can later remove.
    await _box.put(_photoKey, Uint8List.fromList(bytes));
  }
}
