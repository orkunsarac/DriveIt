import 'dart:typed_data';
import 'local_owner_lifecycle.dart';
import 'profile_storage_service.dart';
import '../features/my_world/services/my_world_settings_service.dart';

/// No Box or Auth fallback; every access checks the revocable lease.
class OwnerProfileStore implements LocalProfileStore {
  OwnerProfileStore(this.lease);
  final LocalOwnerLease lease;
  String? _text(String key) {
    final value = lease.read<String>('profile', key);
    return value?.trim().isNotEmpty == true ? value : null;
  }

  @override
  String? get name => _text('display_name');
  @override
  String? get username => _text('username');
  @override
  Uint8List? get photo {
    final value = lease.read<Object>('profile', 'avatar_bytes');
    return value is List<int> && value.isNotEmpty
        ? Uint8List.fromList(value)
        : null;
  }

  @override
  bool get onboardingCompleted =>
      lease.read('profile', 'onboarding_completed') == true;
  @override
  bool get homeTourCompleted =>
      lease.read('profile', 'home_tour_completed') == true;
  @override
  Future<void> saveName(String input) {
    final value = input.trim();
    if (value.isEmpty ||
        value.runes.length > ProfileStorageService.maximumNameLength) {
      throw ArgumentError('İsim 1–40 karakter arasında olmalı.');
    }
    return lease.put('profile', 'display_name', value);
  }

  @override
  Future<void> savePhoto(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > ProfileStorageService.maximumPhotoBytes) {
      throw ArgumentError('Lütfen 2 MB altında bir fotoğraf seç.');
    }
    return lease.put('profile', 'avatar_bytes', Uint8List.fromList(bytes));
  }

  @override
  Future<void> markHomeTourCompleted() =>
      lease.put('profile', 'home_tour_completed', true);
}

class OwnerWorldSettings implements MyWorldSettingsStore {
  OwnerWorldSettings(this.lease);
  final LocalOwnerLease lease;
  @override
  bool get skipIntroAnimation =>
      lease.read('my_world_settings', 'skip_intro_animation') == true;
  @override
  Future<void> setSkipIntroAnimation(bool value) =>
      lease.put('my_world_settings', 'skip_intro_animation', value);
}
