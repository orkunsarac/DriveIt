import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_bootstrap.dart';

/// Cloud identity is deliberately separate from the existing local profile.
class DriveItAccountProfile {
  const DriveItAccountProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  factory DriveItAccountProfile.fromRow(
    String id,
    String? email,
    Map<String, dynamic> row,
  ) => DriveItAccountProfile(
    id: row['id']?.toString() ?? id,
    email: email,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarUrl: row['avatar_url'] as String?,
  );
}

enum AccountUsernameStatus { invalid, checking, available, taken, unavailable }

/// Single source for choosing the visible name without ever writing a cloud
/// identity into the local Hive profile.
abstract final class DriveItEffectiveProfile {
  static String? displayName({
    required String? localName,
    required bool hasSession,
    required DriveItAccountProfile? cloudProfile,
    required bool cloudProfileLoaded,
    required bool cloudProfileFailed,
  }) {
    if (!hasSession) return _nonEmpty(localName);
    if (!cloudProfileLoaded || cloudProfileFailed) return null;
    return _nonEmpty(cloudProfile?.displayName) ??
        _usernameLabel(cloudProfile?.username) ??
        'DriveIt kullanıcısı';
  }

  static String? username({
    required String? localUsername,
    required bool hasSession,
    required DriveItAccountProfile? cloudProfile,
    required bool cloudProfileLoaded,
    required bool cloudProfileFailed,
  }) {
    if (!hasSession) return _usernameLabel(localUsername);
    if (!cloudProfileLoaded || cloudProfileFailed) return null;
    return _usernameLabel(cloudProfile?.username);
  }

  static String? _usernameLabel(String? value) {
    final username = _nonEmpty(value)?.replaceFirst(RegExp(r'^@+'), '');
    return username == null ? null : '@$username';
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

abstract interface class DriveItAccountGateway {
  bool get isAvailable;
  bool get hasSession;
  String? get currentDisplayName;
  Stream<dynamic> get authStateChanges;
  Future<bool> isUsernameAvailable(String username);
  Future<bool> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> resetPasswordForEmail(String email);
  Future<DriveItAccountProfile?> fetchCurrentProfile();
  Future<DriveItAccountProfile> updateDisplayName(String displayName);
  Future<DriveItAccountProfile> updateUsername(String username);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

abstract final class AccountUsernameAvailability {
  static AccountUsernameStatus resolve({
    required String username,
    bool checking = false,
    bool? available,
    bool checkFailed = false,
  }) {
    if (AccountInputRules.validateUsername(username) != null) {
      return AccountUsernameStatus.invalid;
    }
    if (checkFailed) return AccountUsernameStatus.unavailable;
    if (checking || available == null) return AccountUsernameStatus.checking;
    return available
        ? AccountUsernameStatus.available
        : AccountUsernameStatus.taken;
  }
}

class SupabaseAccountService extends ChangeNotifier
    implements DriveItAccountGateway {
  SupabaseAccountService._();

  static final instance = SupabaseAccountService._();

  StreamSubscription<AuthState>? _identitySubscription;
  DriveItAccountProfile? _profile;
  bool _profileLoaded = false;
  bool _profileLoading = false;
  bool _profileFailed = false;
  String? _profileError;
  int _profileRequest = 0;
  Future<DriveItAccountProfile?>? _profileLoadFuture;

  DriveItAccountProfile? get profile => _profile;
  bool get profileLoaded => _profileLoaded;
  bool get profileLoading => _profileLoading;
  bool get profileFailed => _profileFailed;
  String? get profileError => _profileError;

  /// Start observing the restored persisted session before the first screen
  /// renders. A failed profile read remains visible as an error state.
  void startIdentitySync() {
    final client = _client;
    if (client == null || _identitySubscription != null) return;
    _identitySubscription = client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _clearCloudIdentity();
      } else {
        unawaited(_refreshProfileQuietly());
      }
    });
    if (client.auth.currentSession != null) {
      unawaited(_refreshProfileQuietly());
    } else {
      _clearCloudIdentity();
    }
  }

  Future<void> _refreshProfileQuietly() async {
    try {
      await fetchCurrentProfile();
    } catch (_) {
      // The failure is retained in profileFailed/profileError for the UI.
    }
  }

  String? effectiveDisplayName({required String? localName}) =>
      DriveItEffectiveProfile.displayName(
        localName: localName,
        hasSession: hasSession,
        cloudProfile: _profile,
        cloudProfileLoaded: _profileLoaded,
        cloudProfileFailed: _profileFailed,
      );

