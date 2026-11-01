import 'package:flutter/foundation.dart';
import '../../../config/supabase_bootstrap.dart';
import '../../../services/owner_profile_gateway.dart';
import '../../../services/supabase_account_service.dart';

/// Optional boundary implemented by real readers; fake/legacy readers retain
/// their existing presentation contract.
abstract interface class PlanetScopedRead {
  bool get isReadAuthorized;
  Listenable? get readScopeChanges;
}

class PlanetReadScope {
  PlanetReadScope(this._gateway, this._changes);
  OwnerProfileGateway? _gateway;
  final Listenable? _changes;
  bool get scoped => _gateway != null || SupabaseBootstrap.isPlayPackage;
  OwnerProfileGateway get gateway =>
      _gateway ??= SupabaseAccountService.instance.requirePlanetReadGateway();
  Listenable? get changes =>
      _changes ??
      (SupabaseBootstrap.isPlayPackage
          ? SupabaseAccountService.instance
          : null);
  bool get authorized {
    if (!scoped) return true;
    try {
      return gateway.isAuthorized;
    } catch (_) {
      return false;
    }
  }
}
