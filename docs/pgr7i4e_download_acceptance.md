# P-GR7I 4E — güvenli download dar kabulü

Sonuç: **PASS — yerel SDK/owner/yerel kayıt entegrasyonu**. Genel Play Auth/cloud gate'leri etkinleştirilmedi. Hosted ve fiziksel cihaz kabulü NOT TESTED.

## Üretim bağlantısı

`SupabaseOwnerDriveSyncAdapter.download` için önceki koşulsuz gateway engeli kaldırıldı. Ortak `_ownerData` yolu 4D factory'sinin oluşturduğu `OwnerProfileGateway` ile hem upload hem download işlemlerini onaylı owner/epoch ve tek HTTP işlemine sabitlenmiş credential'a bağlar. Play kompozisyonu gateway olmadan adapter oluşturamaz. DEV istemci yolu korunur. İstek ve yanıt kontrolleri, cursor/snapshot ayrıştırması, mutation UID/scope doğrulaması değiştirilmedi. M2 silme/lease işlemleri Play için kapalıdır; Planet/Group ve aktivasyon gate'leri değiştirilmedi.

Mevcut `LocalOwnerLease._downloadCloudPage` backend kontrolü ve fetch sonrasında `lease.run` ile `OwnerDriveSyncClient.applyDownloadPage` çağırır. Lease ve gerçek Auth UID her sayfanın uygulanmasından önce/sonra kontrol edilir; hesap değişimi eski store'a ait lease'i iptal eder. Yerel kayıtların read-back ve cursor kalıcılık sözleşmesi aynı kalır. Yeni mimari veya veri şeması eklenmedi.

## Gerçek SDK + gerçek lifecycle testleri

`test/owner_download_real_lifecycle_test.dart` gerçek Supabase SDK, SupabaseLocalOwnerAuth, LocalOwnerLifecycle, LocalOwnerLease, üretim adapter ve gerçek izole Hive depolarını kullanır. HTTP/Storage yanıtları sentetiktir; ağ anahtarı veya gerçek rota yoktur. Sürüş fixture'ı mevcut sync regresyonundaki sentetik kanıtlanmış rota/telemetri/skor yapısını kullanır.

| Senaryo | Sonuç ve kanıt |
| --- | --- |
| A sürüşünü alma ve ikinci cihaz deposuna geri yükleme | PASS: iki farklı dizin, iki yerel sürüş, telemetri korunumu ve A HTTP credential kontrolü |
| Çoklu sayfa/cursor ve duplicate | PASS: 0→1→2 cursor, tekrar snapshot'ta iki History kaydı |
| A→B sırasında geç sayfa | PASS: B deposu boş, eski yanıt reddi, B token'ı A isteğine taşınmıyor |
| Epoch, aynı UID credential refresh, logout | PASS: bekletilmiş sayfa her değişimde reddediliyor; cursor/History uygulanmıyor |
| Yabancı mutation UID ve yanlış Play projesi | PASS: History/cursor yazmadan reddediliyor |
| Offline, bozuk veri, retry ve restart | PASS: ilk sayfa ve sürüş korunuyor; aynı dizinde yeni lifecycle kaldığı cursor'dan devam ediyor. Android süreç restart testi değildir |
| Silinmiş kayıt | PASS: normal silme önkoşulu önce reddediliyor ve kayıt korunuyor; tamamlanmış yerel silme fixture'ının replay ile geri gelmediği doğrulanıyor. Gerçek cloud silme açılmaz |
| Eşzamanlı upload/download | PASS: gerçek adapter upload staging/Storage/finalize, bekleyen download sayfası tamamlanmadan bitiyor; tüm istekler A credential kullanıyor |
| Guest/legacy/eski DEV verisinin otomatik upload olmaması | PASS: mevcut uygunluk/scheduler regresyonları; Android paket veri izolasyonu bu aşamada yeniden test edilmedi |
| Kayıp ACK/idempotency, tombstone ve upload regresyonu | PASS: mevcut üretim client/adapter testleri yeniden çalıştırıldı |

## Çalıştırılan doğrulamalar

`flutter test --no-pub test/owner_download_real_lifecycle_test.dart test/owner_upload_real_lifecycle_test.dart test/supabase_owner_drive_sync_adapter_test.dart test/owner_drive_sync_client_test.dart`: **76 PASS, 0 atlanan, exit 0**.

`flutter analyze --no-pub`: **3 warning + 4 info**, mevcut baseline, yeni bulgu yok; **exit 1**. `git diff --check`: PASS.

İlk test koşusu sentetik HTTP JSON content-type eksikliği nedeniyle başarısızdı; fixture düzeltildi. Silme testindeki gerçek bağımsız kaynak/Career koruması korunarak fixture tamamlanmış silme kanıtı ile düzenlendi. Hiçbir assertion kaldırılmadı veya test atlanmadı.

## Kabul sınırı

İzole iki depo fiziksel iki telefon değildir. Mock HTTP'nin kabul ettiği token, gerçek hosted token imzası/RLS kanıtı değildir; istemci token eşlemesi ve değişim yarışı doğrulanır. Gerçek PROD/DEV bağlantısı, cihaz kurulumu, signup, cloud aktivasyonu ve diğer veri yollarının kabulü yapılmadı. Mevcut R1/signing ve ilgisiz yerel dosyalar korunur.
