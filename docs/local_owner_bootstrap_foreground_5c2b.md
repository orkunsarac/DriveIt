# Aşama 5C.2B — kontrollü bootstrap, Auth, foreground ve kaynak yazıcıları

## Güvenlik sınırı

`LocalOwnershipGate.production` KAPALI. Release/profile build test gate'ini
açamaz. Normal `main` aynı legacy başlangıç fonksiyonunu aynı sırayla çağırır.
Gerçek hesap, kaynak veri taşıması, backend işlemi veya A55 kurulumu yapılmaz.
GPS journal v3 şeması, Hive adapter'ları, Score ve World kuralları değişmez.

Gate açık yol yalnız açık bağımlılıklarla ve işaretlenmiş
`driveit_owner_test_*` diziniyle oluşturulur. SDK restore callback'i mevcut
initialize edilmiş client için `SupabaseLocalOwnerAuth(client)` döndürebilir;
testler fake Auth kullanır. Scoped mağazalar restore/UUID doğrulamasından sonra
açılır. Owner/recovery hatasında ortak mağazaya fallback yoktur.

## Bağlantılar

- `LocalOwnershipBootstrap.run`: OFF legacy çağrısı; ON kimlik restore,
  journal/sidecar, epoch lifecycle, owner mağazası ve kontrollü foreground attach.
- Foreground attach/detach bağımlılıkları gerçek harness'te
  `ForegroundService.attachForTesting` / `detachForTesting` olur. Native producer
  durmadan kernel kapanışı reddedilir. Kapanış verileri silmez.
- `SupabaseAccountService` aynı public signUp/signIn/signOut girişlerini
  kontrollü runtime takıldığında identity işlem bariyerine alır. Aktif veya
  belirsiz oturumda SDK çağrısından önce reddeder. Normal singleton değişmez.
- `ownedStartCallback` Android'in ayrı FlutterEngine'inde descriptor'ı okur,
  aynı SQLite journal ve sidecar'ı açar. `DriveTaskHandler` owner doğrulamasını
  writer restore/GPS aboneliğinden önce yapar. Auth bu isolate'ta okunmaz.
- `DriveStorageService` kontrollü transfer callback'ini kullanır. Hedef sidecar
  binding'inden gelir. Session/drive kimliği veya owner çelişkisi global Hive'a
  yönlenmez. Aynı scoped sink ve intent/receipt sözleşmesi yeniden kullanılır.
- Save acknowledgement kontrollü yolda iki receipt ve hedef kayıtları da arar.
  Journal temizliği otomatik değildir; eski dual-proof maintenance korunur.

## Gerçek kaynak yazıcı envanteri

| Veri/işlem | Bariyer bağlantısı |
| --- | --- |
| History, isimler, symbolic route, toplamlar | DriveStorageService, Box mutasyon proxy'si |
| GPS → Hive | GpsHiveTransferSink, sabit owned transfer route |
| Telemetry ve Score | DriveTelemetryStorageService, DriveScoreStorageService |
| Career katkısı/baseline/revision | CareerContributionRepository tam işlemleri |
| World source/staging/validation revision | WorldSourceSnapshotRepository tam kuyruk işlemleri |
| World generation/pointer/recovery | HiveMyWorldIndexRepository tam commit/recovery |
| World pending jobs/validation/bulk silme | HiveMyWorldRepository, MyWorldRuntime drain |
| Lifecycle/tombstone/silme/recovery | LocalLifecycleJournal, IndependentDeletionService |
| Hazırlama | LocalDataPreparationService |
| Poster PNG/arka plan/metadata/silme | PosterStore tam dosya+metadata işlemi |
| Profil/fotoğraf/tercihler | ProfileStorageService, MyWorldSettingsService |
| Planet outbox | PlanetSegmentOutbox prepare/deliver |
| Scoped kayıtlar/manifest/lifecycle | OwnerScopedLocalStore, ScopedLifecycle |

Kaynak kökleri eski Hive ve kalıcı kaynak dosya dizinlerinin envanterinden açıkça
verilir; importer'ın ayrı hedef dizini kaynak sayılmaz. Fence kaynak writer'lar
oluşturulmadan kurulmalıdır. Kapsam kanıtı eksikse, fence kurulu değilse, bilinmeyen
category yazarsa, GPS aktif/okunamazsa veya drain/flush başarısızsa import başlamaz.
Yeni bir doğrudan Box/dosya yazıcısı eklenirse bu envanter ve testler güncellenmeden
import kapsamına dahil olduğu varsayılamaz. Fence diskte veya ayrı process'te bir
kilit değildir: native GPS için session/producer kontrolü + owner işlem bariyeri
kullanılır; başka kontrolsüz process yazıcısı varsa güvenli import sağlanmış sayılmaz.

