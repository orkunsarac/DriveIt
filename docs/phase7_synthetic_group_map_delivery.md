# Aşama 7 — Sentetik grup haritası ve paylaşım kontrolleri

## Başlangıç checkpoint

İlk Aşama 7 teslimatı `c3c8a1b7af6ceb04839a1a44ae40db606b7f31ae` commit'iyle
`feature/gps-refactor` dalına normal push edildi. Yerel ve uzak HEAD eşleşti.
Sekiz ilgili kaynak/test/docs dosyası dahil edildi; hedefli 14/14 yeniden geçti.
Önceki tam regresyon 922 geçti, 2 koşullu atlandı.

Bu belgedeki yeni değişiklikler kullanıcı incelemesine bırakıldı; commit/push
yapılmadı. Production ownership gate KAPALI. Aşama 5 fiziksel izole release
kabulü hâlâ bekliyor; bu sentetik host kabulü onun yerine sayılmaz.

## Harita ve çalışan ekran akışı

`GroupDriveScreen`, mevcut `google_maps_flutter` SDK'sını kullanan
`GroupDriveMap` gösterir. Yeni SDK veya bağımlılık yok. `DriveMapVisuals` koyu
harita stili kullanılır. Device location layer ve location button kapalıdır;
Geolocator, permission veya cihaz GPS okuması eklenmedi.

Her consented son nokta membership ID'li marker olur. Kendisi mavi; diğer
üyeler mevcut üyelikleri boyunca ayrı renk slotlarını korur. Ad ve son
güncelleme bilgisi InfoWindow'da, paylaşım durumu katılımcı listesinde görünür.
Marker seçimi üyeyi seçip gerçek GoogleMapController camera komutunu üretir.
Controller ömrü ve lease kamera komutundan hemen önce doğrulanır; dispose
timer'ları iptal eder. Polylines/rota geçmişi veya Map Matching yoktur.

Harita ve örnek gönderme kontrolü bütün koordinatların sentetik olduğunu
açıkça belirtir. Ekrandaki **Sentetik Nokta Gönder**, test saatinde üretilen
kurgusal bir nokta gönderir; cihaz konumu okunmaz. Harita boşken (0,0) yalnız
başlangıç viewport'udur, konum kaydı/marker değildir.

Eski noktalar 15 sn sonrasında soluk, 30 sn sonrasında gri/soluk gösterilir;
5 dk sonrasında marker kaldırılır, üye listede kalır. Yerel one-shot timers
yalnız tazelik sınırlarında UI'ı yeniler; ağ polling'i yapmaz. Gecikmiş timer
yerel geçen süreyi de hesaba katar. 15 sn sınırında integer rounding kaynaklı
yeni fade hatası widget testiyle bulundu ve Duration karşılaştırmasıyla
düzeltildi. Gönderimde 15 sn'den eski, gelecekteki veya sırasız örnekler reddedilir.

## Açık rıza ve paylaşım durumu

Üyelik sharing yetkisi değildir. Her yeni üyelik KAPALI başlar. Başlat/Devam
Et açıklama ve ayrı onay dialog'u açar. Onay group ID, membership ve mevcut
owner lease bağlamında yeniden doğrulanır. PAYLAŞILIYOR durumuna geçmek,
henüz bir koordinat göndermez; ayrıca sentetik nokta gönderilmelidir.

Duraklatma -> DURAKLATILDI; kapatma -> KAPALI. Her ikisi publication fence'i
ve son koordinatı anında kaldırır. Diğer üyeleri görme yetkisi üyelikle sürer;
duraklatan üye diğerlerini görür. Devam Et kullanıcı hareketi ve yeni onay
ister, yeni publication ID üretir; eski konum geri konmaz.

Pause/stop, bekleyen fake publish sırasında da kullanılabilir. Fake transport
offline iken de yerel withdrawal senkron uygulanır. Bu in-memory simulator
garantisidir: gelecekte gerçek uzaktaki alıcılar için revoke mesajı, retry ve
TTL sözleşmesi ayrıca gereklidir.

Leave üyeliği ve noktasını kaldırır. End/expiry bütün grant ve noktaları siler.
Owner lease iptali (A→B) publisher'ı DURAKLATILDI yapar ve koordinatı kaldırır.
Sayfa/client kapanması da yayını keser. Aynı fake servis üzerinde client
yeniden oluşturulunca paylaşım otomatik başlamaz. Fake servis tümüyle
yeniden başladığında bellek sıfırlanır; durable üyelik/pause/reboot restore
bu teslimatta uygulanmış sayılmaz (yeniden paylaşım varsayılan olarak kapalı).

