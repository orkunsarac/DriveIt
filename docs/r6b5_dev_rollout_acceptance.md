# R6-B5 — DEV yedek, migration ve delete-account dağıtımı

Tarih: 3 Kasım 2026. Başlangıç checkpoint'i: `f97ad26` (`feature/gps-refactor`). Kapsam yalnız DEV `viqngnjfgknpxtoapzcg`; PROD ve Android uygulama verileri değiştirilmedi.

## A1 — Şifreli yedek ve izole restore: PASS (saklama sınırları belirtilmiştir)

- Repository dışında `%LOCALAPPDATA%\DriveIt\Recovery\R6B5-DEV-20261103-085654-8b8b13f2\driveit-dev-r6b5.zip.dpapi` üretildi. Windows DPAPI CurrentUser şifrelemesi, korumalı User/SYSTEM ACL ve arşiv SHA-256 `12be62b9fe92b7f262705a1407ae602dbc25d36bc4b51543d270b32df4d24a2f` doğrulandı. Yedek veya secret değeri repository'ye alınmadı.
- Arşivde 80 doğrulanmış dosya var: rol dökümü; DB schema/data; 22 migration ledger satırı; 16 Auth kullanıcısının verisi; 7 event trigger ve `rls_auto_enable()`; extensions şema ACL'i; tüm default ACL; Function kaynak/enventory metadata'sı; 2 Storage bucket'ındaki 49 nesnenin metadata'sı ve nesne baytları. Nesne dosyaları arşivden ayrı, ağsız restore çalışma alanına çıkarıldı ve her payload SHA-256 ile doğrulandı.
- Arşiv metadata'sı uzaktaki DEV katalog/veri fingerprint'leriyle export öncesi/sonrası eşleşti. İzole PostgreSQL 17.11 restore'u baseline 22 migration, 7 event trigger, 49 Storage dosyası ve 16 Auth hesabıyla tamamlandı. Restore ile DEV katalog karşılaştırmasındaki eksik `extensions_schema` owner/ACL anahtarı düzeltildi; extensions owner/ACL yerel kopyada da ayrıca doğrudan doğrulandı.
- Kurtarma sınırı: Supabase'in extension binary'leri, Function secret değerleri ve Auth/SMTP/harici sağlayıcı ayarları yedekte yoktur; bunlar ayrıca yeniden kurulmalıdır. Export tek bir veritabanı transaction'ı değildir; tutarlılık pre/post metadata ve fingerprint eşleşmesiyle kontrol edildi. Yeni artifact'in dosya baytları doğrulandı; bu koşuda yeni yerel Supabase Storage servisine API üzerinden yeniden yükleme yapılmadı. Önceki R6-B3 Storage restore kabulü korunur, fakat bu artifact için API düzeyinde rehydration yeniden doğrulanmadı.

## A2 — Backup-copy migration provası: PASS

- Korunan baseline restore DB değiştirilmeden, aynı çevrimdışı container içinde ayrı `driveit_r6b5_migration_rehearsal_b` veritabanı oluşturuldu.
- 2 Planet bootstrap kaydı, 22 mevcut ledger satırı ve onaylı 122/122 Planet bootstrap parity kanıtı temelinde yalnız ledger'a uzlaştırıldı. Bootstrap SQL tekrar çalıştırılmadı.
- `202610310001_phase8_m4_server_gate.sql` ilk uygulandı; `phase8_group_rollout.enabled=false` doğrulandı. Ardından 25 deletion migration'ı ve 2 düzeltme migration'ı sırasıyla hash kontrolüyle uygulandı. Ledger 52 satıra ulaştı.
- 20 finalized manifest'in önce/sonra sayısı ve fingerprint'i aynı kaldı. 4 yeni public tablo `ensure_rls` event trigger ile RLS açık oluşturuldu. `r6b2_group_gate_test.sql`, `r6b2_deletion_isolation_test.sql` ve `r6b4_role_runtime_test.sql` geri alınabilir sentetik fixture'larla geçti; service-role deny baseline değişmedi.
- Canlı DEV ile son 52-migration rehearsal kopyası arasındaki 7 katalog dizisi (extension, event trigger, table, policy, trigger, function, default ACL), `extensions` schema owner/ACL'i ve 9 aggregate veri fingerprint'i eşleşti. Kaynak PostgreSQL 17.6; restore imajı 17.11.
- Yerel `tool/test_r6b5_migration_wrapper.ps1` sonradan eklendi ve 52/52 hash-doğrulanmış kaynak için SQL gövdesi ile ledger INSERT'ini saran tek transaction ürettiğini doğrular. İnceleme, wrapper'ın dağıtım anındaki sürümünün yorum satırlarından sonra gelen `BEGIN` satırını her durumda ayıklamadığını gösterdi. Bu nedenle canlı dağıtımın her migration SQL'i ile ledger INSERT'inin atomik olduğunu iddia etmiyoruz. Remote zincir 52 kayıt ve son katalog/parmak iziyle tamamlandı; migration başarısızlığı gözlenmedi. Wrapper düzeltmesi bundan sonraki yerel provada kullanılmak üzere eklendi; canlı DEV'de yeniden çalıştırılmadı.

