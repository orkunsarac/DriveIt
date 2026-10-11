# Aşama 5 / Teslimat 3 — Fiziksel Android kabul ve kapanış denetimi

Tarih: 12 Ekim 2026. Branch: feature/gps-refactor.
HEAD: f68445cb7038e50b95f0da139fc7b7b307267105.
Önceki bütün Aşama 5 değişiklikleri korundu. Production ownership gate KAPALI.
Fiziksel kontroller yalnız izole test paketinde yapıldı; gerçek uygulamanın
verileri okunmadı. Native ve host test kapsamları aşağıda ayrı tutulmuştur.

## A. Cihaz ve paket güvenliği

ADB cihazı R5CX42V8GSJ: SM-A556E, Android 16, API 36; authorized/device.
Gerçek paket com.example.driveit_project başlangıçta kuruluydu.
Yalnız com.example.driveit_project.isolated_test debug APK kullanıldı.
SDK aapt badging ile applicationId ve debug niteliği doğrulandı; versionCode=1,
versionName=1.0.0. Normal release/debug package kimliği değiştirilmedi.

Her native hedef öncesinde ilgili hedefle isolated define içeren APK derlenip SDK
kimlik doğrulaması yapıldı. Runner aynı hedef ve define ile, açık cihaz seri numarası
ve --no-uninstall kullanarak seri çalıştı. APK yanlış kimlikteyse script durur.
Testler app.main() çağırmaz; ayrı applicationId ayrı Android sandbox/UID sağlar.
Sentetik Hive/SQLite dosyaları yalnız yeni geçici test köklerinde oluşturulur.

Flutter SDK denetimi: commands/test.dart uninstall varsayılanı true;
integration_test_device.kill hedef paketi durdurur ve uninstall bayrağına göre kaldırır.
--no-uninstall test sonu kaldırmayı kapatır. AndroidDevice.installApp ilk kurulum
başarısızsa hedef APK paketini kaldırıp tekrar kurabilir; bu nedenle bu bayrak
kurulumdaki fallback uninstall için genel garanti değildir. Asıl güvenlik sınırı,
önceden doğrulanmış isolated applicationId'dir. Gerçek paket runner hedefi olmadı.

SupabaseBootstrap.isIsolatedAndroidTest gerçek initialize işlemini engeller;
native finalization testi initializeIfConfigured=false sonucunu doğruladı.
DEV/PROD config geçirilmedi, fake Auth ve synthetic matcher kullanıldı.
GPS test üreticisi fiziksel konum okumaz; Android GPS'e sahte konum enjekte edilmedi.
Harita/widget sınır testlerinde map renderer fake; Google Maps native görsel/yol
kabulü geçti sayılmaz. Üretim feature gate veya main aktivasyonu değiştirilmedi.

## B. Arşiv Android kabulü

- Gerçek Android cihaz doğrulama prompt iptali: geçti.
- Gerçek cihaz credential/biometri başarı yanıtı: geçti; kullanıcı manuel doğruladı.
  PIN/parmak izi atlatılmadı, credential sorulmadı/loglanmadı.
  Başarı hangi yöntemin kullanıldığını kanıtlamaz; PIN ve biometri ayrı ayrı geçti
  iddiası değildir.
- device_archive_boundary_android_test: 20/20 geçti. Gerçek isolated Android
  sandbox'ta sentetik eski Hive kayıtlarıyla History → arşiv → detay → GPS haritası,
  tam rota/veri okuması, kaynak bytes değişmezliği, direct ID, invalid snapshot,
  restart/reopen, gate OFF, epoch/background/expiry ve geç gelen auth sonucu sınırları.
  Bu grupta cihaz authorizer fake'dir; lifecycle olayları test binding tarafından
  gönderilir. Gerçek Home/lockscreen kabulüyle eşdeğer değildir.
- Ek gerçek credential → archive context testi 1/1 geçti. Kullanıcı Android
  doğrulamasını tamamladıktan sonra current capability, sentetik arşiv listesi,
  detay, GPS rota widget'ı ve Auth A→B erişim iptali doğrulandı. Kaynak drives.hive
  dosyasının önce/sonra bytes'ları birebir aynıydı. Bu testte map renderer fake'dir;
  Google Maps native görsel kabulü değildir. Entry doğrudan arşiv ekranıdır;
  History giriş zinciri ayrıca 20-test sınır grubunda doğrulandı.
