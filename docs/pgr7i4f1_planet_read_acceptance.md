# P-GR7I 4F1 — owner-scoped Planet okuma entegrasyonu

Dar istemci okuma/owner izolasyonu: **PASS**. Planet genel yayın kabulü tamamlanmış değildir: mevcut skor bundle kaynak bütünlüğü testi **FAIL** (aşağıda). PROD etkinleştirilmedi.

## Gerçek üretim yolu

`SupabasePlanetMapRepository` Play'de yalnız onaylı gateway üzerinden `read_planet_viewport` RPC çağırır. `SupabasePlanetTraceDetailRepository` yalnız `planet-trace-detail` Edge endpoint'ini kullanır. Varsayılan uygulama bağlantısı `SupabaseAccountService.requirePlanetReadGateway` ile gerçek owner lease'ini yakalar; UID, epoch, geçerli lease, PROD URL ve işlem token'ı eşleşmelidir. Her istekte ayrı client ve sabit credential, yanıt öncesi/sonrası mevcut gateway kontrolü uygulanır. DEV ortak istemci yolu korunur.

Play detay isteğinde id-only in-flight cache kullanılmaz; böylece aynı trace id üzerinden hesap/token değişimine ait eski Future paylaşılmaz. Harita controller'ı iptal edilen scope'un cache/snapshot'ını siler ve snapshot getter'ı geçersiz bağlamda veri döndürmez. Detay ekranı scope geçersizse tamamlanmış özeti ve seçilmiş rota önizlemesini gizler. Owner değiştiğinde eski ekranın scope'u yeniden yetkilendirilmez; yeni lease için yeni repository/ekran gerekir. Gateway sahibi yeni hesabı otomatik takip etmez.

Yeni yayın, kişisel bulut tabloları veya Storage kaynağına doğrudan erişim eklenmedi. İstemcide izinli endpoint'lerin dışına çıkan hiçbir istek testte kabul edilmez. Viewport API bounded region/LRU kullanır; cursor pagination sözleşmesi yoktur ve eklenmedi.

## Test matrisi

| Kontrol | Sonuç / kanıt |
| --- | --- |
| Gerçek SDK + gerçek lifecycle ile A harita/detay | PASS, iki üretim repository ve A HTTP credential |
| A→B, logout, epoch | PASS, harita ve detay HTTP yanıtları birlikte bekletilir; eski yanıtlar reddedilir, yeni istek başlatılmaz |
| Aynı UID token refresh | PASS, eski bekleyen yanıt reddedilir; sonraki istek yeni token kullanır |
| Yanlış proje ve owner | PASS, ayrı negatif testler, HTTP başlamaz |
| Yetkisiz sunucu cevabı ve retry | PASS, sentetik 401 reddi; sonraki çağrı yeniden çalışır |
| A önbelleğinin B'de görünmemesi | PASS, gerçek lifecycle controller testi; cache ve snapshot temizlenir |
| Açık detay ekranı | PASS, widget testi scope iptalinde ad/rota önizlemesi gizlenir; başlangıçta yetkisiz scope hata sızdırmaz |
| Gizli GPS/kaynak ayrımı | PASS, istemci yalnız Planet RPC/Edge okur ve kişisel source alanlarını modele taşımaz; 11 Deno sözleşme/mahremiyet testi geçer. Hosted RLS/veri ispatı değildir |
| Mevcut map/detail/LRU/generation/viewport ve profil/upload/download | PASS, ilgili Flutter regresyonları |
| Hosted PROD/DEV, Android cihaz ve gerçek ağ teslimi | NOT TESTED; bağlantı/kurulum yapılmadı |

Flutter: `flutter test --no-pub test/planet_owner_read_integration_test.dart test/planet_map_test.dart test/planet_detail_test.dart test/planet_cache_test.dart test/owner_profile_real_lifecycle_test.dart test/owner_upload_real_lifecycle_test.dart test/owner_download_real_lifecycle_test.dart` — **48 PASS, 0 atlanan, exit 0**.

Tam `flutter analyze --no-pub`: mevcut **3 warning + 4 info**, yeni bulgu yok; exit 1. Yeni biçim bulguları giderildi. `git diff --check` kontrolü checkpoint öncesinde yapılır.

İlk Flutter koşusunda UI interface cast derleme hatası ve eşzamanlı test Future'ına geç hata dinleyicisi bağlama sorunu giderildi; güvenlik assertion'ları/testler kaldırılmadı.

## Ek Deno kontrolü — mevcut FAIL

`deno test --allow-read supabase/functions/planet-trace-detail/detail.test.ts supabase/functions/process-world-publish/planet_map_read.test.ts`: **11 PASS / 1 FAIL, exit 1**.

Başarısız: `generated score bundle matches normalized Dart dependency hashes` (`detail.test.ts:250`, kaynak hash assertion `:270`). Bundle/manifest ve kaynaklar bu görevde değiştirilmedi; `git diff --exit-code HEAD -- lib/features/drive_score lib/models/canonical_telemetry_point.dart supabase/functions/planet-trace-detail/score.manifest.json supabase/functions/planet-trace-detail/score.generated.js` exit 0. Böylece aynı içerik uyuşmazlığı başlangıç checkpoint'inde de mevcuttur.

Normalize edilmiş kaynak hash'i manifestten farklı olan dosyalar:
- lib/features/drive_score/models/driving_analysis_models.dart
- lib/features/drive_score/services/braking_score_engine.dart
- lib/features/drive_score/services/drive_feature_extractor.dart
- lib/features/drive_score/services/drive_phase_analyzer.dart
- lib/features/drive_score/services/drive_score_calculator.dart
- lib/features/drive_score/services/tempo_performance_engine.dart
- lib/features/drive_score/services/transition_control_engine.dart
- lib/models/canonical_telemetry_point.dart

Manifest körlemesine yenilenmedi; skor algoritması/bundle bu aşamada yeniden üretilmedi veya deploy edilmedi. Kaynak/bundle uyumu ayrı teknik yayın engelidir; Planet skor tutarlılığı PASS ilan edilmez.

Mahremiyet kaynakları: `202610070001_planet_trace_detail_read.sql` yalnız aktif trace + `w.status='published'` ile context döndürür; metadata RPC service_role içindir. `planet-trace-detail/detail.ts` kaynak sahipliğini/sözleşmesini doğrular, response'a raw GPS/telemetri/source_path eklemez ve pahalı hesaplama sonrası context'i yeniden doğrular. Bu davranışların saf sözleşme testleri geçti; gerçek hosted ortam bu görevde incelenmedi.

## Korunan sınırlar

Play Auth/signup/cloud gate, World Publish/Storage/processing, Group Drive, silme worker'ı, hukuki onboarding, R1 signing ve Android paketleri değiştirilmedi. Yalnız güvenli okuma kodu/testleri checkpoint'e alınır. Yeni aşamaya veya PROD aktivasyonuna geçilmez.

## 4F1B takip kaydı

Önceki kaynak hash başarısızlığı güvenilir üreticiyle yeniden derlenerek düzeltildi; ilgili Deno paketi 12/12 geçti. Yerel reliable hesaplayıcı ile Planet legacy v1 arasında ayrı, önceden mevcut bir skor sözleşmesi farkı ölçüldü. Ayrıntı ve açık FAIL sonucu: `docs/pgr7i4f1b_score_bundle_acceptance.md`.
