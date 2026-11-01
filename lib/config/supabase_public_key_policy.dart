import 'dart:convert';

/// Client builds may contain only publishable keys or legacy anon JWTs.
abstract final class SupabasePublicKeyPolicy {
  static bool permits(String key) {
    if (key.startsWith('sb_publishable_')) return key.length > 15;
    if (key.startsWith('sb_secret_')) return false;
    final parts = key.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}