- Gerçek Home/ekran kilidi lifecycle kabulü `device_archive_lifecycle_android_test.dart`
  ile 1/1 geçti: cihaz doğrulaması → arşiv liste/detay/rota; Home'a gönderme → Son
  Uygulamalar'dan izole uygulamaya dönüş → yeni cihaz doğrulaması; ardından ekranı
  kilitleyip açınca eski archive context'in geçersiz kalması. Auth A→B geçişinde de
  capability iptali doğrulandı. Gerçek auth prompt ve Home/lock lifecycle kullanıldı;
  sürüş/Hive kaydı sentetiktir, harita renderer'ı fake'dir. Üretim uygulama verisi
  okunmadı.
- Yanlış PIN denemesi/biometri lockout fiziksel kabulü yapılmış sayılmadı.
  Host provider testleri hata/lock yok/cancel durumlarını fail-closed doğrular.
- Eski World/Career/poster/profile/outbox hesap importu çalıştırılmadı.

## C. Yeni sürüş native kabulü

`owned_drive_ui_android_test.dart`: 1/1 geçti. Gerçek `/drive` ekranından başlayan
sentetik owner A akışı gerçek Android foreground-task servisini, kalıcı owner/session/
source UUID doğrulamasını, journal yazımını, Stop→Save, owner Hive read-back, History/
detay/rota, Score, World trace ve exactly-once Career katkısını kapsadı. 301 sentetik
GPS örneğiyle 6 km rota kullanıldı; tekrar save duplicate üretmedi; A→B izolasyonu ve
A'ya dönüş doğrulandı. Bu, gerçek cihaz konum/GPS hareketi veya gerçek kullanıcı
sürüşü değildir.

owned_drive_finalization_android_test: 1/1 geçti. Gerçek Android headless
foreground FlutterEngine ve native sqflite iki servis oluşturulmasında aynı
descriptor/sidecar/session/source UUID'yi doğrular. Sentetik 301 nokta, sequence
1..301, 6 km. Durmuş producer sonrası gerçek ForegroundService.stop ve
DriveStorageService.saveDrive → owner transfer/finalizer kullanıldı.

Native read-back: owner History/route 301 nokta, telemetry 301 nokta, Score mevcut,
World trace mevcut (synthetic road matcher), Career 6000 m ve exactly-once save retry.
Sidecar receipt doğrulandı; gerçek acknowledgeSaved koşulları geçti.
A→B→A dönüşünde kayıtlar doğru owner'da kaldı.
Journal v3 korunur; owner sidecar v3 kullanılır.

Sınır: konum örnekleri sentetiktir; fiziksel GPS hareketi, saha rotası veya güç
kesintisi denenmedi. Native akış gerçek `/drive` UI ve foreground-task servisinden
başladı; platform konum alıcısı yerine testin sentetik GPS kaynağı kullanıldı.

## D. Guest/A/B izolasyonu

Native finalization A→B→A disk/repository izolasyonunu doğruladı.
World/poster grubu 24/24, kişisel ekran grubu 14/14, native owner lifecycle
guest→A→B→restart→A→guest disk/epoch/consent sınırı 1/1 geçti.
Host tam regresyon guest→A, A/B aynı local ID, delayed Future,
epoch revocation, History/Score/World/Career/poster/outbox sınırlarını içerir.
Guest verisi Auth ile otomatik hesaba atanmaz; eski cihaz arşivi account History'ye
karışmaz. Normal owner katkıları legacy revision/merge'e bağımlı değildir.

## E. Recovery / crash / hata kapsamı

Native GPS/SQLite grubu 8/8 geçti: WAL/FULL/timeout, v1/v2→v3 upgrade, orijinal
nokta/quality/zaman read-back, güvenli stop/transfer ve headless recreation.
Bu gruptaki eski Android PRAGMA execute kullanımını yeniden üreten test beklenen
SQLite exception'ını gözlemledi; güncel kod arızası değildir.
Native sentetik foreground stop/recreate iki headless engine üzerinde aynı kimlik
ve sequence zincirini korudu; scoped native SQLite/Hive close-reopen ve duplicate
transfer testi 1/1 geçti. Son testte eski v1 sidecar beklentisi güncel v3'e düzeltildi;
veritabanı formatı/runtime bu nedenle değiştirilmedi.

