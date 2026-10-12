# Aşama 7 — Grup Sürüşü ilk dikey teslimat

## Aşama 6 checkpoint

`b42db26b8d6a0d47b25eff9a70dd4b23fa59ba76`:
`Complete phase 6 client and fake two-device sync acceptance`.
Normal push/fetch sonrasında yerel ve uzak HEAD eşleşti. Sekiz ilgili kaynak,
test ve belge dosyası commit edildi. Checkpoint öncesi hedefli regresyon 30/30
geçti; önceki tam kabul 908 geçti, 2 koşullu atlandı.

Client/fake sync kabulü TAMAMLANDI. `drive_sync_contract_phase6.md` ile
`phase6_offline_sync_client.md`, Aşama 8'e taşınacak zorunlu açık işleri korur:
production worker/Supabase sync, fail-closed delete sync için gerçek tombstone
identity/time/version/provenance, server lease/heartbeat/fencing, tutarlı
server cursor/snapshot ve cross-device World/Career projection. Production
ownership gate KAPALI; Aşama 5 fiziksel release kabulü hâlâ bekliyor.

## Yapılabilirlik ve gerçek bağlantılar

Karar: ilk üyelik/yönetim dikey teslimatı mevcut mimariyle yapılabilir.

- `HomeScreen` zaten Grup Sürüşü kartı içeriyordu. Açıkça enjekte edilmiş fake
  servis varsa kart owner navigator içindeki `/group` sayfasını açar.
- `OwnerPersonalNavigator` aynı `LocalOwnerBoundary` içinde çalışır. Her sayfa
  mevcut `LocalOwnerLease` alır; A→B geçişinde önceki ekran ve lease iptal olur.
  `GroupDriveScreen` ayrıca `LocalOwnerView` ile doğrudan açılmış sayfayı korur.
- Group ve invitation ID'leri ayrı opak UUID v4, üyelik ID'si ayrı UUID v4'tür.
  Ortak UUID üreticisi yalnız rastgele kimlik üretir; grup kaydı sürüş
  provenance'ı sayılmaz. Aktör kimliği `lease.owner.userId` UUID'sidir;
  görüntü adı kimlik veya yetki değildir.
- Limits ve yetkiler `FakeGroupDriveService` içinde uygulanır. Başarılı fake
  isteğin mutasyonu tek synchronous adımda tamamlanır; kapasite kontrolü ile
  katılım arasına `await` girmez. Bu gerçek sunucu transaction garantisi değildir.
- GPS, normal sürüş, finalization, World, Career, sync ve Planet depolarına
  bağımlılık/yazma eklenmedi. Yeni storage veya Android servis oluşturulmadı.
- Grup verisi sadece simulator'ın belleğindedir. Restart persistence, gerçek
  cihazlar arası paylaşım veya production üyelik güvenliği iddia edilmez.

## Teslim edilen kullanıcı akışı

Kontrollü owner navigation + açıkça enjekte edilmiş `FakeGroupDriveService`:

Ana ekran → Grup Sürüşü → Grup Oluştur → grup çalışma alanı ve üye listesi.
Diğer sentetik hesap: Ana ekran → Grup Sürüşü → kod/link → Davetle Katıl.
İki ekranın katılımcı listesi aynı fake servis olaylarıyla güncellenir.
Bekleme odası veya admin Başlat adımı yoktur.

Ekran sürekli "Yerel test • Fake grup servisi" ve canlı paylaşımın kapalı
olduğunu gösterir. Map workspace yalnız önizleme yüzeyidir: bu teslimatta gerçek
map tiles, canlı marker, GPS, konum izni/servisi, arka plan paylaşımı veya sahte
bir rota oluşturulmadı. Davet linki sürümlü `driveit://group/join?v=1&code=...`
modelidir; alan içinde parse edilebilir. OS deep-link/gerçek push daveti kaydı yok.

Admin dahil en çok 10 kişi; hesap başına tek aktif grup. Başka aktif gruba
sessiz geçilmez: mevcut gruptan açık ayrılma gerekir. Admin ayrıldığında en
erken katılan kalan üye yöneticidir (`joinOrder` aynı zaman damgasını da çözer).
Son üye ayrıldığında grup kapanır. Üye ayrılma, admin grup sonlandırma için
uygulama içi onay vardır. Sadece admin uzatır/sonlandırır.

Fake otorite saatine göre ilk 12 saat; en fazla iki +6 saat (24 saat toplam).
Süre sonunda join/extend reddedilir. UI bir defalık expiry refresh timer'ını
iptal edilebilir olarak kullanır; polling veya heartbeat oluşturmaz.

## Servis ve gelecek backend sözleşmesi

`GroupDriveService` owner lease'ten `GroupDriveClient` üretir. Client API:
`current`, `changes`, `create`, `join`, `extend`, `leave`, `end`.
Immutable snapshot grup/membership kimliklerini, roles, created/observed/expiry
zamanlarını, extension count, revision ve invitation içerir. Group exception
kodları offline, invalid_invite, group_full, group_inactive, admin_required,
membership_required, already_in_group, extension_limit, account_required.

