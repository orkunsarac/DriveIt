import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/owner_drive_sync_client.dart';
import '../../services/owner_sync_canonical_json.dart';

abstract final class ManualDevSessionChecks {
  // Storage deliberately hides RLS-protected objects as not found. Require a
  // verified A read through the official download Function, never bucket SELECT.
  static bool downloadMatches(
    OwnerSyncMutation expected,
    OwnerSyncMutation actual,
  ) =>
      canonicalOwnerSyncSha256(actual.payload) == expected.payloadFingerprint &&
      canonicalOwnerSyncJson(actual.toMap()) ==
          canonicalOwnerSyncJson(expected.toMap());

  static bool storageDenied(
    StorageException error, {
    required bool officialDownloadVerified,
  }) {
    if (!officialDownloadVerified) return false;
    final message = error.message.toLowerCase().trim();
    final code = (error.error ?? '').toLowerCase().trim();
    return (error.statusCode == '400' || error.statusCode == '404') &&
            (message == 'object not found' ||
                message == 'the resource was not found' ||
                code == 'nosuchkey') ||
        officialDownloadVerified &&
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
