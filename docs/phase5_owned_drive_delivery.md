# Aşama 5 / Teslimat 2 — Yeni sürüşün uçtan uca owner kaydı

Tarih: 11 Ekim 2026. Branch: `feature/gps-refactor`.
HEAD: `f68445cb7038e50b95f0da139fc7b7b307267105` (değişmedi).
Önceki çalışma alanı geliştirmeleri korunmuştur. Bu teslimat kontrollü,
fake Auth / sentetik GPS ortamıdır; üretim aktivasyonu veya fiziksel kabul değildir.

## A. Bu teslimatta değiştirilen dosyalar

Yeni:
- `lib/screens/owned_drive_screen.dart`
- `lib/services/owned_drive_finalization.dart`
- `test/owned_drive_delivery_test.dart`
- Bu rapor.

Mevcut:
- `lib/widgets/owner_personal_navigator.dart`
- `lib/screens/map_screen.dart`
- `lib/screens/drive_detail_screen.dart`
- `lib/widgets/drive_summary_dialog.dart`
- `lib/features/drive_poster/poster_screens.dart`
- `lib/services/foreground_service.dart`
- `lib/services/local_owner_lifecycle.dart`
- `lib/services/gps_session_transfer.dart`
- `lib/services/owned_gps_session_coordinator.dart`
- `lib/services/scoped_gps_transfer_sink.dart`
- `lib/services/owner_scoped_local_store.dart`
- `lib/services/drive_telemetry_storage_service.dart`
- `lib/features/drive_score/services/drive_score_persistence_coordinator.dart`
- `lib/services/career_contribution_repository.dart`
- `test/local_owner_integration_test.dart`

Git diff ayrıca önceki Aşama 5 dosyalarını içerir; tamamı bu teslimatta oluşturulmuş
gibi sayılmamıştır. Android yapılandırması, main, gate, journal şeması, World ve
Score algoritmaları bu teslimatta değiştirilmemiştir.

## B. Başlangıç denetimi ve /drive

Gerçek eksikler: owner navigator'da `/drive` yoktu; MapScreen/recovery/summary
owner lease taşımıyordu; scoped transfer sonrası erken return nedeniyle ortak
save yolundaki Score/World/Career yan etkileri çalışmıyordu. Proven Career katkıları
yazılabiliyor ama görünür Career yalnız legacy baseline yolundan okunuyordu.

`OwnerPersonalNavigator /drive → OwnedDriveScreen → MapScreen(ownerLease)`
bağlantısı tamamlandı. Önce attachment/lease ve recovery kanıtı doğrulanır.
Doğrulanmamış Auth veya eksik scoped dependency'de ortak depoya fallback yoktur.
Eski aktif session proven ilan edilmez. Recovery hatası veriyi koruyarak erişimi
engeller. İki receipt sonrası yarım finalization varsa yeni sürüş yerine açık
“Kaydı Tamamla” yolu sunulur.

## C. Foreground owner/session/provenance

Yeni bir GPS motoru yazılmadı. Mevcut zincir yeniden kullanılır:

`MapScreen.startDriving → ForegroundService.start → LocalOwnerGpsBridge.start
→ lifecycle operation → sidecar prepare(owner/session/source UUID)
→ journal.create → ready binding → durable descriptor → owned foreground callback`.

Isolate Auth kullanıcısından yeniden owner seçmez. Resume/recreation aynı
session/source UUID'yi doğrular. MapScreen başlangıç, restore, sync ve bitirme
girişleri current lease ve sidecar sahibiyle kontrol edilir. Aktif A session'ında
harici B olayı A sahibini değiştirmez; B görünümü bloke edilir. Güvenli devam için
A kimliğinin yeniden doğrulanması gerekir. Kaydı B'ye aktararak blok aşılmaz.

## D. SQLite → owner Hive finalization

`DriveSummaryDialog → DriveStorageService.saveDrive → mevcut fixed transfer route
→ LocalOwnerLease.transferGps` artık şu tam zinciri çalıştırır:

1. Owner-local `owned_drive_finalization_v1` pending kaydı; sabit owner/session/source.
2. Mevcut SQLite transfer intent; orijinal öneri/date/summary sabitlenir.
3. Scoped drive + telemetry + provenance yazımı, flush ve read-back.
4. Journal acknowledgement öncesinde aynı owner'da Score/source/Career/World.
5. Hedef flush; türetilmiş işlemlerin tamamlandığı kalıcı kayıt.
6. Mevcut journal acknowledgement ve sidecar receipt; iki kanıt yeniden doğrulanır.
7. Owner finalization completed; ancak bundan sonra History/detail erişimi açılır.

