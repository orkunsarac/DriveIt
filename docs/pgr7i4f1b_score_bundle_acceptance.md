# P-GR7I 4F1B — Planet skor bundle onarımı

## Sonuç

Bundle/manifest bütünlüğü **PASS**, mevcut Planet legacy v1 ile native Dart parity **PASS**. Ek olarak ölçülen yerel `calculateReliable()` ↔ Planet legacy v1 eşitliği **FAIL**. Bu ikinci farkı değiştirmek bir skor sözleşmesi/sürüm kararı gerektirir; bu görevde hesaplama yolu veya kurallar değiştirilmedi. Tüm yerel/Planet skorlarının eşit olduğu ilan edilmez.

## Kök neden ve sekiz dosya

Bundle ve manifest `c8f9b2a` döneminde üretildi. Sonraki `5965c6f`, `f6eb724`, `638c58a` kaynak değişiklikleri sonrasında bundle yeniden üretilmemişti. Hash kontrolü CRLF→LF normalize ettiğinden fark salt Windows satır sonu farkı değildir.

| Kaynak | Gerçek kaynak farkı |
| --- | --- |
| driving_analysis_models.dart | reliableIntervalsOnly analizi bayrağı |
| braking_score_engine.dart | Reliable modda sürekli/güvenilir aralık kontrolü |
| drive_feature_extractor.dart | Segment, hız kanıtı, ivme güvenilirliği filtreleri |
| drive_phase_analyzer.dart | Reliable timeline ve segment/event sınırları |
| drive_score_calculator.dart | Mevcut calculate() legacy; ayrı calculateReliable() opt-in yolu |
| tempo_performance_engine.dart | Reliable modda ölçülen süre, hareket/durma ve komşu örnek sınırları |
| transition_control_engine.dart | Reliable modda kesintisiz geçiş koşulu |
| canonical_telemetry_point.dart | Kalite/provenance alanları ve mikrosaniye serileştirme |

Dosyalar `lib/features/drive_score/models`, `lib/features/drive_score/services` ve `lib/models` altındadır. Sekiz hash'in eski olması gerçek kaynak geliştirmelerini yansıtır; hepsi biçim farkı diye değerlendirilmedi.

## Uygulanan düzeltme

Mevcut `tool/build_planet_detail_score.ps1` Dart compiler ile `tool/planet_detail_js.dart` dosyasını derledi; recursive import/export bağımlılıklarını yeniden topladı ve normalize SHA-256 manifestini üretti. Yeni bağımlılıklar `canonical_telemetry_pipeline.dart`, `drive_time_analysis.dart`, `gps_gap_policy.dart` da üretici tarafından manifeste dahil edildi. Hash'ler elle değiştirilmedi.

- Önceki artifact hash: d44d2d11a6bc42f7a5c43d828bde193d5cbfa63786bcff317421ebc3f34ec9a3
- Yeni artifact hash: af274e3a1b1c6b3131651ea08cfdce4e3b1353c958dd172fc0c4913ca5b61fb2
- Üretim komutu: `tool/build_planet_detail_score.ps1 -DartExecutable <Dart executable>`; exit 0.

Eski bundle ve manifest karşılaştırma için yalnız benzersiz `tmp/pgr7i4f1b-*` dizininde korundu; checkpoint'e dahil edilmez. Yeniden derleme sunucu deployment değildir. Drive Score kaynakları, kalibrasyonlar, algorithmVersion, mevcut kayıtlar ve production ayarları değiştirilmedi.

## Parity kanıtı ve sınırı

`tool/test_planet_score_parity.ps1` native Dart oracle'ını çalıştırıp gerçek derlenmiş JS ile toplam, görünen skor, güven, kategoriler, katkılar ve sürüm alanlarını recursive karşılaştırır. Sayısal tolerans 1e-9; boş/tek örnekte null sözleşmesi doğrulanır. Dokuz sentetik vaka: steady, stop-start, braking, cornering, gap, microseconds, long (3600 nokta), single, empty.

