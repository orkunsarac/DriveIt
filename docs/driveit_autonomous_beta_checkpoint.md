# DriveIt otonom geliştirme — beta hazırlık checkpoint'i

Tarih: 3 Kasım 2026. Başlangıç: `f97ad26`, branch `feature/gps-refactor`.

## Durum özeti

| Paket | Sonuç | Kanıt / sınır |
|---|---|---|
| R6-B5 yedek/restore | **PASS** | DPAPI CurrentUser ile şifreli, repo dışı, 80 dosyalı DEV yedeği; SHA-256 `12be62b9fe92b7f262705a1407ae602dbc25d36bc4b51543d270b32df4d24a2f`. Ağsız PostgreSQL restore ve katalog/veri eşleşmesi. Storage dosya baytları checksum ile restore edildi; bu artifact için Storage API'ye yeniden yükleme testi yapılmadı. |
| R6-B5 yerel migration provası | **PASS** | Ayrı restore kopyasında 52 migration; Group Drive gate false; 20 finalized manifest aynı; yeni public tabloların RLS'i açık; rollback-only Group/Deletion testleri ve service-role deny testi geçti. |
| R6-B5 DEV migration + Function | **PASS (dağıtım kapsamı)** | Yalnız `viqngnjfgknpxtoapzcg`: 52 migration, gate false; yalnız `delete-account` v1, `verify_jwt=false`; worker secret yapılandırıldı; cron yok. Diğer Function kod hash'i/zamanı aynı. |
| Gerçek DEV hesap silme / receipt | **BLOCKED** | Geçici sentetik A/B hesap ve gerçek Auth/Storage/receipt/purge HTTP kabulü yapılmadı. API key değerlerini CLI ile alma girişimi otomatik inceleme tarafından reddedildi; güvenli başka bir credential yolu yoktu. Önceden kalan R6-A Account A'ya dokunulmadı. |
| Planet gerçek DEV kabulü | **BLOCKED** | Gerçek DEV Auth, map/publish/validation ve owner izolasyonu HTTP testleri yapılamadı; aynı DEV API key sınırı. Yerel/sentetik Deno ve Flutter testleri PASS, hosted kabul yerine geçmez. |
| Android Auth/GPS yaşam döngüsü | **PARTIAL** | Emülatör Android user 10'da, kimliği doğrulanmış `com.example.driveit_project.isolated_test` ile force-stop/start: `SAVED_EXPIRED → ROTATED owner=A → RESTORED owner=A`. Gerçek Supabase SDK/Android secure storage/owner bootstrap; HTTP MockClient sentetik. İzole debug APK derlemesi exit 0 ile PASS. A55 bağlı değildi; gerçek cihaz kabulü yapılmadı. |
| Play kapalı beta hazırlığı | **PARTIAL** | Önceki AAB üzerinde doğrulamalar var; bu oturumda güncel koddan yeni imzalı AAB üretilmedi. R1 signing sırları bulunmadı. Play Console'a yükleme/yayın yok. |

Detay: [R6-B5 DEV rollout acceptance](r6b5_dev_rollout_acceptance.md), [Play closed beta hazırlığı](play_closed_beta_preparation_20261103.md), [R1 kimlik kabulü](pgr7f_play_identity_acceptance.md).

## Yeni teknik testler

- Deno Planet/schema2/publish/scoring/map/geojson: **77 PASS / 0 FAIL**.
- Deno account-deletion Planet replay: **10 PASS / 0 FAIL**.
- Flutter Planet/owner/profile/upload/download/account-deletion lifecycle hedefli testleri: **53 PASS / 0 FAIL**.
- `flutter analyze --no-pub`: exit 1, analyzer error yok; 3 warning ve 4 info (önceden bilinen `integration_test/device_archive_*` unnecessary non-null assertion warning'leri dahil). Tam regresyon R6 kapsamına bırakıldı.
- Supabase DEV ile son rehearsal kıyaslaması: 7 katalog kategorisi + `extensions` owner/ACL + 9 aggregate fingerprint eşit.
- Sonradan eklenen PowerShell wrapper regresyonu: 52/52 migration kaynağı hash doğrulandı; tek dış transaction, migration gövdesi ve ledger kaydı beraber kapsanıyor.
- `tool/test_play_release_guards.ps1`: normal debug APK build + `com.example.driveit_project` kimliği + konum/foreground-service izinleri PASS; izole APK build + `.isolated_test` kimliği PASS; imzasız release, eksik signing, DEV Supabase release ve Play modunda debug build redleri PASS. Flutter SDK cache dizinine yazma için yükseltilmiş izin gerekiyordu; signing sırrı kullanılmadı.

## Yayın engelleri

1. **Hukuki onboarding gate:** KVKK, gizlilik ve koşullar `pending_legal_review`; onay/sürüm/referans boş. Yeni kurulum onboarding 4/6'da duruyor. Hukuken onaylı, sürümlü ve yayınlanabilir metin/URL gerekir. Bu gate kaldırılmadı.
2. **Signing:** Yeni commit'e ait production/upload-signed AAB yok. Signing secret'ları mevcut olmadığı için tahmin edilmedi; R1 keystore değiştirilmedi. Önceden var olan AAB yeni build sayılmaz.
3. **DEV Auth signup:** Güncel DEV Auth `disable_signup=false`; değiştirilmedi. Signup kapalı olmalıysa bu ayrı, açık DEV config onayı gerektirir. PROD config'e dokunulmadı.
4. **R6-B5 gerçek DEV A/B testi:** API key değerlerinin kullanılmasına yönelik güvenlik incelemesi onayı gerekir veya anahtar vermeden çalışan yetkili bir test yolu sağlanmalıdır. Bu izin olmadan test hesabı oluşturulmadı.
5. Gerçek DEV Planet/receipt kabuli, fiziksel A55 kabuli, Play Console/Data Safety, erişilebilir gizlilik ve silme sayfaları, onaylı destek adresi ve hukuki iletişim/saklama bilgileri bekliyor.

## Koruma ve Git durumu

- PROD'da migration, Function, Auth/SMTP veya kullanıcı değişikliği yapılmadı. PROD/Play yayın başlatılmadı.
- A55'in normal DriveIt uygulamalarına/verilerine, R1 signing dosyalarına ve gerçek sürüş/GPS kayıtlarına dokunulmadı.
- DEV yedeği ve worker secret değeri GitHub'a konmadı. DEV signup ayarı değiştirilmedi.
- Yalnız R6-B5 araçları ve bu checkpoint dosyaları stage/commit edilecek; önceden kirli `.gitignore`, Gradle, `pubspec.lock`, Supabase cache ve diğer untracked işler korunacak.
- Canlı DEV migration dağıtımında SQL ile ledger INSERT'inin her dosya için atomik olduğu doğrulanmadı; sonradan düzeltilen ve test edilen wrapper geçmiş dağıtımı yeniden çalıştırmadı. Ayrıntı R6-B5 rollout raporunda.
- Son GitHub checkpoint'i bu dosya commit edildikten sonra rapora eklenecek.

## Sonraki en yüksek öncelik

DEV için yetkili API test kimlik bilgisi veya secrets açmadan çalışan kontrollü A/B test yolu edin; sonra yalnız yeni sentetik hesaplarla resmi delete-account request/receipt/purge HTTP kabulini yap. Ayrı olarak signup'ın kapatılması için DEV config onayı, hukuki belgeler ve signing girdileri gerekir.
