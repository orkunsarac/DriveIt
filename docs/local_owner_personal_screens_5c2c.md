# Aşama 5C.2C — kişisel ekran entegrasyonu (KISMEN)

## Güvenlik kararı

`LocalOwnershipGate.production` KAPALI. Yeni akış yalnız açık sentetik
runtime/lease ile kurulur. Normal bootstrap, Auth, GPS, journal v3, Hive
adapter'ları ve mevcut kullanıcı depoları değiştirilmedi. Önceki Aşama 5
değişiklikleri korunmuştur. Bu çalışma bütün kişisel ekran entegrasyonunun
tamamlandığına veya gate'in açılabileceğine kanıt değildir.

## Bu adımda değişen dosyalar

- lib/services/local_owner_lifecycle.dart
- lib/services/profile_storage_service.dart
- lib/services/drive_diagnostic_export.dart
- lib/services/owner_personal_preferences.dart (yeni)
- lib/widgets/local_owner_view.dart (yeni)
- lib/widgets/owner_personal_navigator.dart (yeni)
- lib/widgets/drive_score_summary_section.dart
- lib/screens/home_screen.dart
- lib/screens/history_screen.dart
- lib/screens/career_screen.dart
- lib/screens/drive_detail_screen.dart
- lib/screens/profile_settings_screen.dart
- lib/features/drive_replay/drive_replay_screen.dart
- lib/features/world_publish/segments/planet_publication_section.dart
- test/owner_personal_screen_test.dart (yeni)
- integration_test/owner_personal_screen_android_test.dart (yeni)
- bu rapor

## Envanter ve uygulanan sınırlar

| Tüketici | Scoped durum |
| --- | --- |
| Ana ekran | Sürüşler, son skor, kalıcı Kariyer, profil/fotoğraf ve isim aynı lease'ten. Eski SDK kimlik cache'i okunmaz. Scoped onboarding turu henüz açılmaz. |
| Sürüşlerim | Önceki scoped okuma/silme korunur; doğrudan açılmış ekran da Auth değişiminde satır cache'ini kapatır. |
| Sürüş detayı / rota | `OwnedDriveDetailScreen` ID'yi scoped repository'de çözer; dışarıdan verilen model sahiplik kanıtı değildir. Detay kendi authoritative kopyasını kullanır. Kamera timer ve icon callback'i epoch revokasyonuna uyar. |
| Replay | Detaydan aynı lease geçer; authoritative sürüş kullanılır, revokasyonda ticker durur ve kamera çağrıları engellenir. |
| Drive Score | Persisted scoped skor/zaman; başka owner'a fallback veya yeniden score hesabı yok. Eski lease ekranı revokasyonda kapanır. |
| Kariyer | Önceki katkı/baseline tüketicisi korunur; route, Future ve kaynak detay erişimi owner sınırında kalır. Eksik baseline sıfır/toplanmış History diye uydurulmaz. |
| Profil/Ayarlar | Yerel isim, byte avatar ve World tercihi revocable provider'dan okunur/yazılır. Global profile loader scoped yolda kullanılmaz. Açıkça verilmemiş cloud gateway'e fallback yok; gelen profil UUID'si doğrulanır. |
| Segment önizleme/outbox | Authoritative sürüş/telemetry ve sabit owner. Submit yok, yalnız disabled yerel outbox preparation. Payload tekrar mevcut telemetry adaylarıyla doğrulanır; farklı sürüş veya değiştirilmiş payload reddedilir. Mock kabul gerçek yayın değildir. |
| Tanılama export | Scoped sürüş/telemetry/road girdisi. Hesap hash'iyle ayrı temporary dizin; paylaşım öncesi lease yeniden doğrulanır. Native paylaşım başladıktan sonra OS paneli geri çağrılamaz. |
| Benim Dünyam/map/detail/rebuild | **TAMAMLANMADI**; aşağıdaki global fallback bağımlılıkları giderilmeden bağlanmadı. Kontrollü `/world` route kapalı. |
| Poster center/editor/saved/share | **TAMAMLANMADI**; canlı metadata ve dosya resolver'ı birlikte owner-scoped yapılmalı. Kontrollü `/posters` route kapalı. |
| Normal sürüş center/recovery UI | Önceki sabit GPS owner altyapısı mevcut; tüm UI navigasyon zinciri henüz scoped router'a bağlanmadı. `/drive` kapalı. Gate kapalı üretim davranışı korunur. |
| Onboarding yerel profil/ready ekranları | Global profile loader tüketicileri halen var; controlled router'a kayıtlı değil. |
| Ortak Planet map/trace detail | Sunucu ortak içeriği kişisel outbox'tan ayrı; değişmedi, scoped kişisel router yeni network yolu açmaz. |
| Legacy consent/import sonrası ekranlar | Mevcut consent/quiescence/importer/ledger korunur. Completed partition'ın bütün ekranlara güvenli overlay/promotion entegrasyonu **eksik**. |