Secondary writer veya retryable World işi başarısızsa save başarılı gösterilmez.
Stopped journal ve pending iş korunur. Aynı intent/source UUID ile retry yapılır.
Journal saved olmuş fakat son completion yazımı başarısızsa owner pending kaydı
üzerinden reconciliation yapılır; native GPS başlatılmaz. Flush başarısızlığının
bellekte bıraktığı `completed` değeri History'yi açamaz. Cleanup ve UI acknowledgement
de tamamlanmamış/durability doğrulanmamış finalization'ı reddeder.

### Dikey testlerin bulduğu hassasiyet problemleri

Hive DateTime adapter round-trip'i mikrosaniye precision'ını düşürdüğü için yeni
gerçek timestamp'li scoped telemetry exact transfer verification'da reddediliyordu.
Scoped kayıtlar, mevcut metadata/quality alanında microsecond ve UTC bilgisini
kayıpsız taşır. Eski adapter field/type ID'leri değiştirilmedi. Bu opt-in timestamp
metadata'sı yalnız scoped sink tarafından eklenir; normal üretim kayıt biçimi korunur.

UI'nin DateTime.now() sürüş tarihi için de owner `drive_details_v1` içerisinde
`gpsTransferDate:<session>` kanıtı korunur; typed owner drive okuması aynı tarihe
geri döner. Eski drive kaydı, tarih veya tarih anlamı dönüştürülmez.

İlk Score nesnesi ile Hive'dan okunan calculatedAt precision farkı retry'da
Career source-score conflict üretiyordu. Finalizer bütün domain tüketicilerine
hesaplayıcının geçici nesnesini değil, persist edilmiş Score read-back'ini verir.

## E. History, detay ve rota

History owner lease'in tamamlanmış kayıtlarını okur. Pending kayıt doğrudan ID ile
detaydan da açılamaz. `/detail`, route, telemetry, Score ve poster aynı current
lease'i taşır. Account/epoch değişiminde mevcut navigator ve LocalOwnerView
erişimi iptal edilir; eski Future sonuçları yeni hesap görünümüne uygulanmaz.
Eksik veri ortak Hive'dan tamamlanmaz.

## F. Score / World / Career / Poster / Planet

- Score: mevcut v1 calculator ve reliability/coverage policy aynı kalır.
  Yetersiz telemetry'de null/N/A; eski skorlar yeniden hesaplanmaz. Sadece explicit
  storage callback'li entry point eklendi; legacy entry point mevcut fast path'ini korur.
- World: mevcut scoped source snapshot, validateRoad pending job, matching service,
  worker ve index commit kullanılır. v6/5 km/overlap/yön/canonical kuralları değişmez.
  Worker retry durumu başarılı finalization sayılmaz. Kalıcı validation rejection
  geçerli terminal sonuçtur, sahibine yeni World izi uydurulmaz. Matching dependency
  yoksa fail-closed; ortak veya gerçek backend fallback yoktur.
- Career: proven `source:<UUID>` katkısı ve kaynak-score ilişkisi exactly-once.
  Görünür istatistikler yalnız bu owner'ın katkılarından okunur. Boş yeni owner
  sıfır Career gösterebilir; legacy cumulative-only/mixed baseline otomatik toplanmaz
  veya sıfırlanmaz, güvenli hata verir. History silme proof'u proven contribution
  anahtarını kullanabilir; World/Career bağımsız kalıcılığı korunur.
- Poster: kaydetme sonrası teklif/Editor aynı lease ve authoritative owner drive ile
  açılır. Önceki owner-scoped asset/picker/store sınırları yeniden kullanılır;
  tasarım ve eski poster importu değiştirilmez.
- Planet: scoped personal preview/outbox ve kapalı backend davranışı korunur;
  gerçek yayın veya yeni backend etkinleştirilmez.

## G. Guest / A / B ve legacy

Sentetik A → B → A ve guest → A testlerinde History, Career, World ve direct ID
erişimi ayrıdır; guest kaydı otomatik taşınmaz. Aynı local ID'li account kayıtları
ve poster/cache/async izolasyonu mevcut regresyon testlerinde de korunur.
Eski cihaz arşivi değiştirilmedi; arşiv kaynak-hash/read-only/authorization testleri
hedefli ve tam pakette çalıştırıldı. Legacy claim/import/revision publish, World remap
ve eski Career merge yeni sürüş zincirinin bağımlılığı değildir, çalıştırılmamıştır.

## H. Recovery / idempotency / gerçek sınırlar

- Public start/save, descriptor verification, stopped-producer resume aynı UUID.
- Tekrar save: bir History, bir source contribution, aynı World sonucu.
- Flush hatası sonrası stopped journal, hidden pending History ve receipt engeli.
- Store/journal/sidecar close → reopen sonrası aynı source/sequence ve retry.
- İki receipt sonrası completion hatasında kayıt çoğalmadan reconciliation.
- Writer pause/drain ve owner operation bariyerleri mevcut altyapıdan korunur.