  String? effectiveUsername({required String? localUsername}) =>
      DriveItEffectiveProfile.username(
        localUsername: localUsername,
        hasSession: hasSession,
        cloudProfile: _profile,
        cloudProfileLoaded: _profileLoaded,
        cloudProfileFailed: _profileFailed,
      );

  void _clearCloudIdentity() {
    _profileRequest++;
    _profile = null;
    _profileLoaded = false;
    _profileLoading = false;
    _profileFailed = false;
    _profileError = null;
    notifyListeners();
  }

  void _setProfileFailure(String message, int request) {
    if (request != _profileRequest) return;
    _profile = null;
    _profileLoaded = true;
    _profileLoading = false;
    _profileFailed = true;
    _profileError = message;
    notifyListeners();
  }

  SupabaseClient? get _client =>
      SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;

  @override
  bool get isAvailable => _client != null;
  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;
  @override
  bool get hasSession => currentSession != null;
  @override
  String? get currentDisplayName =>
      currentUser?.userMetadata?['display_name']?.toString();
  @override
  Stream<dynamic> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream<dynamic>.empty();

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    final result = await client.rpc(
      'is_username_available',
      params: {'candidate': username},
    );
    if (result is bool) return result;
    throw const AccountServiceException.unavailable();
  }

  @override
  Future<bool> signUp({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    try {
      final result = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username, 'display_name': displayName.trim()},
      );
      final sessionCreated = result.session != null;
      if (sessionCreated) {
        // Auth signup remains successful even if profile propagation is
        // momentarily delayed by the database trigger.
        try {
          await fetchCurrentProfile();
        } catch (_) {}
      }
      return sessionCreated;
    } on AuthException catch (error) {
      throw AccountServiceException.fromAuth(error);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    try {
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      // Login/session should not be discarded if profile propagation is
      // temporarily delayed by the database trigger.
      try {
        await fetchCurrentProfile();
      } catch (_) {}
    } on AuthException catch (error) {
      throw AccountServiceException.fromAuth(error);
    }
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    await client.auth.signOut();
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    try {
      await client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw AccountServiceException.fromAuth(error);
    }
  }

  @override
  Future<DriveItAccountProfile> updateDisplayName(String displayName) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw const AccountServiceException.unavailable();
    }
    final normalized = displayName.trim();
    final validation = AccountInputRules.validateDisplayName(normalized);
    if (validation != null) throw AccountServiceException(validation);
    try {
      final row = await client
          .from('profiles')
          .update({'display_name': normalized})
          .eq('id', user.id)
          .select('id, username, display_name, avatar_url')
          .maybeSingle();
      if (row == null) throw const AccountServiceException.profileUnavailable();
      final profile = DriveItAccountProfile.fromRow(user.id, user.email, row);
      _publishCloudProfile(profile);
      return profile;
    } on PostgrestException catch (error) {
      throw AccountServiceException.fromPostgrest(error);
    }
  }

  @override
  Future<DriveItAccountProfile> updateUsername(String username) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw const AccountServiceException.unavailable();
    }
    final normalized = AccountInputRules.normalizeUsername(username);
    final validation = AccountInputRules.validateUsername(normalized);
    if (validation != null) throw AccountServiceException(validation);
    final current = _profile ?? await fetchCurrentProfile();
    if (current?.username?.trim().toLowerCase() == normalized) {
      if (current == null) {
        throw const AccountServiceException.profileUnavailable();
      }
      return current;
    }
    try {
      final row = await client
          .from('profiles')
          .update({'username': normalized})
          .eq('id', user.id)
          .select('id, username, display_name, avatar_url')
          .maybeSingle();
      if (row == null) throw const AccountServiceException.profileUnavailable();
      final profile = DriveItAccountProfile.fromRow(user.id, user.email, row);
      _publishCloudProfile(profile);
      return profile;
    } on PostgrestException catch (error) {
      throw AccountServiceException.fromPostgrest(error, usernameUpdate: true);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw const AccountServiceException.unavailable();
    }
    if (currentPassword.isEmpty) {
      throw const AccountServiceException('Mevcut şifreni yaz.');
    }
    final validation = AccountInputRules.validatePassword(newPassword);
    if (validation != null) throw AccountServiceException(validation);
    final email = user.email;
    if (email == null || email.trim().isEmpty) {
      throw const AccountServiceException(
        'Hesap e-postası bulunamadığı için şifre değiştirilemiyor.',
      );
    }
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (response.user?.id != user.id) {
        throw const AccountServiceException('Mevcut şifren yanlış.');
      }
    } on AuthException catch (error) {
      final text = error.message.toLowerCase();
      if (text.contains('invalid login') ||
          text.contains('invalid credentials') ||
          text.contains('invalid_grant')) {
        throw const AccountServiceException('Mevcut şifren yanlış.');
      }
      throw AccountServiceException.fromAuth(error);
    }
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AccountServiceException.fromAuth(error);
    }
  }

  @override
  Future<DriveItAccountProfile?> fetchCurrentProfile() {
    final inFlight = _profileLoadFuture;
    if (inFlight != null) return inFlight;
    final future = _fetchCurrentProfile();
    _profileLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_profileLoadFuture, future)) _profileLoadFuture = null;
    });
  }

  Future<DriveItAccountProfile?> _fetchCurrentProfile() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final request = ++_profileRequest;
    _profileLoading = true;
    _profileFailed = false;
    _profileError = null;
    notifyListeners();
    try {
      final row = await client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (request != _profileRequest) return _profile;
      if (row == null) {
        _setProfileFailure(
          'Hesap profili bulunamadı. Biraz sonra yeniden deneyebilirsin.',
          request,
        );
        return null;
      }
      final profile = DriveItAccountProfile.fromRow(user.id, user.email, row);
      _publishCloudProfile(profile);
      return profile;
    } on PostgrestException {
      _setProfileFailure(
        'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.',
        request,
      );
      throw const AccountServiceException.profileUnavailable();
    } catch (_) {
      _setProfileFailure(
        'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.',
        request,
      );
      rethrow;
    }
  }

  void _publishCloudProfile(DriveItAccountProfile profile) {
    _profileRequest++;
    _profile = profile;
    _profileLoaded = true;
    _profileLoading = false;
    _profileFailed = false;
    _profileError = null;
    notifyListeners();
  }
}

