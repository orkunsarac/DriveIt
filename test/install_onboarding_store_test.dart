import 'package:driveit_project/services/install_onboarding_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _MemoryBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _values = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _values[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _values[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _values.addAll(entries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('reads legacy completion and writes install-wide completion', () async {
    final appPreferences = _MemoryBox();
    final legacyProfile = _MemoryBox();
    final store = InstallOnboardingStore(
      appPreferences: appPreferences,
      legacyProfile: legacyProfile,
    );

    expect(store.isCompleted, isFalse);
    await legacyProfile.put('onboarding_completed', true);
    expect(store.isCompleted, isTrue);

    await legacyProfile.put('onboarding_completed', false);
    expect(store.isCompleted, isFalse);
    await store.markCompleted(completedAt: DateTime.utc(2026, 10, 25));
    expect(store.isCompleted, isTrue);
    expect(appPreferences.get('onboarding_completed_at'), isA<String>());
    expect(legacyProfile.get('onboarding_completed'), isFalse);
    expect(
      InstallOnboardingStore(
        appPreferences: appPreferences,
        legacyProfile: legacyProfile,
      ).isCompleted,
      isTrue,
    );
  });
}