Admission pause işlem başında kapanır; daha önce başlamış işlemler ve içlerinden
`unawaited` başlatılan işler ayrı izlenir. Pending kümesi yeniden kontrol edilir.
Drain beklemesi sınırlıdır; kendi write'ını drain etme ve erken resume reddedilir.
Başarısız pause admission'ı geri açar fakat importu çalıştırmaz. Write/flush hatası
import kanıtını zehirler: yeni veri silinmez, aynı fence başarı varsayamaz.

## Bu aşamada eklenen/değiştirilen dosyalar

Önceki 5A/B/C/5C.1/5C.2 dosyaları korunmuştur. Bu adımın dokunduğu dosyalar:

- lib/main.dart
- lib/config/local_ownership_gate.dart
- lib/services/local_ownership_bootstrap.dart (yeni)
- lib/services/owned_foreground_bootstrap.dart (yeni)
- lib/services/owned_drive_transfer_route.dart (yeni)
- lib/services/local_source_writer_fence.dart (yeni)
- lib/services/legacy_source_writer_fence.dart (yeni)
- lib/services/local_owner_lifecycle.dart
- lib/services/local_owner_import_bridge.dart
- lib/services/owner_scoped_local_store.dart
- lib/services/foreground_service.dart
- lib/services/task_handler.dart
- lib/services/supabase_account_service.dart
- lib/services/drive_storage_service.dart
- lib/services/gps_hive_transfer_sink.dart
- lib/services/drive_score_storage_service.dart
- lib/services/drive_telemetry_storage_service.dart
- lib/services/career_contribution_repository.dart
- lib/services/local_lifecycle_journal.dart
- lib/services/independent_deletion_service.dart
- lib/services/local_data_preparation_service.dart
- lib/services/profile_storage_service.dart
- lib/features/drive_poster/poster_store.dart
- lib/features/my_world/repositories/hive_my_world_index_repository.dart
- lib/features/my_world/repositories/hive_my_world_repository.dart
- lib/features/my_world/repositories/world_source_snapshot_repository.dart
- lib/features/my_world/services/my_world_runtime.dart
- lib/features/my_world/services/my_world_settings_service.dart
- lib/features/world_publish/segments/planet_segment_outbox.dart
- test/local_owner_bootstrap_writer_test.dart (yeni)
- test/local_owner_import_bridge_test.dart
- integration_test/owned_foreground_bootstrap_android_test.dart (yeni)
- docs/local_owner_bootstrap_foreground_5c2b.md (yeni)

## Doğrulama ve sınırlar

Başlangıç Flutter: 747/747. Son tam Flutter: 770/770 (23 ek test).
İlk regresyonda beş standalone process testi derleme aşamasında başarısız oldu:
yazıcı bağlantısı Flutter/UI (`dart:ui`) bağımlılığını saf depolama probe'larına
taşıdı. Sözleşme ve transfer route ayrıştırıldı; gate debug kontrolü saf Dart
compile sabitleriyle yapılır. Düzeltme sonrası ilgili process paketi 39/39 ve
tam paket 769/769, ardından gerçek ForegroundService → DriveStorage bağlantı
testiyle 770/770 geçti. İlk başarısız loglar geçici test loglarında korunmuştur.

Android: owner/importer/lifecycle/legacy Hive grubu 20/20; GPS/SQLite 8/8;
toplam 28/28. Native yeni probe gerçek ayrı headless
FlutterEngine ve sqflite MethodChannel ile iki servis oluşturulmasında aynı
owner/120 sıralı sentetik GPS noktası kontrolü yapar. Bu gerçek process kill,
power-loss, disk dolması veya fiziksel GPS hareket testi değildir. Üretim
`DriveTaskHandler`'ın gerçek konum akışı bu sentetik probe ile eşdeğer sayılmaz.

Son tam Flutter logu: `C:/Users/PC/AppData/Local/Temp/driveit_5c2b_full_verified.log`.
Native loglar: aynı dizinde `driveit_5c2b_android.log` ve
`driveit_5c2b_android_gps.log`. Native eski busy_timeout probe'u beklenen eski
SQLite exception'ını kasıtlı üretir; düzeltilmiş yapılandırma testi geçmiştir.
Gradle, flutter_foreground_task'ın gelecekteki Built-in Kotlin uyumu hakkında
uyarı verir; bu aşamada paket/sürüm/signing yapılandırması değiştirilmemiştir.

Kalan ekran entegrasyonları 5C.2C'ye bırakılmıştır. Gate açılmamıştır.
Son analyze: hata/uyarı yok, önceden mevcut 4 info (komut exit 1).
`git diff --check` başarılı. Branch ve checkpoint HEAD değişmemiştir.
İki SQLite dosyası, çoklu Hive kutuları ve dosya sistemi tek transaction değildir;
fail-closed, kalıcı intent/receipt ve idempotent retry gerekliliği devam eder.
