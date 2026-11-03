import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class ManualDevSessionChecks {
  // Storage deliberately hides RLS-protected objects as not found. Require a
  // successful A read of this exact object before treating B's response as denial.
  static bool storageDenied(
    StorageException error, {
    required bool controlRead,
  }) {
    if (!controlRead) return false;
    final message = error.message.toLowerCase().trim();
    final code = (error.error ?? '').toLowerCase().trim();
    return (error.statusCode == '400' || error.statusCode == '404') &&
            (message == 'object not found' ||
                message == 'the resource was not found' ||
                code == 'nosuchkey') ||
        controlRead &&
            error.statusCode == '403' &&
            (code == 'accessdenied' ||
                message == 'new row violates row-level security policy');
  }

  static Future<SupabaseClient> recreate(
    SupabaseClient old,
    SupabaseClient Function() create,
  ) async {
    // dispose releases SDK resources. signOut also revokes the server session.
    await old.dispose();
    return create();
  }
}
