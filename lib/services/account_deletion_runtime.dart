import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_bootstrap.dart';
import '../config/supabase_environment_policy.dart';
import '../config/supabase_public_key_policy.dart';
import 'account_deletion_controller.dart';
import 'owner_profile_gateway.dart';
import 'supabase_account_service.dart';

class SecureAccountDeletionReceiptStore implements AccountDeletionReceiptStore {
  SecureAccountDeletionReceiptStore(this.endpoint);
  final String endpoint;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String get pointer =>
      'driveit.deletion.last.${AccountDeletionController.receiptKey(endpoint, 'pointer')}';
  String key(String owner) =>
      'driveit.deletion.${AccountDeletionController.receiptKey(endpoint, owner)}';
  @override
  Future<Map<String, dynamic>?> read(String? owner) async {
    final selected = owner ?? await storage.read(key: pointer);
    if (selected == null) return null;
    final value = await storage.read(key: key(selected));
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> receipt) async {
    final owner = receipt['owner'] as String;
    await storage.write(key: key(owner), value: jsonEncode(receipt));
    await storage.write(key: pointer, value: owner);
  }

  @override
  Future<void> remove(String owner) async {
    await storage.delete(key: key(owner));
    if (await storage.read(key: pointer) == owner) {
      await storage.delete(key: pointer);
    }
  }
}

/// Play's request action uses a credential-pinned owner gateway. Receipt-only
/// `run` calls intentionally send no Authorization header: after the server
/// revokes the account session, the random receipt is the recovery capability.
class OwnerScopedAccountDeletionTransport {
  OwnerScopedAccountDeletionTransport({
    required this.endpoint,
    required this.publicKey,
    required this.applicationId,
    required this.gatewayForOwner,
    this.receiptClient,
  });

  final String endpoint;
  final String publicKey;
  final String applicationId;
  final OwnerProfileGateway Function(String owner) gatewayForOwner;
  final http.Client? receiptClient;

  static final _requestIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final _receiptPattern = RegExp(r'^[0-9a-f]{64}$');

  Future<AccountDeletionReply> send(Map<String, dynamic> body) async {
    _requirePlayProject();
    final action = body['action'];
    if (action == 'request') return _request(body);
    if (action == 'run') return _resume(body);
    throw StateError('Deletion action is not allowed');
  }

  void _requirePlayProject() {
    if (!SupabasePublicKeyPolicy.permits(publicKey) ||
        !SupabaseEnvironmentPolicy.permits(
          applicationId: applicationId,
          url: endpoint,
        )) {
      throw StateError('Account deletion project is not approved');
    }
  }

  Future<AccountDeletionReply> _request(Map<String, dynamic> body) async {
    final owner = body['expectedOwner'];
    final requestId = body['requestId'];
    final receiptToken = body['receiptToken'];
    if (owner is! String ||
        owner.isEmpty ||
        requestId is! String ||
        !_requestIdPattern.hasMatch(requestId) ||
        receiptToken is! String ||
        !_receiptPattern.hasMatch(receiptToken) ||
        body['confirm'] != 'DELETE_MY_ACCOUNT' ||
        body['password'] is! String ||
        (body['password'] as String).isEmpty) {
      throw StateError('Account deletion confirmation is invalid');
    }
    return gatewayForOwner(owner).run((client, uid) async {
      if (uid != owner || body['expectedOwner'] != uid) {
        throw StateError('Account deletion owner mismatch');
      }
      final requestBody = <String, Object?>{
        'action': 'request',
        'requestId': requestId,
        'receiptToken': receiptToken,
        'expectedOwner': uid,
        'confirm': 'DELETE_MY_ACCOUNT',
        'password': body['password'],
      };
      try {
        final response = await client.functions
            .invoke('delete-account', body: requestBody)
            .timeout(const Duration(seconds: 30));
        return (status: response.status, body: _map(response.data));
      } on FunctionException catch (error) {
        return (status: error.status, body: _map(error.details));
      }
    });
  }

  Future<AccountDeletionReply> _resume(Map<String, dynamic> body) async {
    final requestId = body['requestId'];
    final token = body['receiptToken'];
    if (requestId is! String ||
        !_requestIdPattern.hasMatch(requestId) ||
        token is! String ||
        !_receiptPattern.hasMatch(token)) {
      throw StateError('Account deletion receipt is invalid');
    }
    final root = Uri.parse(endpoint);
    final uri = root.replace(path: '/functions/v1/delete-account');
    final client = receiptClient ?? http.Client();
    final ownsClient = receiptClient == null;
    try {
      final response = await client
          .post(
            uri,
            headers: {'apikey': publicKey, 'content-type': 'application/json'},
            body: jsonEncode({
              'action': 'run',
              'requestId': requestId,
              'receiptToken': token,
            }),
          )
          .timeout(const Duration(seconds: 30));
      return (status: response.statusCode, body: _decodeMap(response.body));
    } finally {
      if (ownsClient) client.close();
    }
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static Map<String, dynamic> _decodeMap(String value) {
    try {
      return _map(jsonDecode(value));
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}

abstract final class AccountDeletionRuntime {
  static const _configuredEnabled = bool.fromEnvironment(
    'DRIVEIT_ACCOUNT_DELETION_ENABLED',
  );
  static bool get enabled {
    if (!_configuredEnabled) return false;
    if (!SupabaseBootstrap.isPlayPackage) return true;
    try {
      SupabaseAccountService.instance.requireAccountDeletionLease();
      return true;
    } catch (_) {
      return false;
    }
  }

  static AccountDeletionController? _controller;
  static AccountDeletionController get controller => _controller ??= create();
  static AccountDeletionController create() {
    final account = SupabaseAccountService.instance,
        client = Supabase.instance.client;
    if (SupabaseBootstrap.isPlayPackage) {
      account.requireAccountDeletionLease();
      final endpoint = SupabaseConfig.url;
      final publicKey = SupabaseConfig.publishableKey;
      final transport = OwnerScopedAccountDeletionTransport(
        endpoint: endpoint,
        publicKey: publicKey,
        applicationId: 'com.osaracx.driveit',
        gatewayForOwner: (owner) => account.requireAccountDeletionGateway(
          lease: account.requireAccountDeletionLease(owner),
        ),
      );
      return AccountDeletionController(
        endpoint: endpoint,
        store: SecureAccountDeletionReceiptStore(endpoint),
        currentOwner: () => client.auth.currentUser?.id,
        guard: account.authorizeAccountDeletion,
        // A receipt is a one-purpose recovery capability. No user session or
        // other account's credential participates in this resume path.
        resumeGuard: (action) => action(),
        signOutLocal: (owner) async {
          if (client.auth.currentUser?.id == owner) {
            await client.auth.signOut(scope: SignOutScope.local);
          }
        },
        send: transport.send,
      );
    }
    return AccountDeletionController(
      endpoint: SupabaseConfig.url,
      store: SecureAccountDeletionReceiptStore(SupabaseConfig.url),
      currentOwner: () => client.auth.currentUser?.id,
      guard: account.authorizeAccountDeletion,
      signOutLocal: (owner) async {
        if (client.auth.currentUser?.id == owner) {
          await client.auth.signOut(scope: SignOutScope.local);
        }
      },
      send: (body) async {
        try {
          final r = await client.functions.invoke('delete-account', body: body);
          return (
            status: r.status,
            body: Map<String, dynamic>.from(r.data as Map),
          );
        } on FunctionException catch (e) {
          return (
            status: e.status,
            body: e.details is Map
                ? Map<String, dynamic>.from(e.details as Map)
                : <String, dynamic>{},
          );
        }
      },
    );
  }
}
