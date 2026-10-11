# Aşama 5 / Teslimat 1 — Salt okunur cihaz sürüş arşivi

> Takip notu (11 Ekim 2026): Aşağıdaki bulgular ilk teslimatın tarihsel sonucudur.
> Eksik Android doğrulama adapter'ı sonraki kapanış çalışmasında eklendi; epoch,
> kısa ömür ve background iptali test edildi. Güncel sonuç ve açık fiziksel kabul
> için [Android arşiv erişimi kabul raporu](phase5_drive_archive_acceptance.md)
> esas alınmalıdır. Production gate hâlâ kapalıdır.

Tarih: 11 Ekim 2026. Branch: `feature/gps-refactor`. Başlangıç HEAD:
`f68445cb7038e50b95f0da139fc7b7b307267105`. Önceki Aşama 5 değişiklikleri korundu.

## A. Değiştirilen dosyalar ve ürün kararı

- `docs/driveit_requirements.md`: G.2/G.10, eski geniş legacy aktarım kapsamının yerine gelen açık kullanıcı kararı; F.4 yeni guest katkılarıyla eski toplamları ayırır.
- `docs/phase5_completion_replan.md`: tarihsel geniş arşiv önerisini geçersiz kılan kapsam notu. Tarihsel denetim silinmedi.
- `lib/services/device_drive_archive.dart`: dar Hive okuyucu, doğrulanmış detached snapshot, ayrı cihaz yetkilendirmesi ve revocable archive context.
- `lib/screens/device_drive_archive_screen.dart`: salt okunur liste, detay ve GPS haritası.
- `lib/screens/history_screen.dart`: yalnız controlled owner görünümünde ayrı arşiv girişi.
- `lib/widgets/owner_personal_navigator.dart`: isteğe bağlı arşiv bağımlılığını controlled History'ye iletir. Önceki poster rotası korundu.
- `test/device_drive_archive_test.dart`: sentetik kaynak ve fake Auth ile testler.
- Bu rapor.

Zorunlu koruma yalnız eski kaydedilmiş sürüş/rota/tarih/süre/mesafe/hız/temel detaydır.
Eski Career, World, poster/görsel, profil ve Planet outbox yeni hesaplara taşınmaz.
Kaynakları silmek veya bu yeni karar nedeniyle mevcut yeni sürüş kurallarını değiştirmek yoktur.
Import partition, claim ledger, revision pointer ve merge/remap bileşenleri korunur fakat
arşiv onları çağırmaz. Normal yeni sürüş finalization'ının önceki raporda belirtilen
ayrı entegrasyon eksikleri bu teslimatın tamamlandığı iddiasına dahil değildir.

## B. Gerçek kaynaklar ve okuma yan etkileri

`DriveStorageService.getAllDrives/getDrive` ortak `drives` kutusundan okur.
`DriveSession` Hive type 0 alanları: ID(0), date(1), metre mesafesi(2), saniye süre(3),
ortalama/maksimum hız(4/5), mapImagePath(6), sıralı RoutePoint listesi(7), mevcut temel
stop/hareket/irtifa istatistikleri(12–25). `date` gerçek bitiş zamanı diye yorumlanmaz.
Rota kaynağı bu persisted listedir; SQLite journal tamamlanmamış sürüş ve recovery
içindir, arşiv oluşturulurken journal örneklerinden yeni sürüş üretilmez.
RoutePoint latitude/longitude 0/1, breakBefore 254; eski DateTime alanı 2 rezervdir.
Mevcut adapter'ın taşıdığı legacy route alanları binary round-trip ile korunur.

Normal `HistoryScreen` silme sunar; `DriveDetailScreen` profil, yayın ve poster/score
tüketicilerine bağlıdır. Normal bootstrap World index hazırlığı ve pending job drain
çalıştırabilir. Normal save Career hazırlığı/katkı, Score persistence, World kaynak/job
işlemleri yapar. Bu akışlar arşiv görüntülemesinde kullanılmaz. Yeni okuyucu yalnız
çağıranın zaten açmış olduğu `Box<DriveSession>` için `keys/get` kullanır; kendisi
`Hive.openBox`, flush, put, delete, migration, rebuild veya Auth başlatmaz.
Hive kutusunu açan dış kodun bakım/compaction davranışı ayrı sorumluluktur; kaynak
dosyalarını read-only işletim sistemi modunda açtığımız iddia edilmez.

