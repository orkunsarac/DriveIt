# P-GR7I 4F2A — Schema 2 Planet İşleme Kabulü

## Kapsam ve sonuç

Schema 2 (`reliable_intervals`, hesaplama sürümü 1) kaynakları mevcut Planet yayın işleme hattına bağlandı. Sunucu kaynak sahipliğini, yayın kimliğini, dosya yolunu, şema/sürüm metadatasını ve reliable telemetri kanıtını doğrulamadan puanlama yapmaz. Schema 1 kaynaklarındaki legacy v1 puanlama korunur; karma schema karşılaştırması açıkça reddedilir. Bu kabul yalnız yerel/sentetik işlem kodunu kapsar; hosted PROD/DEV yayını veya istemci tarafındaki Planet yayınını etkinleştirmez.

## Uygulanan davranış

- `process-world-publish` schema 1 ve 2 kaynaklarını kabul edecek biçimde genişletildi. Schema 2'de reliable skor, derlenmiş Dart `calculateReliable()` köprüsüyle hesaplanır; kaynakta sunulan hazır skor kullanılmaz.
- Schema 2 kaynak doğrulaması GPS kopma işaretlerinin ham rota ve kanonik telemetride eşleşmesini, güvenilirlik politikasını, zaman aralığını, mikro saniye sırasını ve telemetri kalite alanlarını kontrol eder.
- Mapbox eşleştirmesi açık rota kopmalarında eşleşmeyi böler; GPS boşluğu tek kesintisiz rota olarak birleştirilmez.
- Schema 1 ↔ 2 kıyaslaması `world_score_mixed_source_modes` ile reddedilir. Yetersiz reliable telemetri `world_score_telemetry_insufficient` veya kaynak doğrulama hatasıyla kapalı kalır.
- Reliable skora yetersiz/güvenilmez pencere katkı yapmaz ve bu pencere kazanan bölgesini GPS boşluğu boyunca birleştiremez. Mevcut 3 km karşılaştırma, 2 km kazanan bölge ve World generation/CAS/idempotency kuralları değişmedi.
- Boş Planet ilk yayınının üretim RPC çağrısı ve sentetik kabul testi aynı `commitEmptyWorldPlan` yardımcı yolunu kullanır.

## Doğrulama

| Kontrol | Sonuç |
|---|---|
| Process-world-publish + Planet trace detail hedefli Deno regresyonları | **PASS — 160/160, exit code 0** |
| Yeni schema 2 işlem uçtan uca sentetik testleri | **PASS — 4/4**, pakete dahil |
| Planet trace detail Dart bundle/hash ve schema 2 testleri | **PASS — 12/12**, pakete dahil |
| Legacy v1 skor, World mutation ve sınır parity testleri | **PASS**, 160 testlik pakete dahil |
| Hedefli Flutter My World / Drive Score / upload ve reliable contract testleri | **PASS — 177/177, exit code 0**; final bundle'dan sonra skor/parity alt kümesi ayrıca **58/58 PASS** |
| `flutter analyze --no-pub` | **3 warning + 4 info; önceki 3 warning + 4 info baseline ile eşleşiyor**. Exit code 1 lint baseline nedeniyle; bu değişiklikten yeni bulgu yok |
| `git diff --check` | **PASS** |
| `deno check .../index.ts` | **NOT RUN TO COMPLETION** — import edilen `npm:@supabase/supabase-js@2` registry DNS ile alınamadı; süreç exit 1. İşlem stage/helper testleri ise Deno paketinde çalıştı |
| Deno npm bağımlılığı kullanan `edge_boot`, `auth` ve `validation_payload` testleri | **NOT RUN** — bu ortamda npm registry/DNS erişimi yok; uzak bağımlılık indirmeden çalışma koşulu korunarak dışarıda bırakıldı |
| Hosted Supabase/Mapbox/Storage ve gerçek Edge handler kabulü | **NOT TESTED** — hosted bağlantı/yayın yapılmadı; işlem ve RPC sınırları sentetik sağlayıcılarla test edildi |
| Gerçek cihaz ve istemci yayın kabulü | **NOT TESTED** — bu aşamanın kapsamı dışında |

Yeni Deno testlerinde skip yoktur. Sentetik testler gerçek kaynak doğrulama, Mapbox route-preprocessing kodu, aktif-yol çakışma, Dart skor köprüsü, winner planning, boş dünya RPC sözleşmesi, generation CAS ve tekrar işleme davranışını çağırır. Bunlar gerçek hosted servis kabulü yerine geçmez.

## Kapsam dışı / güvenlik sınırı

- PROD Auth, Planet yayınlama, Edge deployment veya migration açılmadı.
- Kişisel bulut, Group Drive, hesap silme, R1 signing ve hukuki onboarding değişmedi.
- Eski skorlar veya sürüş kayıtları yeniden hesaplanmadı/değiştirilmedi.
- Eski v1 ve yeni schema 2 katkıları karıştırılmaz; uyumlu olmayan kaynak kıyaslaması başarısız olur.

## Değişiklik doğrulaması

Generated skor bundle'ları mevcut Dart builder'larla yeniden üretildi; manifest hash'leri builder çıktısıyla eşleşiyor. Algoritma ağırlıkları değiştirilmedi. Son checkpoint bilgisi, testlerin tamamlanmasından sonra eklenecektir.
