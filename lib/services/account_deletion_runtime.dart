import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_bootstrap.dart';
import 'account_deletion_controller.dart';
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

abstract final class AccountDeletionRuntime {
  static const enabled = bool.fromEnvironment(
    'DRIVEIT_ACCOUNT_DELETION_ENABLED',
  );
  static AccountDeletionController? _controller;
  static AccountDeletionController get controller => _controller ??= create();
  static AccountDeletionController create() {
    if (SupabaseBootstrap.isPlayPackage) {
      throw StateError('Owner-scoped account deletion is unavailable');
    }
    final account = SupabaseAccountService.instance,
        client = Supabase.instance.client;
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
