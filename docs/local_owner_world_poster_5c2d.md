# Aşama 5C.2D — World/poster sınırları (KISMEN)

## Güvenlik kararı

Üretim `LocalOwnershipGate.production` KAPALI. Branch
`feature/gps-refactor`, checkpoint `d883fe3e2587af5fd85087768364f6da767d3058`
korunur. Önceki 5A–5C.2C değişiklikleri geri alınmadı. Bu adım gerçek kullanıcı
migrasyonu, Supabase işlemi, fiziksel telefon kurulumu veya release aktivasyonu
değildir. GPS journal v3, Hive adapter alanları, Drive Score ve World kuralları
değişmez.

## Bu adımda değişen dosyalar

- lib/features/my_world/repositories/hive_my_world_repository.dart
- lib/features/my_world/services/my_world_rebuild_service.dart
- lib/features/my_world/services/world_record_processing_service.dart
- lib/services/owner_scoped_local_store.dart
- lib/services/local_owner_lifecycle.dart
- lib/features/drive_poster/poster_store.dart
- lib/features/drive_poster/poster_screens.dart
- integration_test/owned_foreground_bootstrap_android_test.dart
- test/owner_world_poster_boundary_test.dart (yeni)
- integration_test/owner_world_poster_android_test.dart (yeni)
- bu rapor (yeni)

## World bağımlılıkları

Mevcut `HiveMyWorldRepository.scoped` constructor'ı source snapshot, silme
kontrolleri ve serialized lifecycle işlemlerini zorunlu alır. Kutuda bulunmayan
road yalnız aynı namespace'in bağımsız kaynağından okunur; global
`WorldSourceAccess` veya global Hive'a fallback yoktur. Pending job admission ve
okuma aynı owner'ın tombstone kayıtlarıyla sınırlandırılır.

Rebuild ve record processing mevcut algoritmaları kullanır. Global filtreler
yerine açık owner-scoped filtreler enjekte edilebilir; eski constructor
varsayılanları değişmez. Lease üzerinden snapshot, road, pending job, map
projection, independent source detail ve rebuild erişimi hazırlanmıştır.
Rebuild tam owner operasyonu boyunca sabit depoda çalışır; Auth görüntüyü hemen
iptal eder, store kapanışı başlamış operasyonu bekler. Dönen sonucu revoked
lease'le yeni ekrana uygulamak yasaktır.

5 km, canonical/cumulative offset, yön, overlap ve minimum trace kuralları
yeniden yazılmadı. Rebuild eligibility, mevcut runtime gibi kaynak skorunun
bulunmasını da kontrol eder. Test fixture processing version'ı gerçek mevcut
`MyWorldRules.validatedRoadProcessingVersion` değerinden alınır.

## Poster dosya sınırları

Yeni paralel poster store yoktur. Aynı `PosterStore`, scoped kutu ve owner'a
özel poster/cache diziniyle kurulur. Her erişimde lease kontrol edilir. Absolute
başka-owner yolu, traversal, URI ve symlink reddedilir. Windows'ta karışık slash
ayraçları aynı private dosyayı yanlış reddetmeyecek şekilde eşitlenir.

Poster save/delete admission, owner operasyon bariyerine katılır. Başlayan
dosya/Hive işi başka owner'a yönlendirilmez; context kapanışı işi bekler. Save
öncesi sürüş ID'si authoritative scoped History'de doğrulanır. Paylaşım/galeri
öncesi güncel lease yeniden kontrol edilir. OS paylaşım başladıktan sonra OS
panelinin geri çağrılabileceği iddia edilmez.

`SavedPostersScreen(ownerLease: ...)` global store injection'ını kullanmaz;
metadata, viewer ve dosya erişimi aynı lease'te kalır. Revoked view kapatılır.
Scoped viewer'da henüz güvenli olmayan legacy edit yolu gösterilmez. Legacy
constructor ve tema/görünüm davranışı korunur. Scoped dış dosya/picker kaynağı
otomatik benimsenmez; owner staging/resolver bağlantısı tamamlanmalıdır.

## Tamamlanmamış kapsam ve neden gate kapalı

1. `MyWorldMapScreen`/`WorldTraceDetailScreen` içindeki bütün alt navigasyon,
   kaynak History silinmişken detay erişimi, trace silme/purge ve pending worker
   zinciri henüz bu scoped bağımlılıklara geçirilmedi. `/world` kontrollü router'da
   kapalı kalır. Helper/read tests tam native map ekran entegrasyonu değildir.
2. Poster center/editor, picker/cropper/lost-data cache'i, mapImagePath,
   oluşturma/önizleme ve import edilmiş görsel resolver'ı birlikte bitirilmedi.
   Controlled router'da `/posters` halen kapalıdır. Doğrudan scoped saved view
   desteği tam poster akışının tamamlandığı anlamına gelmez.
