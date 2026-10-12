import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_owner_lifecycle.dart';
import '../config/supabase_bootstrap.dart';

/// Construct explicitly only after Supabase bootstrap succeeds and the complete
/// ownership flow is enabled. Does not initialize Supabase or log credentials.
class SupabaseLocalOwnerAuth implements LocalOwnerAuth {
  /// Application composition can use this restore dependency. Failed/missing
  /// SDK configuration is not a successfully restored anonymous session.
  static Future<SupabaseLocalOwnerAuth> restore() async {
    if (!await SupabaseBootstrap.initializeIfConfigured()) {
      throw StateError('Owner Auth restore unavailable');
    }
    return SupabaseLocalOwnerAuth(Supabase.instance.client);
  }

  SupabaseLocalOwnerAuth(SupabaseClient client)
    : this._(
        () => client.auth.currentSession?.user.id,
        client.auth.onAuthStateChange,
      );

  /// SDK event projection can be verified without a network/client session.
  factory SupabaseLocalOwnerAuth.events({
    required String? Function() currentUserId,
    required Stream<AuthState> events,
  }) => SupabaseLocalOwnerAuth._(currentUserId, events);
  SupabaseLocalOwnerAuth._(this._currentUserId, this._events);
  final String? Function() _currentUserId;
  final Stream<AuthState> _events;
  @override
  String? get userId => _currentUserId();
  @override
  Stream<String?> get changes =>
      _events.map((state) => state.session?.user.id).distinct();
}