Birden fazla Hive kutusu + iki SQLite dosyası **tek transaction değildir**.
Career katkısı veya World generation, son History visibility completion'dan önce
kalıcılaşabilir. Hata halinde bu doğrulanmış owner-local domain yazımları rollback
edilmez; journal/intent korunup idempotent retry tamamlar. Bütün domain ekranlarının
tek atomik visibility pointer'ı kullandığı iddia edilmez. Bu teslimatta legacy revision
publish kullanılmamıştır. Kontrollü exception/close-reopen gerçek process-kill veya
power-loss kabulü değildir.

## I. Test sonuçları

- Başlangıç GPS/transfer/provenance regresyonu: 41/41.
- Yeni `owned_drive_delivery_test.dart`: 12/12; service ve widget akışı dahil.
- Son hedefli paket (yeni sürüş + lifecycle/bootstrap + scoped transfer + arşiv): 80/80.
- Tam Flutter son koşu: **887 geçti, 2 koşullu atlandı, 0 başarısız**; exit 0.
- İlk tam koşudaki boş-owner Career beklentisi başarısızlığı saklandı. Eski test yeni
  ürün anlamına güncellendi; cumulative-only protected-error testi ayrıca eklendi.
- Analyze: yalnız mevcut 4 info; error/warning yok.
- `git diff --check`: başarılı.

Atlananlar: Windows host'ta sentetik symlink oluşturma kısıtı;
isolated-Android define gerektiren backend-guard native koşulu. Atlananlar geçti sayılmaz.

UI testi gerçek owner `/drive` route'unu, gerçek MapScreen start/stop metotlarını,
gerçek summary save kontrolünü, History/detail widget'larını kullanır. 301 sentetik
GPS noktası / 6 km; persisted Score, owner World generation/trace ve tek Career katkısı
doğrulanır. Harita ve foreground MethodChannel host fake'idir. Fiziksel GPS,
Google Maps native render veya Android foreground servis kabulü değildir.

Loglar: `build/phase5_owned_drive_targeted_tests.log`,
`build/phase5_owned_drive_flutter_tests.log` (ilk başarısız koşu),
`build/phase5_owned_drive_flutter_tests_final.log`,
`build/phase5_owned_drive_analyze_final.log`. Build çıktıları commit edilmedi.

ADB yetkili salt-okunur kontrolünde cihaz listesi boş: **A55 native yapılmadı**.
Gerçek paket veya gerçek veriye işlem yapılmadı. Son fiziksel kabulde yalnız izole
paketle foreground restart, finalization, owner switch/recovery ve archive cihaz
doğrulaması kontrol edilmelidir.

## J. Gate kapalı üretim davranışı

`LocalOwnershipGate.production` KAPALI; synthetic gate release/profile'da reddedilir.
`main` aktivasyonu değişmedi. Ortak Hive/GPS save yolu ve eski arşiv kaynakları
korunur; yeni scoped finalization ancak açık fake/test bootstrap + attachment ile
çalışır. Otomatik legacy migration/sahiplenme başlamaz. Supabase, gerçek Planet
yayını, APK kurulumu, branch değişimi, commit/push ve `tatus` işlemi yapılmadı.

## K. Eksikler / kalan kabul maddeleri

1. Bu teslimatın yeni-owner host dikey zincirinde açık bağlantı eksikliği kalmadı.
2. Son Android/A55 foreground/finalization ve gerçek GPS kabulü yapılmadı.
3. Üretim rollout/bootstrap/Auth onboarding kararı ayrı; sadece gate flip güvenli değildir.
4. Harici Auth ile sahip session çelişirse doğru owner yeniden doğrulanana kadar
   güvenli bekleme sürer. Başka hesaba transfer veya otomatik bitirme çözüm değildir.
5. Çok kutulu disk hatası/power-loss için tam atomik rollback garantisi verilmez.
6. Native device-auth arşiv kabulü Teslimat 1'den açık kalır; yeni sürüşte legacy merge
   bağımlılığı oluşturmaz. Gerçek kullanıcı kayıtlarında migration denenmedi.

## L. Karar

**Teslimat 2: EVET — kontrollü gate-açık sentetik kabul hedefi için.**
Yeni sürüş, gerçek UI/service entry point'leri üzerinden aynı owner'da kaydedilip
History, rota, Score, World ve Career sonucunu veriyor; gate kapalı üretim yolu
korunuyor. Bu karar Aşama 5'in bütünü veya Android production-readiness onayı değildir.
Fiziksel kabul ve üretim aktivasyonu açık bırakılmıştır. Bu teslimat sonunda duruldu.
