import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_owner_lifecycle.dart';

/// Android-backed session vault. It never enables SDK automatic persistence.
/// The caller must separately fence and authenticate a restored session.
abstract interface class OwnerSessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class AndroidOwnerSessionStorage implements OwnerSessionStorage {
  const AndroidOwnerSessionStorage();
  static const _key = 'driveit.auth.play.session.v1';
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class OwnerSessionVault {
  OwnerSessionVault(this.storage);
  final OwnerSessionStorage storage;
  static final _uid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static void validate(Session session) {
    final token = session.accessToken;
    final parts = token.split('.');
    if (parts.length != 3 ||
        session.refreshToken == null ||
        session.refreshToken!.isEmpty ||
        !_uid.hasMatch(session.user.id) ||
        session.tokenType.toLowerCase() != 'bearer') {
      throw const FormatException('Invalid session');
    }
    final Object? payload;
    try {
      payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } catch (_) {
      throw const FormatException('Invalid session');
    }
    if (payload is! Map ||
        payload['sub'] != session.user.id ||
        payload['exp'] is! int ||
        (payload['exp'] as int) <= 0) {
      throw const FormatException('Invalid session');
    }
  }

  Future<void> save(Session session) async {
    validate(session);
    // Provider credentials are not needed by DriveIt and are never persisted.
    final data = session.toJson()
      ..remove('provider_token')
      ..remove('provider_refresh_token');
    await storage.write(jsonEncode(data));
  }

  Future<Session?> load() async {
    final raw = await storage.read();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid session');
      }
      final session = Session.fromJson(decoded);
      if (session == null) throw const FormatException('Invalid session');
      validate(session);
      return session;
    } catch (_) {
      // Do not delete or overwrite malformed data automatically; fail closed.
      throw const FormatException('Invalid stored session');
    }
  }

  Future<void> clear() => storage.clear();
}

/// Runs before personal UI and foreground attachment. Server verification is
/// mandatory; JWT parsing in the vault is not an authentication decision.
Future<void> restoreVerifiedOwnerSession({
  required LocalOwnerLifecycle owner,
  required SupabaseClient client,
  required OwnerSessionVault vault,
}) async {
  if (client.auth.currentSession != null) {
    throw StateError('Unexpected session before restore');
  }
  String? restoredOwner;
  await owner.authorizeIdentityChange(() async {
    final restoreEpoch = owner.epoch;
    void requireUnchanged() {
      if (owner.epoch != restoreEpoch ||
          owner.state != LocalOwnerState.preparing ||
          client.auth.currentSession != null) {
        throw StateError('Restore context changed');
      }
    }

    requireUnchanged();
    final stored = await vault.load();
    requireUnchanged();
    if (stored == null) return;
    if (stored.expiresAt == null) {
      throw StateError('Stored session expiry missing');
    }
    Session verifiedSession;
    if (stored.isExpired || stored.expiresAt! <= _refreshBeforeEpoch()) {
      // refreshSession installs the returned session and emits TOKEN_REFRESHED.
      // The owner identity-change fence remains held while we authenticate it.
      try {
        final refreshed = await client.auth.refreshSession(stored.refreshToken);
        final candidate = refreshed.session;
        if (candidate == null || candidate.user.id != stored.user.id) {
          throw StateError('Refresh owner mismatch');
        }
        final verified = await client.auth.getUser(candidate.accessToken);
        final current = client.auth.currentSession;
        if (verified.user?.id != stored.user.id ||
            verified.user?.isAnonymous != false ||
            current?.user.id != stored.user.id ||
            current?.accessToken != candidate.accessToken ||
            current?.refreshToken != candidate.refreshToken) {
          throw StateError('Refreshed session verification failed');
        }
        verifiedSession = candidate.copyWith(user: verified.user!);
        await vault.save(verifiedSession);
        if (client.auth.currentSession?.accessToken != candidate.accessToken ||
            client.auth.currentSession?.refreshToken !=
                candidate.refreshToken) {
          throw StateError('Session changed during refresh storage');
        }
      } catch (_) {
        // Supabase installs and broadcasts the refreshed session before the
        // server-user check. Clear any candidate inside this fence so its
        // queued event cannot open another owner's store.
        if (client.auth.currentSession != null) {
          await vault.clear();
          await client.auth.signOut(scope: SignOutScope.local);
        }
        rethrow;
      }
    } else {
      final verified = await client.auth.getUser(stored.accessToken);
      requireUnchanged();
      if (verified.user?.id != stored.user.id ||
          verified.user?.isAnonymous != false ||
          client.auth.currentSession != null ||
          stored.isExpired) {
        throw StateError('Stored session verification failed');
      }
      verifiedSession = stored.copyWith(user: verified.user!);
      await client.auth.recoverSession(jsonEncode(verifiedSession.toJson()));
    }
    if (client.auth.currentSession?.user.id != stored.user.id ||
        client.auth.currentSession?.accessToken !=
            verifiedSession.accessToken) {
      throw StateError('Restored session changed');
    }
    restoredOwner = stored.user.id;
  }, revokeBeforeChange: true);
  if (restoredOwner != null && owner.lease.owner.userId != restoredOwner) {
    throw StateError('Restored owner mismatch');
  }
}

