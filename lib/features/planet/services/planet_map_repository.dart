import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_bootstrap.dart';
import '../models/planet_viewport.dart';
import 'package:flutter/foundation.dart';
import '../../../services/owner_profile_gateway.dart';
import 'planet_read_scope.dart';

abstract interface class PlanetMapRepository {
  Future<PlanetSnapshot> read(PlanetViewport viewport);
}

class PlanetReadFailure implements Exception {
  const PlanetReadFailure(this.message);
  final String message;
}

class SupabasePlanetMapRepository
    implements PlanetMapRepository, PlanetScopedRead {
  SupabasePlanetMapRepository({
    OwnerProfileGateway? gateway,
    Listenable? ownerChanges,
  }) : _scope = PlanetReadScope(gateway, ownerChanges);
  final PlanetReadScope _scope;
  @override
  bool get isReadAuthorized => _scope.authorized;
  @override
  Listenable? get readScopeChanges => _scope.changes;
  @override
  Future<PlanetSnapshot> read(PlanetViewport viewport) async {
    if (_scope.scoped) {
      try {
        return await _scope.gateway.run(
          (data, uid) async => PlanetSnapshot.parse(
            await data.rpc('read_planet_viewport', params: viewport.params),
          ),
        );
      } catch (_) {
        throw const PlanetReadFailure(
          'Gezegen verileri alınamadı. Tekrar deneyebilirsin.',
        );
      }
    }
    if (!SupabaseBootstrap.isInitialized) {
      throw const PlanetReadFailure(
        'Çevrimiçi gezegen hizmeti şu anda kullanılamıyor.',
      );
    }
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw const PlanetReadFailure(
        'Gezegeni görmek için DriveIt hesabına giriş yap.',
      );
    }
    try {
      return PlanetSnapshot.parse(
        await client.rpc('read_planet_viewport', params: viewport.params),
      );
    } catch (_) {
      throw const PlanetReadFailure(
        'Gezegen verileri alınamadı. Tekrar deneyebilirsin.',
      );
    }
  }
}