class AccountServiceException implements Exception {
  const AccountServiceException(this.message);

  const AccountServiceException.unavailable()
    : message = 'Çevrimiçi hesap hizmeti şu anda kullanılamıyor.';

  const AccountServiceException.profileUnavailable()
    : message = 'Hesap bilgileri şu anda alınamıyor. Tekrar deneyebilirsin.';

  const AccountServiceException.usernameTaken()
    : message = 'Bu kullanıcı adı kullanımda. Başka bir ad deneyebilirsin.';

  const AccountServiceException.profileUpdateFailed()
    : message = 'Profil bilgileri kaydedilemedi. Tekrar deneyebilirsin.';

  factory AccountServiceException.fromPostgrest(
    PostgrestException error, {
    bool usernameUpdate = false,
  }) {
    final text = error.message.toLowerCase();
    if (usernameUpdate &&
        (error.code == '23505' ||
            text.contains('duplicate key') ||
            text.contains('unique constraint'))) {
      return const AccountServiceException.usernameTaken();
    }
    return const AccountServiceException.profileUpdateFailed();
  }

  factory AccountServiceException.fromAuth(AuthException error) {
    final text = error.message.toLowerCase();
    if (text.contains('email not confirmed') ||
        text.contains('not confirmed')) {
      return const AccountServiceException(
        'Giriş yapmadan önce e-posta doğrulama bağlantısına tıkla.',
      );
    }
    if (text.contains('invalid login') ||
        text.contains('invalid credentials')) {
      return const AccountServiceException('E-posta veya şifre hatalı.');
    }
    if (text.contains('already registered') ||
        text.contains('already exists')) {
      return const AccountServiceException(
        'Bu e-posta ile daha önce hesap oluşturulmuş.',
      );
    }
    if (text.contains('password')) {
      return const AccountServiceException('Şifre şartlarını kontrol et.');
    }
    if (text.contains('email')) {
      return const AccountServiceException('E-posta adresini kontrol et.');
    }
    return const AccountServiceException(
      'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.',
    );
  }

  final String message;

  @override
  String toString() => message;
}

abstract final class AccountInputRules {
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String? validateUsername(String value) {
    final normalized = normalizeUsername(value);
    if (normalized.length < 3 || normalized.length > 20) {
      return 'Kullanıcı adı 3–20 karakter olmalı.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(normalized)) {
      return 'Yalnızca a-z, 0-9 ve _ kullanabilirsin.';
    }
    return null;
  }

  static String? validateDisplayName(String value) {
    final length = value.trim().runes.length;
    if (length < 2 || length > 40) return 'İsim 2–40 karakter olmalı.';
    return null;
  }

  static String? validateEmail(String value) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Geçerli bir e-posta adresi yaz.';
    }
    return null;
  }

  static String? validatePassword(String value) =>
      value.length < 8 ? 'Şifre en az 8 karakter olmalı.' : null;

  static String? validateCurrentPassword(String value) =>
      value.isEmpty ? 'Mevcut şifreni yaz.' : null;

  static String? validatePasswordConfirmation(String password, String repeat) =>
      password != repeat ? 'Şifreler eşleşmiyor.' : null;
}