Telemetry, validated roads, World snapshots, Career, profile, poster ve outbox kutuları
arşiv için okunmaz. `mapImagePath` mevcut sürüş objesinin ayrık kopyasında kalır fakat
görsele erişilmez/kopyalanmaz/gösterilmez. Eski Score isteğe bağlı olduğu için bu
teslimatta gösterilmez; skor hesaplanmaz. Eksik telemetry'den değer uydurulmaz.

## C. Tamamlanan sentetik ekran zinciri

`OwnerPersonalNavigator → HistoryScreen → Cihazdaki Eski Sürüşler → Eski Sürüş Detayı
→ GPS Rota Haritası`.

Liste tarih/mesafe/süreyi, detay kayıtlı ortalama/maksimum hızı ve rota önizlemesini
gösterir. Harita birebir sıralı koordinatlar, breakBefore ile ayrı polylines ve gerçek
ilk/son marker kullanır; konum izni/GPS akışı açmaz. Pan/zoom GoogleMap'in standart
kontrolleridir. Harita native tiles/gestures host fake-platform testinde doğrulanmış
sayılmaz. Başlangıç kamera ilk kayıtlı noktaya odaklıdır; tüm rotaya otomatik fit yoktur.
Silme, düzenleme, poster, publish, World ve Career eylemleri bulunmaz.

## D. Kaynak bütünlüğü / snapshot

Snapshot diskten kaynakları taşımayan, bellekte detached binary kopyadır. Kaynak writer
registration + pause/drain ve unfinished session kontrolü zorunlu bağımlılıktır;
kontrol hatası veya pending GPS varsa snapshot verilmez. Tekil ID eşleşmesi, şema,
finite koordinatlar ve SHA-256 fingerprint doğrulanır; ikinci source capture ile
tutarlılık karşılaştırılır. Başarılı resume tamamlanmadan snapshot Future'ı dönmez.
Kısmi snapshot ekrana verilmez. Yeni provenance UUID veya ID remap yoktur.

Her okumada yeni detached DriveSession/RoutePoint alınır: objeyi değiştirmek snapshot'ı
ve kaynağı değiştirmez; HiveObject.save/delete bağlı box olmadığından reddedilir.
Kaynak `.hive` byte'ları okuma öncesi/sonrası eşitliği sentetik testle kanıtlandı.
Başka metadata/dosyaları dönüştürme veya ek disk snapshot yazımı yapılmaz.
Restart testi kaynak Hive kapatılıp yeniden açıldıktan sonra aynı fingerprint'in tekrar
hazırlanmasını doğrular; process kill/power-loss testi değildir. Serialize/restore
ayrıca bütünlük kontrolünden geçer; gerçek bootstrap'a kalıcı snapshot açma bağlanmadı.

## E. Hesap izolasyonu ve bağımsız erişim

Arşiv account/guest History'ye eklenmez. Ayrı `DeviceArchiveAuthorizer` onayı gerekir;
Supabase login yetki sayılmaz. Direct ID yalnız özel `DeviceDriveArchiveContext` ile
okunur; account-only kayıt arşiv ID lookup'tan bulunamaz. Context owner lease epoch'ına
yalnız revocation için bağlıdır; bu bağ arşiv kaydını o owner'a ait yapmaz.
Auth değişirken bekleyen device verification sonucu reddedilir. A→B→A eski capability'yi
yeniden canlandırmaz. Açık harita/list/detail epoch değişiminde unavailable görünümüne
geçer; yeni hesap için ortak source veya kişisel depo fallback'i yoktur.

