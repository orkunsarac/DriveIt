import 'package:hive_flutter/hive_flutter.dart';

/// Installation-wide onboarding state, separate from owner-scoped profile data.
/// The legacy profile completion bit is read only for upgrade compatibility.
class InstallOnboardingStore {
  InstallOnboardingStore({
    required this._appPreferences,
    required this._legacyProfile,
  });

  static const _appPreferencesBoxName = 'app_preferences';
  static const _legacyProfileBoxName = 'profile';
  static const _completedKey = 'onboarding_completed';
  static const _legacyCompletedKey = 'onboarding_completed';

  final Box<dynamic> _appPreferences;
  final Box<dynamic> _legacyProfile;

  static Future<InstallOnboardingStore> open() async {
    if (!Hive.isBoxOpen(_appPreferencesBoxName) &&
        !Hive.isBoxOpen(_legacyProfileBoxName)) {
      await Hive.initFlutter();
    }
    final appPreferences = Hive.isBoxOpen(_appPreferencesBoxName)
        ? Hive.box<dynamic>(_appPreferencesBoxName)
        : await Hive.openBox<dynamic>(_appPreferencesBoxName);
    final legacyProfile = Hive.isBoxOpen(_legacyProfileBoxName)
        ? Hive.box<dynamic>(_legacyProfileBoxName)
        : await Hive.openBox<dynamic>(_legacyProfileBoxName);
    return InstallOnboardingStore(
      appPreferences: appPreferences,
      legacyProfile: legacyProfile,
    );
  }

  bool get isCompleted =>
      _appPreferences.get(_completedKey) == true ||
      _legacyProfile.get(_legacyCompletedKey) == true;

  Future<void> markCompleted({DateTime? completedAt}) async {
    await _appPreferences.putAll(<String, dynamic>{
      _completedKey: true,
      'onboarding_completed_at': (completedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
    });
  }
}