Hem **eski bundle 9/9**, hem **yeni bundle 9/9** mevcut native `calculate()` legacy yolu ile eşleşti. Bu nedenle yeniden derlemenin test edilen mevcut Planet veri sözleşmesinde skor davranışını değiştirdiğine dair bulgu yoktur. Sonuç, bütün olası verilerde matematiksel eşitlik ispatı değildir. Server adapter'ı `tool/world_scoring_adapter.dart` telemetriyi legacy varsayılan kalite alanlarıyla oluşturur; server giriş noktası hâlâ `calculate()` kullanır. Reliable mod veya kalite/provenance protokolü bu görevde sunucuya taşınmadı.

## Açık gerçek uyumsuzluk ve sürümleme gereksinimi

Yeni yerel kayıtlar için `drive_score_persistence_coordinator.dart` ve `planet_segment.dart` içinde reliable hesaplama yolu bulunuyor. `calculateReliable()` ve Planet'in `calculate()` yolu aynı v1 etiketiyle farklı sonuç üretebiliyor:

| Sentetik vaka | Planet legacy display | Yerel reliable display | Ham toplam |
| --- | --- | --- | --- |
| stop-start | 782 | 782 | 781.81 ↔ 782.25 (tabloda yuvarlanmış) |
| gap | 694 | 711 | 693.76 ↔ 711.48 (tabloda yuvarlanmış) |

Bu fark eski bundle'da da aynı şekilde mevcuttu. Her sentetik gap'ın uygulamanın global kapsama kabulünü geçip kaydedileceği iddia edilmez; tablo doğrudan iki hesaplayıcı modunun aynı noktalardaki davranışını ölçer. Daha önce kaydedilmiş skorların anlamı değiştirilmedi veya skorlar tekrar hesaplanmadı.

Sunucuyu reliable moda geçirmek, yeni telemetri kalite bilgisini taşımak veya legacy/yeni skorları eşitlemek için açık hesaplama-modu/provenance sözleşmesi ve algorithmVersion/kalite sürümü ayrımı gerekir. Eski v1 sonuçlar korunmalı; aynı etiket altında sessiz hesaplayıcı değişimi yapılmamalı. Bu görevin yetkisiyle bu karar uygulanmadı.

Açık karşılaştırma komutu (synthetic oracle stdout'u stdin'e verilir):
`deno run --allow-read tool/test_planet_score_parity.ts ../supabase/functions/planet-trace-detail/score.generated.js --require-local-reliable`
Sonuç: **FAIL / exit 1**, stop-start ve gap farkları. Normal server-v1 parity çalıştırıcısı exit 0. İki farklı kabul kontrolü tek PASS altında birleştirilmez.

## Gerçek test sonuçları

- İlgili Planet Deno paketi: **12/12 PASS, exit 0** (`detail.test.ts` + `planet_map_read.test.ts`). Önceki kaynak hash testi artık geçer.
- Eski/yeni bundle ↔ native legacy parity: **9/9 + 9/9 PASS, exit 0**.
- Yerel reliable ↔ Planet legacy equality: **FAIL, exit 1**, yukarıdaki mevcut davranış farkı.
- Drive Score, persistence, golden/world parity, Planet okuma/UI/cache ve owner testleri: **128 PASS, exit 0**, atlama yok.
- Tam Flutter analyze: mevcut **3 warning + 4 info**, yeni bulgu yok, exit 1.
- Yeni TS parity aracı `deno check`: PASS, exit 0.
- `git diff --check`: PASS.

## Korunan sınırlar

PROD/DEV bağlantısı, deployment, kayıt yeniden hesaplama, Auth/Planet aktivasyonu, cihaz işlemi yapılmadı. R1/signing ve ilgisiz yerel dosyalar korundu. Bundle/manifest düzeltmesi ile teşhis/test araçları bağımsız checkpoint'tir; reliable/local eşitliği tamamlandı sayılmaz. Sonraki aşamaya geçilmez.
