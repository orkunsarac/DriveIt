import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_bootstrap.dart';
import '../models/planet_viewport.dart';

abstract interface class PlanetMapRepository {
  Future<PlanetSnapshot> read(PlanetViewport viewport);
}

class PlanetReadFailure implements Exception {
  const PlanetReadFailure(this.message);
  final String message;
}

class SupabasePlanetMapRepository implements PlanetMapRepository {
  @override
  Future<PlanetSnapshot> read(PlanetViewport viewport) async {
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