## A3 — Kontrollü DEV dağıtımı

- Önkoşullar geçtikten sonra yalnız DEV'e 2 bootstrap ledger reconciliation, M4 server gate ve 27 account-deletion migration'ı (25 + 2 düzeltme) uygulandı. Sonuç 52 migration, Group Drive `false`, deletion RLS açık ve mevcut finalized manifest fingerprint'i değişmemiş olarak doğrulandı.
- Yalnız `delete-account` Edge Function dağıtıldı: Function sürüm 1, `verify_jwt=false`. İç JWT, aynı UID parola doğrulaması, açık silme onayı ve receipt kontrolleri kodda korunuyor. Bir rastgele sentetik UUID ile Auth tokenı olmayan HTTP `request` çağrısı 401 `unauthorized` döndürdü.
- 256-bit `ACCOUNT_DELETION_WORKER_TOKEN` DEV secret'ı olarak ayarlandı. Yerel kurtarma kopyası yalnız DPAPI CurrentUser şifreli ve ACL'i User/SYSTEM ile sınırlı; plaintext geçici `.env` dosyası kalmadı. Secret değeri rapora/repoya yazılmadı. Cron/scheduler başlatılmadı; dağıtım öncesi aktif deletion cron sayısı sıfırdı.
- Function envanterindeki diğer dokuz Function'ın bundle SHA-256 ve `updated_at` değerleri aynı kaldı. CLI sonrası `version` metadata alanı tüm Function kayıtlarında bir arttı; kod hash'i ve güncellenme zamanı değişmedi. Bu platform metadata davranışı ayrıca kaydedildi; diğer Function kaynakları yeniden dağıtılmadı.
- DEV Auth Management API `disable_signup=false` döndürdü (signup mevcutta açık). Bu ayara dokunulmadı. PROD Auth/signup değiştirilmedi. Beta için DEV signup'ının da kapalı olması gerekiyorsa bu ayrı onaylı config adımıdır.

## Gerçek DEV kullanıcı kabulü — BLOCKED

R6-B2 test onayındaki gibi yeni geçici A/B hesapları oluşturulmadı; gerçek parola/receipt/storage/purge HTTP testi çalıştırılmadı. `supabase projects api-keys --reveal` ile API anahtarlarının süreç belleğine alınması, API key değerleri açığa çıkabileceği için otomatik güvenlik incelemesi tarafından reddedildi. Anahtarları başka yoldan almaya çalışılmadı. Bu nedenle yeni hesap/Storage/receipt kabulü, R6-A Account A temizliği ve DEV Planet publish/Auth HTTP kabulü bekliyor. Mevcut Account A'ya dokunulmadı.

## Yerel test kanıtı

- `supabase/functions/delete-account/planet_rebuild_test.ts`: 10/10 PASS.
- Planet/schema2/publish/scoring/map/geojson Deno hedefli testleri: 77/77 PASS.
- `flutter test test/planet_owner_read_integration_test.dart test/world_publish_owner_real_lifecycle_test.dart test/account_deletion_owner_runtime_test.dart test/owner_profile_real_lifecycle_test.dart test/owner_upload_real_lifecycle_test.dart test/owner_download_real_lifecycle_test.dart`: 53/53 PASS.
- Bu testler sentetik/local'dir; gerçek DEV HTTP A/B/Planet kabulinin yerine geçmez.
