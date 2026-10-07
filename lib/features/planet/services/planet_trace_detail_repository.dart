import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_bootstrap.dart';
import '../models/planet_trace_detail.dart';

abstract interface class PlanetTraceDetailRepository {
  Future<PlanetTraceDetail> read(String traceId);
}

class PlanetDetailFailure implements Exception {
  const PlanetDetailFailure(this.code);
  final String code;
  String get message => switch (code) {
    'trace_retired' ||
    'trace_changed' => 'Bu iz artık güncel değil. Haritayı yenileyebilirsin.',
    'unauthorized' => 'İz detayını görmek için hesabına giriş yap.',
    'source_invalid' ||
    'source_unavailable' ||
    'score_unavailable' => 'Bu sürüşün detayları şu anda kullanılamıyor.',
    _ => 'İz detayı alınamadı. Tekrar deneyebilirsin.',
  };
}

class SupabasePlanetTraceDetailRepository
    implements PlanetTraceDetailRepository {
  final _inFlight = <String, Future<PlanetTraceDetail>>{};
  @override
  Future<PlanetTraceDetail> read(String id) {
    final existing = _inFlight[id];
    if (existing != null) return existing;
    final result = _read(id);
    _inFlight[id] = result;
    return result.whenComplete(() => _inFlight.remove(id));
  }

  Future<PlanetTraceDetail> _read(String id) async {
    if (!SupabaseBootstrap.isInitialized ||
        Supabase.instance.client.auth.currentSession == null) {
      throw const PlanetDetailFailure('unauthorized');
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'planet-trace-detail',
        body: {'trace_id': id},
      );
      final detail = PlanetTraceDetail.parse(
        (response.data as Map).cast<String, dynamic>(),
      );
      if (detail.traceId != id) {
        throw const PlanetDetailFailure('trace_changed');
      }
      return detail;
    } on FunctionException catch (e) {
      final data = e.details;
      final code = data is Map ? data['error_code'] : null;
      throw PlanetDetailFailure(code is String ? code : 'detail_unavailable');
    } on PlanetDetailFailure {
      rethrow;
    } catch (_) {
      throw const PlanetDetailFailure('detail_unavailable');
    }
  }
}
