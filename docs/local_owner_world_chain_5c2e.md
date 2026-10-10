# Aşama 5C.2E — owner-scoped World zinciri

## Kapsam ve kapalı üretim davranışı

`LocalOwnershipGate.production` KAPALI kalır. Yeni namespace, migration,
import, Auth değişimi veya GPS transferi üretimde etkinleştirilmez. Önceki
5A–5C.2D değişiklikleri korunur; poster oluşturma/picker ve legacy import
görünürlüğü bu aşamanın dışındadır. World rules version 6, 5 km kabul şartı,
overlap, yön, canonical offset, ownership ve GPS boşluğu sunum kuralları
değiştirilmedi.

## Tüketici envanteri ve bağlantılar

- `OwnerPersonalNavigator`: `/world` owner haritasına, `/world-trace` yalnız
  mevcut owner deposundan doğrulanan trace ID detayına gider.
- `MyWorldMapScreen`: scoped read/settings/detail; lease + epoch + World
  revision kontrolü; eski owner cache/polyline/marker/controller temizliği.
  Gecikmiş kamera ve highlight callback'leri iptal/kimlik kontrolü kullanır.
  Aynı generation içindeki tombstone/read değişimi de render cache'ini
  geçersiz kılar; bunun widget regresyonu vardır.
- `OwnedWorldTraceDetailScreen`: dışarıdan verilmiş trace nesnesine güvenmez;
  ID'yi authoritative scoped snapshot üzerinden çözer. History silinmiş olsa
  da bağımsız snapshot ile World detayı açılır; History detayı düğmesi kapalıdır.
- `LocalOwnerLease`: map/detail/rebuild/trace deletion/job enqueue/drain;
  her mutation başlayan owner deposuna sabitlenir. Harici Auth olayı lease'i
  hemen geçersiz kılar; eski işlem yeni hesap ekranına sonuç uygulayamaz.
- `ControlledOwnershipRuntime.processWorldJobs`: açık kontrollü background
  giriş noktası. Pending job kendi store namespace'iyle drain edilir.
  Matching provider açıkça enjekte edilmelidir; ortak/global provider'a
  fallback yoktur. Üretim scheduler'ı veya yeni GPS → score/source hazırlama
  pipeline'ı bu aşamada açılmadı. Scoped harita açılışı salt okunurdur;
  kontrollü yenileme eylemi pending işleri ve rebuild'i çağırır.
- Matched-road presentation mevcut `MyWorldReadService` ve sunum servisini
  kullanır. Kalıcı tombstone read sınırında da uygulanır.

## Bu aşamada değiştirilen dosyalar

- `lib/features/my_world/repositories/hive_my_world_repository.dart`
- `lib/features/my_world/services/my_world_read_service.dart`
- `lib/features/my_world/services/my_world_validation_service.dart`
- `lib/features/my_world/services/world_pending_job_processor.dart`
- `lib/services/local_owner_lifecycle.dart`
- `lib/services/local_ownership_bootstrap.dart`
- `lib/screens/my_world_map_screen.dart`
- `lib/screens/world_trace_detail_screen.dart`
- `lib/widgets/owner_personal_navigator.dart`
- `test/owner_world_poster_boundary_test.dart`
- `test/owner_personal_screen_test.dart`
- `pubspec.yaml`, `pubspec.lock`: mevcut transitive Google Maps platform
  interface sürümü fake-map harness için direct dev dependency yapıldı.
- Bu rapor: `docs/local_owner_world_chain_5c2e.md`.

## Bağımsız silme ve dayanıklılık

Trace silme önce owner kapsamında intent/tombstone yazıp flush eder, sonra
mevcut rebuild algoritmasıyla generation üretir. History, Career ve kabul
edilmiş Planet yayınlarına dokunmaz. Kaynak ancak History yoksa ve bütün
World footprint'leri silinmişse mevcut bağımsız silme kuralıyla kaldırılır.
Eksik doğrulanmış snapshot/road durumunda silme engellenir.