3. Completed legacy partition doğrulanmış salt-okunur kanıttır; live store'a
   kopyalanmış writable görünüm değildir. Koşulsuz overlay, aynı drive ID,
   Career baseline/katkı ve bağımsız World generation/pointer çakışmasını çözemez.
   Eski partition kayıtlarını tombstone/deletion ile tutarlı ve idempotent canlı
   görünürlüğe taşıyan atomik/fail-closed activation sözleşmesi tamamlanmadı.
   Importer/consent/ledger sınırları korunur; completed importtan sonra bütün
   kişisel ekranların yenilendiği iddia edilmez.
4. Önceki rapordaki normal drive/recovery UI ve onboarding tüketicileri de
   tam scoped router'a bağlanmış değildir. Bütün kişisel tüketiciler kapsandı
   denilemez; unregistered route ortak depoya düşmez.

Yeni scoped kayıtlar legacy ledger'a bağlanmadı. Gerçek legacy kaynaklar taşınmadı
ve silinmedi. Herhangi bir receipt görünürlük kanıtı diye tahminen genişletilmedi.
Bu eksikler nedeniyle **5C.2 bütünü tamamlanmadı**, 5C.3/5D'ye geçiş için güvenli
kapanış kararı verilemez.

## Test kayıtları ve kanıt sınırı

Başlangıç tam paket denemesi sırasında kaynak değiştirildiği için üç kernel
yükleme hatası görüldü (`Invalid kernel binary`, aynı URI için farklı source).
Bu koşu baseline veya başarılı regresyon değildir; çıktı saklandı. Sonraki
testler kaynak sabitken seri runner'larla çalıştırılır.

İlk hedefli koşu 78 geçti/3 başarısız: eski processing-version fixture'ı iki
World beklentisini, Windows karışık ayraç kontrolü poster save'i etkiledi.
Fixture güncellendi, path kontrolü düzeltildi; güvenlik/World eşikleri gevşetilmedi.
Yeni sınır paketi ara koşuda 10/10 geçti. Sonradan in-flight rebuild testi eklendi.

Önceki foreground arızasının çıktısında yalnız `ServiceRequestFailure` wrapper'ı
vardır; underlying native exception kayıtlı değildir. Probe izin önkoşulunu
doğrular, yeni failure'da native exception/test stack'ini korur. On seri tekrar
başarılı olsa bile eski arızanın kesin nedeni bulundu sayılmaz.

Native testler ayrı headless engine ve gerçek sqflite kullanabilir; sentetik
noktalar, kontrollü Auth ve emülatör dosyaları kullanılır. Bunlar fiziksel GPS,
gerçek OS process-kill/power-loss, A55 import veya gerçek kullanıcı kabulü değildir.
## Nihai doğrulama

- Kaynak sabitken tam Flutter: **795/795 geçti**. Yeni World/poster sınır
  paketi 11 testi kapsar; in-flight rebuild/Auth yarışı da bu koşuda geçti.
- Analyze: **yalnız önceden mevcut 4 info**, yeni warning/error yok.
- Headless foreground probe: **10/10 seri tekrar geçti**. Her tekrar izin
  önkoşulunu kontrol etti ve yeniden oluşturulan gerçek Android engine ile aynı
  owner/session/sequence zincirini doğruladı. Eski tek arızanın kök nedeni hâlâ
  kesinleşmedi.
- Android GPS/SQLite: **8/8 geçti**. Eski `busy_timeout` exception'ı beklenen
  negatif testtir; yeni native yapılandırma, v1/v2 yükseltme ve restart testleri
  geçti.
- Birleşik Android koşusu World/poster APK kurulumu sonrasında VM/test bağlantı
  aşamasında ilerlemedi. Tek başına yeniden deneme build sonrasında ilerlemedi.
  İki runner durduruldu; bu paket ve ardından planlanan importer/lifecycle/
  scoped storage/sidecar/legacy Hive tekrarları **bu tur tamamlanmadı**.
  Önceki Android sonuçları yeni koşu başarısı olarak sunulmaz.
- Çıktılar Windows geçici dizininde `driveit_5c2d_full.log`,
  `driveit_5c2d_analyze_final.log`, `driveit_5c2d_foreground_10.log`,
  `driveit_5c2d_android.log`, `driveit_5c2d_android_retry.log` adlarıyla korunur.
- `git diff --check` başarılı; HEAD/branch değişmedi. Önceki uncommitted
  geliştirmeler ve ilgisiz `tatus` korunur. Commit/push yapılmadı.

**Son karar: 5C.2D KISMEN.** Tam World/poster ekran zinciri ve doğrulanmış
legacy partition'ın güvenli canlı görünürlüğü tamamlanmadan 5C.2 bütünü kapanmaz.
Üretim gate'i KAPALI; 5C.3/5D'ye geçilmedi.