## Repository/cache bariyerleri

Mevcut epoch ve owner namespace kullanılır; yeni bir hesap/epoch sistemi yoktur.
`LocalOwnerView`, doğrudan push edilen özel route'u da listenable revokasyonunda
kapatır. `OwnerPersonalNavigator`, mevcut `LocalOwnerNavigator` altında bütün
private Navigator subtree'sini owner epoch ile değiştirir. Eksik route protected
ekran verir; legacy widget builder çağrılmaz. ID çakışmasında sadece ilgili
namespace'in authoritative kaydı okunur. Normal yeni scoped kayıtlar ledger'a
bağlanmaz. Logout disk verisini silmez.

Başlamış yazmalar eski lease deposuna sabittir; context geçişi yazmaları bekler.
Yeni revocable profil yazması veya outbox preparation eski lease ile başlayamaz.
Gecikmiş Future sonuçları eski owner view'den çıkar; harita callback'i yeni
owner state'ine yönlendirilmez. Bu, kontrolsüz legacy ekranın scoped router
dışında güvenli olduğu iddiası değildir.

## Tamamlanmayı engelleyen somut tüketiciler

- `HiveMyWorldRepository.getValidatedRoad/getAllValidatedRoads` box'ta kayıt
  bulunmazsa global `WorldSourceAccess` kaynaklarına bakıyor. Yalnız başka box
  inject etmek izolasyon sağlamaz.
- `MyWorldRebuildService` global `LocalLifecycleJournal` tombstone/filter
  bağımlılıkları içeriyor. Owner-scoped index tek başına yeterli değildir.
- `MyWorldMapScreen` pending drain, trace silme, kaynak detay, son sürüş ve
  settings yollarında global runtime/source erişimleri kullanıyor.
- `WorldTraceDetailScreen` global profil ve nested DriveDetail yolu kullanıyor.
- `poster_screens.dart` History, score, `PosterStore.open`, görsel dosya ve
  saved poster yeniden düzenleme yollarını birlikte bağlamak gerekiyor.
  5C.1 verified file resolver'ını atlayıp yalnız metadata kopyalamak güvenli değil.
- `VerifiedLegacyImport` ayrı doğrulanmış read-only partition'dır. Live store ile
  ID/World generation/Kariyer baseline çatışması kararı olmadan genel union veya
  kısmi target görünürlüğü eklenmedi. Consent/import tamamlandı diye bütün
  ekranlardan erişilebilir olduğu raporlanamaz.

Bu bileşenler etkinleştirilmemiştir; 5C.3/5D'ye geçmek için henüz güvenli değildir.
Gerçek A55 verisi, Supabase, commit/push veya tatus üzerinde işlem yapılmadı.

## Test kayıtları

Başlangıç tam Flutter: 770/770. İlk yeni hedefli koşu 31 geçti / 1 başarısız:
test fixture'ın telemetry drive ID'si istenen segment kaynağıyla eşleşmiyordu.
Fixture düzeltildi; ID/payload doğrulaması gevşetilmedi. Ardından yeni ekran
paketi 10/10 ve ara tam paket 780/780 geçti. Sonradan eklenen route/History/
Navigator testleri ve nihai regresyon sonuçları görev son raporunda belirtilir.

Testler fake Auth ve sentetik/private geçici Hive kullanır. Gerçek Android
GPS hareketi, process kill, power loss veya gerçek kullanıcı importu değildir.
Map widget native rendering ve poster görsellerinin owner izolasyonu bu
eksik implementasyonla doğrulanmış sayılmaz. Loglar Windows geçici klasöründe
`driveit_5c2c_*` adlarıyla saklanır; repoya test çıktısı eklenmez.

### Nihai sonuçlar

- Tam Flutter: **784/784** (`--timeout=2m`), 1 dakika 45 saniye.
- Yeni owner ekran paketi: Android emülatörde **14/14**.
- İlk birleşik Android koşusu: **40 geçti / 1 başarısız**. Başarısız olan
  foreground owner probe `ServiceRequestFailure` verdi; ilk alttaki native
  exception kayıtta bulunmadığından kesin kök neden iddiası yoktur.
- Emülatör konum izin hazırlığıyla seri tekrar: foreground probe **1/1**,
  GPS/SQLite **8/8**, owner ekranları **14/14**, toplam **23/23**.
  İlk koşudaki diğer importer/lifecycle/scoped/sidecar/legacy Hive kontrolleri
  de geçti. Tekrarın geçmesi ilk arızanın kök nedenini kanıtlamaz.
- Analyze: yalnız önceki **4 info**, yeni error/warning yok.
- `git diff --check`: başarılı.

Sonuç **KISMEN**: yukarıdaki eksik World/poster/legacy görünürlük tüketicileri
tamamlanmadan gate açılmamalı ve 5C.3/5D'ye geçilmemeli. Sentetik hata
simülasyonları gerçek process kill/power loss olarak değerlendirilmemiştir.
