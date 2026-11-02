# P-GR7I 4G — Play hesap silme runtime kabulü

## Dar kabul sonucu

**Durum: PASS (yerel istemci/runtime sözleşmesi).** Play runtime için yeni silme talebi artık yalnız geçerli account owner, canlı `LocalOwnerLease`, doğru PROD proje ve istek boyunca değişmeyen Supabase credential ile `delete-account` çağrısı yapabilir. Owner değişirse lease veya gateway kontrolü isteği durdurur. `LocalOwnerLifecycle.authorizeIdentityChange` aktif ve kurtarılabilir GPS kontrolünü çalıştırır; üretim bootstrap'ında bu kontrol foreground producer, SQLite journal aktif kaydı ve recoverable kayıtları kapsar.

Play controller/gateway yaratımı ayrıca `LocalOwnerLease.cloudDeletionEnabled` ister. Bu gate mevcut runtime build ayarlarına bağlı ve varsayılan kapalıdır; bu aşamada Auth/signup, cloud veya deletion gate açılmadı.

Yeni talep Edge Function'da kullanıcı JWT'sini doğrular, `expectedOwner` değerini gerçek UID ile karşılaştırır ve aynı hesapta mevcut parolayı yeniden doğrular. Receipt Secure Storage'a ağ isteğinden önce yazılır; parola receipt'e kaydedilmez. Yerel sürüş, Hive geçmişi, GPS journal ve owner store bu akışta silinmez veya taşınmaz.

## Oturum iptalinden sonra kurtarma

Play `run`/resume çağrısı yalnız `action`, request UUID ve 256-bit receipt token'ı gönderir. HTTP başlığında `Authorization` yoktur; başka hesaba ait JWT taşınmaz. Bir başka hesap oturum açmışsa owner-scoped receipt store o hesabın receipt'ini seçer; farklı owner receipt'i doğrulamadan ağa gönderilmez. Sunucunun `completed` yanıtı alınmadan yerel çıkış veya başarı durumu üretilmez. `pending`, `busy`, `blocked_planet`, 403 ve ağ hataları receipt'i korur.

Receipt resume için Edge Gateway JWT ön doğrulaması kapalı olmalıdır. Bu aşamada `supabase/prod/config.toml` veya manifest değiştirilmedi ve Edge Function dağıtılmadı; mevcut izole test runner'ı yalnız yerel stack için `verify_jwt=false` ayarlar. Gelecekte ayrıca onaylanacak deployment paketi de bu değeri açıkça tanımlamalıdır. Function'ın `request` eylemi kendi içinde kullanıcı JWT'sini ve parolayı doğrular; `run` eylemi veritabanındaki receipt hash/claim/lease kontrollerine dayanır. Worker eylemleri bağımsız worker token kontrolünü korur. Hosted deployment öncesinde bu sözleşme sunucu testleriyle yeniden kabul edilmelidir.

## Yerel test kanıtı

- Flutter hesap silme controller + gerçek Supabase SDK/`LocalOwnerLifecycle` sentetik HTTP testleri: **18/18 PASS**, exit code 0.
- Birleşik hesap silme, owner lifecycle, owner gateway ve 4F2B yayın regresyon paketi: **55/55 PASS**, exit code 0.
- Deno `delete-account/planet_rebuild_test.ts`: **8/8 PASS**, exit code 0.
- Mevcut Deno `supabase/prod/tests/account_deletion_test.ts` yerel servis uçtan uca paketi çalıştırılamadı: `run_pgr6a.ps1` mevcut test stack'inin API/DB endpoint'lerini CLI status'tan alamadı; önkoşul denetimi test başlamadan durdu. Docker named pipe de bu çalışma sırasında erişilebilir değildi. Bu, test PASS'i veya hosted kabul değildir.
- Tam `flutter analyze --no-pub`: exit code 1; **önceki baseline ile aynı 3 warning + 4 info**, bu değişikliklerden yeni bulgu yok.
- PROD release preparation self-test, mevcut Planet function kaynaklarında **11 manifest hash uyuşmazlığı** nedeniyle başarısız. Bu aşamada manifest yenilenmedi; bu kaynaklar 4G kapsamı dışında ve kör hash güncellemesi yapılmadı.
- PROD Auth, signup, deletion gate, worker, cron veya Edge Function değiştirilmedi/etkinleştirilmedi.

### Kapsanan kritik durumlar

- A hesabının owner gateway ile request'i ve fixed `Bearer A` credential'ı.
- Password reauth reddi ve kalıcı receipt.
- Active/recoverable GPS sırasında talebin ağ/receipt öncesi reddi.
- A→B geçişinde A isteğinin B token'ıyla devam etmemesi; A receipt'inin korunması.
- Logout sonrası receipt-only resume ve Authorization başlığının bulunmaması.
- B oturumunun A receipt'ini kullanamaması.
- Yanlış PROD hedefi/bozuk receipt reddi.
- `pending`, `busy`, `blocked_planet` ve 5xx durumlarının başarı sayılmaması.
- Terminal `completed` yanıtında yalnız A oturumunun kapatılması ve receipt'in kaldırılması.

## Yayın öncesi ayrı kabul şartları

- Gerçek Edge/Supabase local stack testleri ve RLS/worker retry kabulü.
- `delete-account` Edge Function ve gerekli secrets için ayrıca onaylı deployment.
- Hukuki veri saklama/Planet politikasının tamamlanması.
- Üretim hesabı, Auth ayarları ve gerçek cihaz kabulü.

Bu belge hosted veya fiziksel cihaz hesap silme kabulü anlamına gelmez.
