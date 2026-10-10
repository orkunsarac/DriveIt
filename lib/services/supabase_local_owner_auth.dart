import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_owner_lifecycle.dart';

/// Construct explicitly only after Supabase bootstrap succeeds and the complete
/// ownership flow is enabled. Does not initialize Supabase or log credentials.
class SupabaseLocalOwnerAuth implements LocalOwnerAuth {
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