**Somut blokaj:** repoda güvenilir Android device credential/biometric doğrulaması
yoktur (`local_auth`, Keyguard/deviceCredential uygulaması bulunmadı). Bu nedenle
production veya controlled gerçek kullanıcı arşiv erişimi kurulmadı. History'deki
kontrollü giriş, güvenilir adapter bağımlılığı verilmediyse devre dışıdır ve nedeni
gösterilir. Fake authorizer yalnız sentetik testte verilir. Production gate sabit OFF;
debug synthetic gate release/profile'da reddedilir. Gate-OFF normal History UI ve GPS
akışına arşiv girişi/migration eklenmez.

## F. Test sonuçları

- İlk hedefli koşu: 12 geçti / 1 başarısız; test `HiveError` yerine `StateError` bekliyordu.
  Ürün kodunda exception bastırılmadı; test gerçek Hive detached-object sözleşmesine düzeltildi.
- Güncel hedefli: **15 geçti / 0 atlandı / 0 başarısız**.
- Tam Flutter iki seri tam koşuda: **859 geçti / 2 koşullu atlandı / 0 başarısız**
  (yaklaşık 80 ve 77 saniye). Son koşu snapshot hazırlığı öncesi/sonrası byte karşılaştırmasını da içerir.
- İki skip: hostta isolated-Android define'ı bulunmayan backend guard ve Windows
  symlink fixture koşulu; başarılı test sayılmadı.
- Son `flutter analyze`: yalnız önceden mevcut **4 info**, yeni warning/error/info yok.
  Analyze info'lar nedeniyle exit 1 verir; temiz exit 0 olarak sunulmaz.
- `git diff --check`: mevcut repository CRLF ayarlarıyla exit 0; yeni untracked
  kaynak/test/raporlar ayrıca no-index whitespace kontrolünden geçirildi.

Kapsam: tam rota/legacy DateTime/metadata, source byte equality, detached mutation,
A/B normal depolarda eski kayıt bulunmaması, epoch revocation ve async auth yarışı,
yetki reddi, gate-OFF, source reopen, snapshot restore/corruption, active journal
engeli, writer drain hatası ve tam History→arşiv→detail→segmentli map widget zinciri.

## G. Android kabul ve kalan sınırlar

ADB cihaz listesi boş. A55 veya başka cihazda kurulum/test/gerçek veri okuması yapılmadı.
Native kabul açık: izole paketle eski Hive fixture, device authorization adapter'ı,
GoogleMap native rendering/gesture ve epoch geçişi. Gerçek pakete dokunulmadı.

Bellek maliyeti kaynak Hive cache'ine ek olarak O(toplam rota noktası) binary/base64
snapshot'tır; büyük gerçek arşiv/native RAM ölçümü yapılmadı. Snapshot tamlığı mevcut
adapter'ın okuyabildiği korunacak alanlar içindir; eski kaldırılmış flow alanlarının
ham orijinal bytes yedeği değildir. Gerçek bozuk kutu/sahipsiz schema kanıtı yoksa
kayıt sessizce atlanmaz; hazırlık başarısız olur. Writer fence cross-process OS kilidi
değildir; gerçek kaynak path/kategori kapsamı ve GPS busy/recovery kontrolü kanıtlanmadan
adapter üretime bağlanmamalıdır. Kullanıcılar için safe local authorization ve gerçek
read-only source provisioning henüz tamamlanmış değildir.

## H. Karar

**Teslimat 1: KISMEN.** Repository/model ile bırakılmadı: çalışan sentetik ekran zinciri
ve source-preserving testler tamamlandı. Ancak cihaz-yerel yetkilendirme olmadığı için
gerçek kullanıcı erişimi güvenli biçimde kapalı tutuldu; native kabul yapılmadı.
Bu eksik tamamlanmadan erişimi veya production ownership gate'i açmak güvenli değildir.
Legacy World/Career merge bu teslimatın zorunlu bağımlılığı değildir.

Commit/push, Supabase, GPS journal v3 değişikliği, gerçek veri migration'ı, APK kurulumu
ve `tatus` üzerinde işlem yapılmadı. Teslimat sonrası başka geliştirmeye geçilmedi.
