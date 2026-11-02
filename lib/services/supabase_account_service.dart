import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/local_ownership_gate.dart';
import '../config/play_auth_runtime_policy.dart';
import '../config/driveit_auth_callback.dart';
import '../config/supabase_bootstrap.dart';
import 'local_owner_lifecycle.dart';
import 'gps_session_ownership.dart';
import 'owner_profile_gateway.dart';

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
  Future<void> completePasswordRecovery(String newPassword);
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

  @visibleForTesting
  SupabaseAccountService.forTesting(this._testClient, this._testGateway);
  SupabaseClient? _testClient;
  OwnerProfileGateway? _testGateway;
  int? _profileEpoch;

  bool get _requiresScopedProfile =>
      _testGateway != null || SupabaseBootstrap.isPlayPackage;

  OwnerProfileGateway _profileGateway(SupabaseClient client) {
    final injected = _testGateway;
    if (injected != null) return injected;
    final owner = _controlledOwner;
    if (owner == null) throw StateError('Owner context unavailable');
    return OwnerProfileGateway(
      authClient: client,
      url: SupabaseConfig.url,
      publicKey: SupabaseConfig.publishableKey,
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => owner.lease.owner.userId,
      approvedEpoch: () => owner.epoch,
      isLeaseCurrent: (epoch) {
        try {
          return owner.lease.epoch == epoch && owner.lease.isCurrent;
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<T> _profileOperation<T>(
    SupabaseClient client,
    Future<T> Function(SupabaseClient, String) operation,
  ) {
    if (_requiresScopedProfile) return _profileGateway(client).run(operation);
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Session unavailable');
    return operation(client, uid);
  }

  bool _profileIsVisible() {
    if (!_requiresScopedProfile) return true;
    try {
      final owner =
          _testGateway?.approvedOwner() ?? _controlledOwner?.lease.owner.userId;
      final epoch = _testGateway?.approvedEpoch() ?? _controlledOwner?.epoch;
      if (epoch == null ||
          !(_testGateway?.isLeaseCurrent(epoch) ??
              (_controlledOwner?.lease.isCurrent ?? false))) {
        return false;
      }
      return owner != null &&
          _client?.auth.currentUser?.id == owner &&
          (_profile == null ||
              (_profile!.id == owner &&
                  _profileEpoch ==
                      (_testGateway?.approvedEpoch() ??
                          _controlledOwner?.epoch)));
    } catch (_) {
      return false;
    }
  }

  (String?, String?, int?) _profileContext() => (
    _client?.auth.currentUser?.id,
    _client?.auth.currentSession?.accessToken,
    _testGateway?.approvedEpoch() ?? _controlledOwner?.epoch,
  );

  void _requireProfileContext((String?, String?, int?) captured) {
    if (!_requiresScopedProfile) return;
    final client = _client;
    if (client == null) throw StateError('Owner context revoked');
    final gateway = _profileGateway(client);
    if (captured != _profileContext() ||
        captured.$1 == null ||
        captured.$1 != gateway.approvedOwner() ||
        captured.$3 == null ||
        !gateway.isLeaseCurrent(captured.$3!)) {
      throw StateError('Owner context revoked');
    }
  }

  static final instance = SupabaseAccountService._();
  LocalOwnerLifecycle? _controlledOwner;

  /// Planet readers pin the approved lease; they never follow a new account.
  OwnerProfileGateway requirePlanetReadGateway() {
    final client = _client;
    final lease = _controlledOwner?.lease;
    if (!SupabaseBootstrap.isPlayPackage || client == null || lease == null) {
      throw StateError('Planet owner context unavailable');
    }
    lease.requireCurrent();
    return OwnerProfileGateway(
      authClient: client,
      url: SupabaseConfig.url,
      publicKey: SupabaseConfig.publishableKey,
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => lease.owner.userId,
      approvedEpoch: () => lease.epoch,
      isLeaseCurrent: (epoch) => epoch == lease.epoch && lease.isCurrent,
    );
  }

  /// Planet writes are bound to the exact screen lease that proved the drive
  /// and telemetry are in the current account's private store. The public
  /// Play Auth gate still controls whether this can be constructed at runtime.
  OwnerProfileGateway requirePlanetPublicationGateway({
    required LocalOwnerLease lease,
  }) {
    final client = _client;
    final owner = _controlledOwner;
    if (!SupabaseBootstrap.isPlayPackage ||
        client == null ||
        owner == null ||
        !identical(owner.lease, lease) ||
        lease.owner.kind != GpsOwnerKind.account ||
        lease.owner.userId == null) {
      throw StateError('Planet publication owner context unavailable');
    }
    lease.requireCurrent();
    return OwnerProfileGateway(
      authClient: client,
      url: SupabaseConfig.url,
      publicKey: SupabaseConfig.publishableKey,
      applicationId: 'com.osaracx.driveit',
      approvedOwner: () => lease.owner.userId,
      approvedEpoch: () => lease.epoch,
      isLeaseCurrent: (epoch) => epoch == lease.epoch && lease.isCurrent,
    );
  }

  int? _observedOwnerEpoch;
  LocalOwnerState? _observedOwnerState;

  void _onOwnerStateChanged() {
    final owner = _controlledOwner;
    if (!_requiresScopedProfile ||
        owner == null ||
        _identitySubscription == null) {
      return;
    }
    if (_observedOwnerEpoch == owner.epoch &&
        _observedOwnerState == owner.state) {
      return;
    }
    _observedOwnerEpoch = owner.epoch;
    _observedOwnerState = owner.state;
    if (owner.state != LocalOwnerState.ready) {
      _clearCloudIdentity();
    } else if (_profileIsVisible() && _client?.auth.currentUser != null) {
      unawaited(_refreshProfileQuietly());
    }
  }

  /// Same public Auth entry points, fenced only in an explicit debug harness.
  void attachOwnerForTesting(LocalOwnerLifecycle owner) {
    if (!LocalOwnershipGate.syntheticRuntimeAvailable ||
        !owner.gate.enabled ||
        _controlledOwner != null) {
      throw StateError('Controlled Auth owner unavailable');
    }
    _controlledOwner = owner;
    owner.addListener(_onOwnerStateChanged);
  }

  /// Fences real account switches against active local GPS operations in the
  /// explicitly activated normal-app composition. No fake Auth is accepted.
  void attachOwnerForProduction(LocalOwnerLifecycle owner) {
    if (!LocalOwnershipGate.localProductionActivation ||
        !owner.gate.enabled ||
        _controlledOwner != null) {
      throw StateError('Production Auth owner unavailable');
    }
    _controlledOwner = owner;
    owner.addListener(_onOwnerStateChanged);
  }

  void detachOwnerForTesting(LocalOwnerLifecycle owner) {
    if (!identical(_controlledOwner, owner)) {
      throw StateError('Auth owner conflict');
    }
    owner.removeListener(_onOwnerStateChanged);
    _controlledOwner = null;
    _observedOwnerEpoch = null;
    _observedOwnerState = null;
  }

  void detachOwnerForProduction(LocalOwnerLifecycle owner) {
    if (!LocalOwnershipGate.localProductionActivation ||
        !identical(_controlledOwner, owner)) {
      throw StateError('Production Auth owner conflict');
    }
    owner.removeListener(_onOwnerStateChanged);
    _controlledOwner = null;
    _observedOwnerEpoch = null;
    _observedOwnerState = null;
  }

  Future<T> _identityChange<T>(Future<T> Function() action) {
    if (!PlayAuthRuntimePolicy.permitsIdentityChange(
      isPlay: SupabaseBootstrap.isPlayPackage,
      ownerBound: _controlledOwner != null,
    )) {
      throw StateError('Play Auth owner runtime unavailable');
    }
    return _controlledOwner?.authorizeIdentityChange(action) ?? action();
  }

  /// Account deletion must never fall back to an unfenced legacy/GPS composition.
  Future<void> authorizeAccountDeletion(Future<void> Function() action) async {
    final owner = _controlledOwner;
    if (owner == null || !owner.gate.enabled) {
      throw StateError('Safe account deletion owner runtime unavailable');
    }
    await owner.authorizeIdentityChange(action);
  }

  StreamSubscription<AuthState>? _identitySubscription;
  DriveItAccountProfile? _profile;
  bool _profileLoaded = false;
  bool _profileLoading = false;
  bool _profileFailed = false;
  String? _profileError;
  int _profileRequest = 0;
  Future<DriveItAccountProfile?>? _profileLoadFuture;
  (String?, String?, int?)? _profileLoadContext;

  DriveItAccountProfile? get profile => _profileIsVisible() ? _profile : null;
  bool get profileLoaded => _profileIsVisible() && _profileLoaded;
  bool get profileLoading => _profileLoading;
  bool get profileFailed => _profileFailed;
  String? get profileError => _profileError;

  /// Start observing the restored persisted session before the first screen
  /// renders. A failed profile read remains visible as an error state.
  void startIdentitySync() {
    final client = _client;
    if (client == null || _identitySubscription != null) return;
    _identitySubscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session == null) {
          _clearCloudIdentity();
        } else {
          // Auth changes can arrive before the replacement profile request
          // completes. Drop the previous account's name immediately so no
          // screen can briefly render it under the new identity.
          if (_profile?.id != state.session!.user.id) {
            _clearCloudIdentity();
          }
          unawaited(_refreshProfileQuietly());
        }
      },
      onError: (Object _) {
        // Supabase reports invalid/expired callback exchanges on this stream.
        // The UI handles a safe generic message; never echo callback details.
      },
    );
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
        cloudProfile: profile,
        cloudProfileLoaded: profileLoaded,
        cloudProfileFailed: _profileFailed,
      );

  String? effectiveUsername({required String? localUsername}) =>
      DriveItEffectiveProfile.username(
        localUsername: localUsername,
        hasSession: hasSession,
        cloudProfile: profile,
        cloudProfileLoaded: profileLoaded,
        cloudProfileFailed: _profileFailed,
      );

  void _clearCloudIdentity() {
    _profileRequest++;
    _profileLoadFuture = null;
    _profileLoadContext = null;
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
      _testClient ??
      (SupabaseBootstrap.isInitialized ? Supabase.instance.client : null);

  @override
  bool get isAvailable => _client != null;
  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;
  @override
  bool get hasSession => currentSession != null;
  @override
  String? get currentDisplayName {
    if (!_profileIsVisible()) return null;
    return currentUser?.userMetadata?['display_name']?.toString();
  }

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
  }) => _identityChange(
    () => _signUp(
      displayName: displayName,
      username: username,
      email: email,
      password: password,
    ),
  );
  Future<bool> _signUp({
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
        emailRedirectTo: DriveItAuthCallback.uri,
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
  Future<void> signIn({required String email, required String password}) =>
      _identityChange(() => _signIn(email: email, password: password));
  Future<void> _signIn({
    required String email,
    required String password,
  }) async {
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
  Future<void> signOut() => _identityChange(_signOut);
  Future<void> _signOut() async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    await client.auth.signOut();
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    final client = _client;
    if (client == null) throw const AccountServiceException.unavailable();
    try {
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: DriveItAuthCallback.uri,
      );
    } on AuthException catch (error) {
      throw AccountServiceException.fromAuth(error);
    }
  }

  @override
  Future<void> completePasswordRecovery(String newPassword) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      throw const AccountServiceException.unavailable();
    }
    final validation = AccountInputRules.validatePassword(newPassword);
    if (validation != null) throw AccountServiceException(validation);
    try {
      await client.auth.updateUser(UserAttributes(password: newPassword));
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
    final context = _profileContext();
    final validation = AccountInputRules.validateDisplayName(normalized);
    if (validation != null) throw AccountServiceException(validation);
    try {
      final row = await _profileOperation(client, (data, uid) {
        if (uid != user.id) throw StateError('Owner changed');
        return data
            .from('profiles')
            .update({'display_name': normalized})
            .eq('id', uid)
            .select('id, username, display_name, avatar_url')
            .maybeSingle();
      });
      if (row == null || row['id'] != user.id) {
        throw const AccountServiceException.profileUnavailable();
      }
      _requireProfileContext(context);
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
    final context = _profileContext();
    final validation = AccountInputRules.validateUsername(normalized);
    if (validation != null) throw AccountServiceException(validation);
    final current = profile ?? await fetchCurrentProfile();
    if (current?.username?.trim().toLowerCase() == normalized) {
      _requireProfileContext(context);
      if (current == null) {
        throw const AccountServiceException.profileUnavailable();
      }
      return current;
    }
    try {
      final row = await _profileOperation(client, (data, uid) {
        if (uid != user.id) throw StateError('Owner changed');
        return data
            .from('profiles')
            .update({'username': normalized})
            .eq('id', uid)
            .select('id, username, display_name, avatar_url')
            .maybeSingle();
      });
      if (row == null || row['id'] != user.id) {
        throw const AccountServiceException.profileUnavailable();
      }
      _requireProfileContext(context);
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
    final context = _profileContext();
    if (_requiresScopedProfile && context.$1 != null) {
      _requireProfileContext(context);
    }
    final inFlight = _profileLoadFuture;
    if (inFlight != null &&
        (!_requiresScopedProfile || _profileLoadContext == context)) {
      return inFlight;
    }
    final future = _fetchCurrentProfile();
    _profileLoadFuture = future;
    _profileLoadContext = context;
    return future.whenComplete(() {
      if (identical(_profileLoadFuture, future)) {
        _profileLoadFuture = null;
        _profileLoadContext = null;
      }
    });
  }

  Future<DriveItAccountProfile?> _fetchCurrentProfile() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final request = ++_profileRequest;
    final context = _profileContext();
    _profileLoading = true;
    _profileFailed = false;
    _profileError = null;
    notifyListeners();
    try {
      final row = await _profileOperation(client, (data, uid) {
        if (uid != user.id) throw StateError('Owner changed');
        return data
            .from('profiles')
            .select('id, username, display_name, avatar_url')
            .eq('id', uid)
            .maybeSingle();
      });
      if (request != _profileRequest ||
          _client?.auth.currentUser?.id != user.id) {
        return this.profile;
      }
      _requireProfileContext(context);
      if (row == null || row['id'] != user.id) {
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
      _requireProfileContext(context);
      _setProfileFailure(
        'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.',
        request,
      );
      throw const AccountServiceException.profileUnavailable();
    } catch (_) {
      _requireProfileContext(context);
      _setProfileFailure(
        'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.',
        request,
      );
      rethrow;
    }
  }

  void _publishCloudProfile(DriveItAccountProfile profile) {
    _profileRequest++;
    _profileEpoch = _testGateway?.approvedEpoch() ?? _controlledOwner?.epoch;
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