Gelecek adapter aynı API'yi authenticated RPC + yalnız yetkili üyeler için
kapalı Realtime kanalına çevirebilir. Supabase kurulmadı. Sunucu:

- Aktörü client UUID assertion'ından değil Auth'tan çözmeli.
- Kapasite, tek aktif üyelik, admin devir/extend/end ve expiry'yi transaction
  ve server time ile uygulamalı; istemci timer'ı otorite değildir.
- Davet bearer code'u snapshot okuma yetkisi saymamalı; katılımdan önce özel
  üye listesini döndürmemeli. Gruba üye olmayan ID komutları reddedilmeli.
- Reconnect/replay/revision ve kalıcı üyelik restore sözleşmesini doğrulamalı.
- Admin invite on/off/rotate, removal/ban/unban kurallarını sonraki üyelik
  teslimatında tamamlamalı. Bu ilk dar kapsamda bu kontroller yoktur.

## Owner izolasyonu ve üretim sınırı

Guest ve unresolved owner erişimi reddedilir. `_request` async gecikmeden önce
ve sonra aynı lease'i doğrular. Eski epoch'ta kalan istek veri okumaz/yazmaz;
gecikmiş sonuçlar mounted/current kontrolünü geçmeden ekrana uygulanmaz.
Üye olmayan hesap group ID bilse bile komut veremez. Stream her olayda güncel
lease ve üyeliği doğrular. Dispose stream/timer/text controller'ı kapatır.

Fake servisi üretim main/bootstrap oluşturmaz. Normal Home default
`groupDriveAvailable=false` ile eski "yakında" davranışını korur. Yeni route
yalnız explicit fake service verilen kontrollü navigator'da kayıtlıdır.
Ownership gate, normal Auth veya GPS yolları değiştirilmedi.

## Test ve kabul

`group_drive_service_test.dart`: oluştur/join/retry, concurrent 11. katılımcı,
roles, 12/18/24 saat sınırları, earliest-member admin devir, last leave,
gruplar arası izolasyon, tek aktif üyelik, guest/unresolved/revoked erişim,
owner değişirken gecikmiş komut ve fake offline iken gerçek normal sürüş
finalization → owner History/rota → sync outbox kabulü.

`group_drive_ui_test.dart`: iki gerçek Home/owner navigator üzerinden
create/join → her iki listede A/B → iki uzatma → üye leave → admin end;
A→B→A ekran/cache izolasyonu, gecikmiş Future, 12 saat expiry,
bozuk invitation/offline UI ve simulator verilmediğinde eski Home davranışı.

UI fixture ilk denemede `pumpAndSettle` ile Home'un sürekli artwork
animasyonlarına takıldı. Test şimdi route'un gerçek 300 ms geçişini ve service
microtask'larını frame pump ile doğrular; uygulamaya sleep veya timeout
değişikliği eklenmedi. Sabit GlobalKey'li navigator'ın testte epoch boyunca
korunması yerine mevcut boundary'nin navigator oluşturması kullanıldı
(gerçek main composition zaten epoch değişiminde navigator key'ini yeniler).

Son doğrulamalar:

- Grup hedefli testler: 14/14 (9 servis, 5 gerçek UI/navigation widget testi).
- `flutter test --timeout=2m`: 922 geçti, 2 koşullu atlandı; başarısız yok.
- Atlananlar: izole Android compile-time backend guard testi ve Windows'ta
  symlink desteği gerektiren owner World/poster boundary testi.
- `flutter analyze`: önceden mevcut 4 info; yeni warning/error yok.
- `git diff --check`: başarılı. Yeni dosyalar da no-index check ile denetlendi.
- Android/A55 testi yapılmadı; bu teslimatın kabulü sentetik host UI/servis
  kapsamındadır. Aşama 5 fiziksel release kabulü geçmiş sayılmadı.

Değiştirilen dosyalar:

- `lib/screens/home_screen.dart`
- `lib/widgets/owner_personal_navigator.dart`
- `lib/features/group_drive/group_drive_models.dart`
- `lib/features/group_drive/group_drive_service.dart`
- `lib/features/group_drive/group_drive_screen.dart`
- `test/group_drive_service_test.dart`
- `test/group_drive_ui_test.dart`
- `docs/phase7_group_drive_first_delivery.md`

Sonuç: ilk dar kapsamlı Grup Sürüşü teslimatı EVET. Gerçek online grup, canlı
harita/konum, durable üyelik restore, admin invite/ban kontrolleri ve native
paylaşım kabulü tamamlanmış sayılmaz. Normal üretim entrypoint değişmedi.

## Sonraki tek teslimat

Canlı grup haritasının yalnız sentetik veriyle çalışan opt-in konum/pause
akışı: paylaşım için ayrı açık rıza, duraklatma/restoration, katılımcı marker
tazeliği ve mevcut normal GPS kaydından bağımsızlık. Android paylaşım servisi
ve gerçek Realtime kurulumu bu ilk teslimatın parçası değildir.

Bu ilk üyelik/yönetim UI→fake service→UI teslimatı tamamlandıktan sonra
durulur; Aşama 7 değişiklikleri commit/push edilmez.