## Fake service ve yarış bariyerleri

Mevcut `GroupDriveClient` dört paylaşım komutu ve close ile genişletildi:
`startSharing(consent)`, `pauseSharing`, `stopSharing`, `publishSynthetic`.
Grant group, membership, opak publication ID, owner epoch ve start time taşır.
Konum latitude/longitude, UTC recordedAt ve monoton sequence taşır.
Fake service yalnız son örneği saklar; buffer/history tutmaz.

Her publish authenticated fake owner/lease, halen aktif grup, üyelik,
PAYLAŞILIYOR durumu, issuer client, kalıcı olmayan revocable grant, membership
ID, epoch, start time ve sequence doğrulamalarından geçer. Async fault seam
sonrasında bu koşullar tekrar denetlenir. Pause/resume, leave/rejoin ve A→B
sonrasındaki eski grant veya bekleyen olay reddedilir. Başka grubun konumları
current/changes sonucuna giremez. Kaynak kimliği/güncellik uydurulmaz.

## Normal sürüş ve üretim sınırı

Normal `/drive`, foreground service, GPS journal v3, finalization, Score,
World ve sync kodları değiştirilmedi. Aktif sentetik paylaşım + offline grup
servisi sırasında gerçek kontrollü `ForegroundService.start` → journal →
owner Hive save → History rota → sync outbox akışı test edildi.

Fake servis hâlâ yalnız kontrollü navigator'a açıkça enjekte edilir.
Production main/bootstrap veya gate değiştirilmedi. Gerçek GPS/konum izni,
Supabase/Realtime, Android background service veya gerçek kullanıcı verisi
kullanılmadı. Harita widget testinde native plugin/tiles test double kullanır;
bu gerçek cihaz harita rendering veya backend kabulü değildir.

## Testler

- Servis: A/B/C opt-in görünürlük; hiç açmayan B; pause/resume/off; başka
  üyeyi görmeye devam; delayed publish/pause yarışı; leave/rejoin grant sınırı;
  end/expiry; owner iptali; başka grup; stale/future/duplicate örnek;
  client recreation sonrası otomatik paylaşmama.
- Gerçek Home/navigator UI: oluştur/join -> ayrı consent cancel/approve ->
  send -> GoogleMap marker set -> blue self -> focus camera command ->
  pause -> resume (eski nokta yok) -> send -> off -> leave -> end.
- GoogleMap tazelik testi: 15/30/300 saniye; expired grup ve owner switch
  sonrası marker temizliği; gecikmiş UI gönderimi.
- Normal save/outbox: paylaşım açık ve fake servis offline iken geçer.
- Mevcut üyelik/roles/limits/UI regresyonları korunur.

Son doğrulama:

- Hedefli: 25/25 (9 üyelik/normal save servis, 7 paylaşım servis,
  9 gerçek ekran/navigasyon/map widget testi).
- Tam `flutter test --timeout=2m`: 933 geçti, 2 koşullu atlandı; başarısız yok.
- Atlananlar: izole Android compile-time guard ve Windows symlink koşullu
  owner World/poster boundary testi.
- `flutter analyze`: yalnız önceki 4 info. Yeni if-block stil notları
  giderildikten sonra hedefli 25/25 tekrar geçti.
- `git diff --check` ve dört yeni dosyada no-index whitespace check başarılı.
- A55/native harita testi yapılmadı; bu teslimatın şartı değildi.

Teslimat: EVET — sentetik grup UI → fake service → mevcut GoogleMap widget
ve paylaşım kontrolleri tamamlandı. Gerçek GPS/backend/foreground kabulü
tamamlanmış sayılmaz.

## Değiştirilen dosyalar

- `lib/features/group_drive/group_drive_models.dart`
- `lib/features/group_drive/group_drive_service.dart`
- `lib/features/group_drive/group_drive_screen.dart`
- `lib/features/group_drive/group_drive_map.dart` (yeni)
- `test/group_drive_service_test.dart`
- `test/group_drive_ui_test.dart`
- `test/group_drive_map_fake.dart` (yeni host platform double)
- `test/group_location_service_test.dart` (yeni)
- `docs/phase7_synthetic_group_map_delivery.md` (yeni)

## Kalan gerçek işler

Gerçek GPS provider/filtreleme, explicit OS izinleri, Android birleşik
foreground notification/service ve pause/reboot persistence, tam kamera ve
marker/cluster davranışları henüz geliştirilmedi. Gerçek backend membership
auth/RLS, expiry/invite/ban ve Realtime/presence/revocation/TTL Aşama 8'de
kanıtlanmalıdır. Bu teslimat yalnız sentetik map/paylaşım kabulüdür.