Yarım intent aynı owner'da yeniden denenir. Processing/job kayıt yazımı
owner lifecycle bariyerinde tombstone'u tekrar kontrol eder; sonradan gelen
iş silinen kaynağı canlandıramaz. Drain coalescing artık global tek Future
yerine explicit store namespace kullanır. Legacy default `legacy` kalır.

## Android bağlantı teşhisi

İlk teşhis uygulama değişikliklerinden önce yapıldı. Yalnız emulator-5554
bağlıydı. APK derlendi; verbose çıktıdaki son aşama `adb install -t -r` oldu.
Test/VM bağlantısı başlamadı. İlgili logcat'te FATAL/ANR kanıtı bulunmadı.
Bu bulgu uygulama deadlock'u veya instrumentation crash'i kanıtlamaz.

ADB server yeniden başlatıldı; emülatör tekrar `device` durumuna geldi.
Sandbox içindeki normal ADB server başlangıcı başarısız olurken yetkili
komutla bağlantı çalıştı. Bu erişim farkı tek başına kurulum gecikmesinin
kesin kök nedeni değildir. Son tek-runner yeniden denemesinde de APK build
başarılı oldu fakat `adb install -t -r` tamamlanmadı; sınırlı koşu durduruldu.
Emülatör boot_completed=1, /data üzerinde yaklaşık 4 GB boş alan vardı.
World native testleri başlamadı. Aynı kurulum önkoşuluna bağlı lifecycle,
scoped storage ve GPS native tekrarları bu tur tamamlanamadı; önceki geçişler
güncel koşu başarısı değildir. Gerçek Google Map/Android World kabulü açıktır.

## Test sınırları ve sonuçlar

- Son hedefli World/poster, kişisel ekranlar, pending processor, rebuild ve
  lifecycle: 54/54. Son checkpoint öncesi sahiplik/bootstrap/GPS/importer
  regresyon paketi: 166/166. Yanlış dosya adı verilen ayrı hedefli koşu yükleme hatası
  olarak saklandı ve doğru listeyle yeniden çalıştırıldı; başarılı sayılmadı.
- Son tam Flutter: 805/805. İlk tam koşudaki iki hata gizlenmedi: yeni World
  route'unu hâlâ kapalı bekleyen eski test ve onun native map cleanup hatası.
  Eski beklenti hâlâ kapalı olan poster route'una taşındı; tekrar tam koşu geçti.
- Analyze: yalnız önceden mevcut 4 info, yeni error/warning/info yok.
- Map widget testleri fake platform kullanır; gerçek native harita çizimi,
  GoogleMapController kamera komutları veya A55 kabulü sayılmaz.
- Sentetik prepared-intent/retry testleri gerçek process kill/power loss
  veya disk flush fault injection ile eşdeğer değildir.
- Flutter çıktıları Windows Temp'te `driveit_5c2e_full_verified.log`,
  `driveit_5c2e_analyze_verified.log`, `driveit_5c2e_target_verified.log`;
  native teşhis `driveit_5c2e_android_diagnostic.log`,
  `driveit_5c2e_emulator_logcat.log`, `driveit_5c2e_android_retry.log`.

## Açık riskler

Çoklu Hive kutuları tek transaction değildir. Kalıcı intent + aynı plana
idempotent recovery kullanılır; güç kaybına karşı tam atomik rollback iddiası
yoktur. Background giriş noktası hazırdır ancak üretim scheduler'ı kapalıdır.
Yeni normal GPS kaydından bağımsız World kaynak hazırlamanın bütünleşik
otomatik akışı önceki fazların açık entegrasyon alanı olmaya devam eder.
Native test tamamlanmadan Android World zinciri başarılı olarak raporlanamaz.
Gate açılmamalı; 5C.3/5D'ye geçilmedi, commit/push yapılmadı.

**Son durum: 5C.2E KISMEN.** Kontrollü World harita/detail/ID/delete/rebuild
ve worker sınırları tamamlandı; native tekrar kurulum engelinde kaldı.
