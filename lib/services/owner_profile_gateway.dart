import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_environment_policy.dart';
import '../config/supabase_public_key_policy.dart';

/// A single request's credential is immutable and cannot follow SDK changes.
class OwnerProfileGateway {
  OwnerProfileGateway({
    required this.authClient,
    required this.url,
    required this.publicKey,
    required this.applicationId,
    required this.approvedOwner,
    required this.approvedEpoch,
    required this.isLeaseCurrent,
    this.transport,
  });

  final SupabaseClient authClient;
  final String url, publicKey, applicationId;
  final String? Function() approvedOwner;
  final int Function() approvedEpoch;
  final bool Function(int) isLeaseCurrent;
  final http.Client? transport;

  Future<T> run<T>(Future<T> Function(SupabaseClient, String) action) async {
    if (!SupabasePublicKeyPolicy.permits(publicKey) || !SupabaseEnvironmentPolicy.permits(
      applicationId: applicationId,
      url: url,
    )) {
      throw StateError('Unapproved data project');
    }
    final session = authClient.auth.currentSession;
    final uid = approvedOwner();
    final epoch = approvedEpoch();
    if (session == null ||
        uid == null ||
        session.user.id != uid ||
        session.accessToken.isEmpty ||
        !isLeaseCurrent(epoch)) {
      throw StateError('Owner context unavailable');
    }
    final token = session.accessToken;
    void check() {
      final now = authClient.auth.currentSession;
      if (!isLeaseCurrent(epoch) ||
          approvedOwner() != uid ||
          now?.user.id != uid ||
          now?.accessToken != token) {
        throw StateError('Owner context revoked');
      }
    }

    check();
    final data = SupabaseClient(
      url,
      publicKey,
      httpClient: transport,
      accessToken: () async {
        check();
        return token;
      },
    );
    try {
      final result = await action(data, uid);
      check();
      return result;
    } finally {
      await data.dispose();
    }
  }
}