/// Refreshes an already active account only while its owner lease is fenced.
/// No SDK automatic refresh is enabled; callers invoke this on resume or before
/// a protected cloud action. GPS identity changes remain blocked by the owner.
Future<bool> refreshVerifiedOwnerSession({
  required LocalOwnerLifecycle owner,
  required SupabaseClient client,
  required OwnerSessionVault vault,
  Duration refreshWindow = const Duration(minutes: 2),
}) async {
  final before = client.auth.currentSession;
  if (before == null || before.user.isAnonymous) return false;
  final lease = owner.lease;
  final uid = before.user.id;
  if (lease.owner.userId != uid || before.expiresAt == null) {
    throw StateError('Refresh owner context unavailable');
  }
  if (before.expiresAt! >
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + refreshWindow.inSeconds) {
    return false;
  }
  var refreshedToken = false;
  await owner.authorizeIdentityChange(() async {
    try {
      if (client.auth.currentSession?.user.id != uid ||
          client.auth.currentSession?.refreshToken != before.refreshToken) {
        throw StateError('Refresh session changed before request');
      }
      final response = await client.auth.refreshSession(before.refreshToken);
      final candidate = response.session;
      if (candidate == null || candidate.user.id != uid) {
        await vault.clear();
        throw StateError('Refresh owner mismatch');
      }
      final verified = await client.auth.getUser(candidate.accessToken);
      final current = client.auth.currentSession;
      if (verified.user?.id != uid ||
          verified.user?.isAnonymous != false ||
          current?.user.id != uid ||
          current?.accessToken != candidate.accessToken ||
          current?.refreshToken != candidate.refreshToken) {
        await vault.clear();
        throw StateError('Refreshed session verification failed');
      }
      final verifiedSession = candidate.copyWith(user: verified.user!);
      await vault.save(verifiedSession);
      final persisted = await vault.load();
      if (persisted?.user.id != uid ||
          persisted?.accessToken != candidate.accessToken ||
          persisted?.refreshToken != candidate.refreshToken ||
          client.auth.currentSession?.accessToken != candidate.accessToken) {
        await vault.clear();
        throw StateError('Rotated session was not safely persisted');
      }
      refreshedToken = true;
    } catch (_) {
      // SDK refresh mutates its shared session before returning. If anything
      // fails after that point, synchronously clear it inside the owner fence
      // so a queued TOKEN_REFRESHED event cannot open the candidate owner.
      final current = client.auth.currentSession;
      if (current == null) {
        await vault.clear();
      } else {
        if (current.user.id != uid ||
            current.accessToken != before.accessToken) {
          await vault.clear();
        }
        await client.auth.signOut(scope: SignOutScope.local);
      }
      rethrow;
    }
  }, revokeBeforeChange: true);
  if (owner.lease.owner.userId != uid ||
      client.auth.currentSession?.user.id != uid) {
    throw StateError('Refresh owner changed');
  }
  return refreshedToken;
}

int _refreshBeforeEpoch() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
