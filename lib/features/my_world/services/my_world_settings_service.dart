import 'package:hive/hive.dart';

abstract interface class MyWorldSettingsStore {
  bool get skipIntroAnimation;
  Future<void> setSkipIntroAnimation(bool value);
}

class HiveMyWorldSettingsStore implements MyWorldSettingsStore {
  const HiveMyWorldSettingsStore();

  static const boxName = 'my_world_settings';
  static const _skipIntroKey = 'skip_intro_animation';

  static Future<void> openBox(HiveInterface hive) =>
      hive.openBox<dynamic>(boxName);

  Box<dynamic>? get _box =>
      Hive.isBoxOpen(boxName) ? Hive.box<dynamic>(boxName) : null;

  @override
  bool get skipIntroAnimation =>
      _box?.get(_skipIntroKey, defaultValue: false) == true;

  @override
  Future<void> setSkipIntroAnimation(bool value) async {
    final box = _box;
    if (box == null) return;
    await box.put(_skipIntroKey, value);
  }
}

class MemoryMyWorldSettingsStore implements MyWorldSettingsStore {
  factory MemoryMyWorldSettingsStore({bool skipIntroAnimation = false}) {
    return MemoryMyWorldSettingsStore._(skipIntroAnimation);
  }

  MemoryMyWorldSettingsStore._(this._skipIntroAnimation);

  bool _skipIntroAnimation;

  @override
  bool get skipIntroAnimation => _skipIntroAnimation;

  @override
  Future<void> setSkipIntroAnimation(bool value) async {
    _skipIntroAnimation = value;
  }
}