Host testler stopped source, service continue, interrupted save close/reopen,
World/Career/Score flush hatası, receipt/sidecar/provenance çatışması,
external Auth değişimi, pending completion reconciliation ve writer drain
başarısızlığında fail-closed/idempotency'yi kapsar.
`owned_drive_process_kill_android_test.dart` prepare/recover aşamaları 1/1'er geçti.
Hazırlık fazında izole uygulama sürecinde 16 sentetik journal örneği ve session/
owner/source UUID kalıcılığı doğrulandı; Android ActivityManager'ın `cmd activity
crash --user 0` kontrollü süreç-crash yolu ile uygulama süreci sonlandırıldı, ardından
ayrı recovery çalıştırması aynı kimliği ve 16 örneği doğruladı. `kill -9` izin
reddi nedeniyle kullanılmadı; force-stop, servis stop veya güç kesintisi yapılmadı.
Bu gerçek Android uygulama-process crash/recovery kanıtıdır; kernel seviyesinde
zorla öldürme ve fiziksel power-loss kanıtı değildir. Kontrollü exception veya
close/reopen testleri de gerçek OS process-kill/power-loss ile eşdeğer değildir.
SQLite/Hive/dosya sistemi arasında tek transaction yoktur. World/Career doğrulanmış
katkıları son History completed işaretinden önce kalıcılaşabilir; rollback edilmiş
sayılmaz, aynı immutable kaynakla retry gerekir. Eski owner verisine fallback yok.

## F. Gerçek uygulamanın korunması

Gerçek uygulamanın dosyaları, sürüşleri ve izinleri okunmadı/değiştirilmedi.
Asıl pakete install/uninstall/force-stop/pm clear uygulanmadı.
Yalnız paket varlığı ve cihaz sistem bilgisi salt okunur kontrol edildi.
Son kontrolde asıl paket hâlâ kurulu ve başlangıçtaki APK path'i aynıydı;
izole paket ayrı kurulu kaldı. Gerçek kayıtların byte hash'i ölçülmedi: gerçek
dosyalara erişilmeden içerik doğrulaması yapılmış olduğu iddia edilemez.
Tam gerçek kullanıcı yedeği alınmadı; alınmış olduğu iddia edilmez.
Test cleanup sadece kendisinin oluşturduğu sentetik geçici kökleri kaldırır.

## G. Regresyon sonuçları

Yeni tam koşu: flutter test --timeout=2m — **887 geçti, 2 koşullu
atlandı, 0 başarısız**, exit 0, yaklaşık 2 dakika 15 saniye. Önceki sonuç kopyalanmadı.
Atlananlar: Windows sentetik symlink oluşturma kısıtı; explicit isolated define
gerektiren backend guard. Android World/poster suite symlink testini çalıştırdı.
Backend guard ayrıca sahte .invalid URL ve sentetik public key ile hedeflendi:
**1/1 geçti**; yapılandırma verilse bile izole testte Supabase başlatılması engellendi.
Bu ek hedefli koşu, normal tam paketin 2 koşullu atlama sayısını değiştirmez.

Analyze: mevcut **4 info**, error/warning yok, exit 1 (info nedeniyle), 73.8 saniye:
home_screen.dart:738, map_screen.dart:921 ve 1149, route_preview.dart:32.
Yeni native harness dosyalarında yeni analyzer bulgusu yok.
git diff --check: exit 0. Android ve host runner'lar seri çalıştırıldı.

Yerel kanıt logları build/phase5_native_scoped.log,
build/phase5_native_credentials.log, build/phase5_native_archive_context.log,
build/phase5_native_finalization.log, build/phase5_*_android_test.log,
build/phase5_final_acceptance_flutter.log, build/phase5_final_acceptance_analyze.log
ve build/phase5_final_acceptance_diff_check.log. Loglar/build çıktıları Git adayı değildir.

## H. Yeni bulgular / bu tur değişen dosyalar

- integration_test/owner_scoped_storage_android_test.dart: obsolete sidecar
  getVersion()==1 beklentisi 3 olarak düzeltildi.
- integration_test/device_archive_credentials_android_test.dart: gerçek system
  credential iptal/başarı ve sentetik arşiv capability kabul harness'i.
- integration_test/device_archive_boundary_android_test.dart: mevcut arşiv
  synthetic boundary/ekran testlerinin isolated Android wrapper'ı.
- integration_test/owned_drive_finalization_android_test.dart: gerçek foreground
  headless engine + native sqflite → owner finalization kabul harness'i.
- integration_test/owned_drive_ui_android_test.dart: gerçek `/drive` UI/foreground
  service başlangıcından sentetik owner-scoped sürüş kabulü.
- integration_test/owned_drive_process_kill_android_test.dart: process-crash
  prepare/recovery fazları için sentetik kalıcı journal doğrulayıcısı.
- integration_test/device_archive_lifecycle_android_test.dart: gerçek cihaz
  doğrulaması, Home/Recents dönüşü, lock/unlock ve archive capability iptali.
- docs/phase5_final_android_acceptance.md: bu rapor.

Arşiv lifecycle testinde tekrar doğrulama sonrasında eski expired widget'ın test
Navigator ağacında kaldığı görüldü. Sentetik snapshot ve yeni context geçerliydi;
testte birbirinden ayrı `MaterialApp` anahtarları eklenerek önceki Navigator state'inin
yeniden kullanılmaması sağlandı. Üretim arşiv/runtime kodu değiştirilmedi.

Yeni harness ilk derlemesindeki decode Future await eksikliği düzeltildi ve ilk
başarısız build logu saklandı; bu uygulama runtime hatası değildir.
Production runtime, journal şeması, Score/World algoritmaları bu tur değiştirilmedi.
Gradle mevcut flutter_foreground_task Kotlin plugin gelecekteki Flutter uyumluluk
uyarısını veriyor; bu test arızası değil, ileri sürüm teknik riski.
Git fsmonitor IPC ortam uyarısı için salt-okunur komutlarda -c core.fsmonitor=false
kullanıldı; repo ayarı değiştirilmedi.

## I. Gerçek üretim aktivasyonu için zorunlu koşullar

1. Gerçek kaydedilmiş sürüşler + orijinal rota/telemetry kaynakları için Android'in
   izin verdiği doğrulanmış yedek/export; sayı, ID ve hash/read-back doğrulanmalı.
   JSON dışa aktarmak tüm uygulama dosyaları/yapısal yedek demek değildir.
2. Kullanıcı eski sürüşlere ayrı salt-okunur cihaz arşivinden ulaşmalı. Başka hesabın
   login olması cihaz yetkisi sayılmamalı. Gerçek kaynak snapshot writer drain ile
   alınmalı, kaynaklar silinmemeli. Kilitsiz cihaz erişimi fail-closed.
3. Native credential → archive context → liste/detay/harita, gerçek Home/Recents ve
   lock/unlock sonrası iptal/yeniden doğrulama kabulü geçti. `/drive` UI → gerçek
   foreground-task servisi → save akışı da sentetik GPS ile geçti. Canlı GPS hareketi,
   physical power-loss ve credential lockout/yanlış PIN kabulü ayrı kapsam dışıdır.
4. Guest/A/B owner isolation, immutable GPS owner ve receipt/read-back eksikliği
   halinde source retention; aktif sürüşte hesap değişimi güvenli engellenmeli.
5. Rollout bootstrap/Auth/scoped dependencies açıkça tamamlanıp kabul edilmeden
   yalnız gate flip yapılamaz. main şu an legacy bootstrap'a gider; test attachment
   gerçek rollout wiring'in kanıtı değildir. Legacy merge yeni kapsamda şart değildir.
6. Rollback: gate OFF data conversion değildir. Sidecar/owner-scoped kayıtlar eski
   APK tarafından tanınmayabilir. Eski APK'ya dönmek bu kayıtları ortak Hive'a
   tahminen yazma hakkı vermez. Yedek ve format uyumluluğu doğrulanmış rollback
   sürümü gerekir; yeni owner dosyaları/journal korunmalı, otomatik clear/reset yok.

## J. Checkpoint hazırlığı / dosya envanteri

Branch/HEAD değişmedi. Stage, commit veya push yapılmadı; index boş.
Değişmiş/yeni kaynak-test-doc/pubspec adaylarında APK, Hive/SQLite kullanıcı payload'u,
private key/GitHub token/secret-key biçimleri görülmedi. Bu bir biçim taraması ve
diff kapsam denetimidir; her olası credential için matematiksel garanti değildir.
Config veya gerçek kullanıcı dosyaları taramaya/commit listesine katılmadı.

android/build/, android/.kotlin/, build/ test log/APK'ları ve ilgisiz tatus
kesinlikle checkpoint adaylarından dışlanmalıdır. Bunlar silinmedi.
Aşağıdaki liste çalışma alanındaki checkpoint sonrası 72 Phase 5 adayını içerir;
bu raporla toplam 73 kaynak/test/dokümantasyon/pubspec adayı vardır.
Önceki kapalı legacy revision/import kodu korunmuştur,
çalıştırılmamıştır. Kontrollü git add -A kullanılmamalı.

```text
android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/example/driveit_project/MainActivity.kt
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/values-v31/styles.xml
android/app/src/main/res/values/styles.xml
docs/android_isolated_integration_tests.md
docs/driveit_requirements.md
docs/foreground_owner_handoff_5c2g2c2.md
docs/gps_provenance_end_to_end_5c2g2c1.md
docs/owner_import_revision_5c2g2.md
docs/owner_import_visibility_contract.md
docs/owner_import_world_career_merge_5c2g2b.md
docs/owner_provenance_foundation_5c2g2c.md
docs/phase5_completion_replan.md
docs/phase5_drive_archive_acceptance.md
docs/phase5_drive_archive_delivery.md
docs/phase5_owned_drive_delivery.md
integration_test/device_archive_boundary_android_test.dart
integration_test/device_archive_credentials_android_test.dart
integration_test/owned_drive_finalization_android_test.dart
integration_test/owned_foreground_bootstrap_android_test.dart
integration_test/owner_scoped_storage_android_test.dart
lib/config/supabase_bootstrap.dart
lib/features/drive_poster/poster_screens.dart
lib/features/drive_poster/poster_store.dart
lib/features/drive_score/services/drive_score_persistence_coordinator.dart
lib/features/my_world/repositories/world_source_snapshot_repository.dart
lib/screens/device_drive_archive_screen.dart
lib/screens/drive_detail_screen.dart
lib/screens/history_screen.dart
lib/screens/map_screen.dart
lib/screens/owned_drive_screen.dart
lib/services/android_device_archive_authorizer.dart
lib/services/career_contribution_repository.dart
lib/services/device_drive_archive.dart
lib/services/drive_source_provenance_repository.dart
lib/services/drive_source_provenance.dart
lib/services/drive_telemetry_storage_service.dart
lib/services/foreground_service.dart
lib/services/gps_session_ownership.dart
lib/services/gps_session_store.dart
lib/services/gps_session_transfer.dart
lib/services/legacy_account_import.dart
lib/services/legacy_asset_transfer.dart
lib/services/legacy_claim_ledger.dart
lib/services/local_owner_gps_bridge.dart
lib/services/local_owner_lifecycle.dart
lib/services/local_source_bundle.dart
lib/services/owned_drive_finalization.dart
lib/services/owned_foreground_bootstrap.dart
lib/services/owned_gps_session_coordinator.dart
lib/services/owner_revision_models.dart
lib/services/owner_revision_repository.dart
lib/services/owner_scoped_local_store.dart
lib/services/scoped_gps_transfer_sink.dart
lib/widgets/drive_summary_dialog.dart
lib/widgets/owner_personal_navigator.dart
pubspec.lock
pubspec.yaml
test/android_device_archive_authorizer_test.dart
test/device_drive_archive_test.dart
test/drive_source_provenance_test.dart
test/gps_session_ownership_test.dart
test/isolated_android_backend_guard_test.dart
test/local_owner_bootstrap_writer_test.dart
test/local_owner_integration_test.dart
test/owned_drive_delivery_test.dart
test/owner_personal_screen_test.dart
test/owner_revision_repository_test.dart
test/owner_world_poster_boundary_test.dart
test/scoped_gps_transfer_test.dart
docs/phase5_final_android_acceptance.md
```

## K. Son kontrol / karar

Native sonuç: önceki native gruptaki 72 test ile bu son turdaki 4 kabul çalıştırması
birlikte **76/76 geçti, 0 başarısız, 0 atlandı**:

| Test grubu | Geçen |
| --- | ---: |
| Native scoped SQLite/Hive transfer | 1 |
| Gerçek device auth iptal + başarı | 2 |
| Gerçek device auth → archive context/route | 1 |
| Archive Home/Recents + lock/unlock revocation | 1 |
| `/drive` → foreground → owner save/History/Score/World/Career | 1 |
| Process-crash prepare + recovery | 2 |
| Native foreground → finalization/Score/World/Career | 1 |
| Sentetik archive boundary/ekran zinciri | 20 |
| World/poster owner boundary | 24 |
| Kişisel ekran owner boundary | 14 |
| Native GPS/SQLite | 8 |
| Native guest/A/B lifecycle/reopen | 1 |

Tam host: 887 geçti / 2 atlandı / 0 başarısız.
Analyze: mevcut 4 info; diff check başarılı.

**Aşama 5 kod ve kontrollü native kabul: EVET (yalnız sentetik/izole kabul kapsamı).**
Üç açık senaryo da izole pakette geçti: birleşik `/drive` owner-scoped sürüş akışı,
ActivityManager ile kontrollü gerçek uygulama-process crash ve ayrı recovery,
gerçek Android auth prompt + Home/Recents + ekran kilidi sonrası arşiv capability
iptali. Gerçek DriveIt paketi kurulu kaldı; gerçek uygulama verisi okunmadı veya
değiştirilmedi. Production ownership gate KAPALI; bu kabul gerçek kullanıcı
migrasyonu veya gate aktivasyonu izni değildir. Canlı GPS hareketi, fiziksel güç
kesintisi ve credential lockout/yanlış PIN native kabulü yapılmadı. Legacy full
merge yeni kapsamda şart değildir. Supabase, gerçek import, stage/commit/push yok.
