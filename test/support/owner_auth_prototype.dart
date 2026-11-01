import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated experiment only: this is not wired into the application.
class OwnerAuthPrototype {
  OwnerAuthPrototype({
    required SupabaseClient authClient,
    required this.ownerId,
    required this.epoch,
    required this.isCurrent,
    required String capturedToken,
    required http.Client transport,
  }) : _authClient = authClient,
       _token = capturedToken {
    if (authClient.auth.currentUser?.id != ownerId ||
        !isCurrent(epoch) ||
        capturedToken.isEmpty ||
        authClient.auth.currentSession?.accessToken != capturedToken) {
      throw StateError('Unapproved owner context');
    }
    _dataClient = SupabaseClient(
      'https://example.invalid',
      'synthetic-public',
      httpClient: transport,
      accessToken: () async {
        _requireCurrent();
        return _token;
      },
    );
  }
  final SupabaseClient _authClient;
  final String ownerId;
  final int epoch;
  final bool Function(int) isCurrent;
  final String _token;
  late final SupabaseClient _dataClient;

  void _requireCurrent() {
    if (!isCurrent(epoch) || _authClient.auth.currentUser?.id != ownerId) {
      throw StateError('Owner context revoked');
    }
  }

  Future<FunctionResponse> invoke(
    String function,
    Map<String, Object?> body,
  ) async {
    _requireCurrent();
    final response = await _dataClient.functions.invoke(function, body: body);
    _requireCurrent();
    return response;
  }

  Future<void> dispose() => _dataClient.dispose();
}
