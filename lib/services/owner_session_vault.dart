import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
