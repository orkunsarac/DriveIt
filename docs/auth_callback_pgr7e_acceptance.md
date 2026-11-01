# P-GR7E — Android Auth callback kabulü

Durum: **yerel teknik hazırlık**. Bu değişiklikler hosted Supabase Auth ayarlarını, DEV/PROD projelerini veya e-posta gönderimini değiştirmez. Google Play'e veya gerçek telefona yükleme yapılmadı.

## Akış

- Android callback yolu tam olarak `scheme://auth/callback` biçimindedir. `scheme`, Android `applicationId` değerinden üretilir; URI şemasında geçersiz olan `_` karakterleri `-` olur.
- Play paketi `com.osaracx.driveit` için callback: `com.osaracx.driveit://auth/callback`.
- Geliştirici paketi `com.example.driveit_project` için callback: `com.example.driveit-project://auth/callback`.
- İzole Android test paketi `com.example.driveit_project.isolated_test` için callback: `com.example.driveit-project.isolated-test://auth/callback`.
- Manifestteki intent filtresi scheme, `auth` host'u ve `/callback` path'ini tam eşler. Supabase Flutter SDK'sının URI predicate'i de çalışan paketin scheme'i, host/path, boş user-info/port ve Auth yanıt parametrelerini doğrular.
- Signup ve parola kurtarma istekleri `DriveItAuthCallback.uri` ile açık yönlendirme kullanır. Supabase Flutter 2.17.2'nin PKCE akışı açıkça seçilmiştir. SDK callback'i kendisi işler; uygulama callback URI'sini ikinci kez açıp tokenları uygulama loglarına yazmaz.
- Parola yenileme ekranı yalnız `passwordRecovery` olayı ve geçerli session birlikte oluştuğunda açılır. Geçersiz/expired/replay callback session üretmez; genel hata gösterilir. Mevcut kullanıcı oturumu bu hata halinde uygulama tarafından silinmez.
- Email-change bağlantısı aynı strict callback ve SDK oturum hattından geçer. Auth event/profile senkronizasyonu mevcut account owner bileşeninde kalır. Bu checkout'ta DriveIt içinde e-posta değiştirme talebi başlatan bir servis veya UI bulunmadı; callback gelen onayları işler, e-posta değiştirme talebi oluşturma özelliği eklenmedi.

## Hosted Supabase yapılandırması (henüz uygulanmadı)

Dashboard'da önce yalnız şu anki değerleri salt okunur biçimde teyit edin: Site URL, mevcut Redirect URL allowlist'i, signup/confirm ayarları ve Auth e-posta şablonlarında hangi redirect değişkeninin kullanıldığı. Bu görev hosted ayarları okumadı; değerler varsayılmadı.

Her proje için yalnız kendi uygulama callback'ini **exact URL** olarak ekleyin:

- PROD `arwnbogcswisfesayosy`: `com.osaracx.driveit://auth/callback`
- DriveIt DEV `viqngnjfgknpxtoapzcg`: `com.example.driveit-project://auth/callback`
- Yerel izole Android test profili: `com.example.driveit-project.isolated-test://auth/callback`

Wildcard eklemeyin. PROD Redirect URL listesine DEV veya isolated scheme eklemeyin. Mevcut Site URL'yi gözlemeden değiştirmeyin. Uygulama ilgili link isteklerine explicit redirect verir; Site URL'nin fallback olduğu durumlar için mevcut web hesabı/silme ve support akışlarını ayrıca doğrulayın. Site URL fallback'ini app callback'e taşımak ayrı bir Dashboard değişikliği ve geri dönüş planı gerektirir.

Hosted redirect değişikliği için kontrollü sıra: (1) mevcut değerlerin ekran görüntüsü/export'u ve proje ref kontrolü, (2) yalnız doğru ref'e tek exact Redirect URL ekleme, (3) redirect allowlist kontrolü, (4) kontrollü test, (5) hata varsa yalnız eklenen exact URL'yi kaldırıp önceki değerleri yeniden doğrulama. Bu belgeyle canlı değişiklik yetkisi verilmiş sayılmaz.

## Testler ve sınırlar

- `flutter test test/driveit_auth_callback_test.dart test/profile_onboarding_page_test.dart`: **19 test geçti, exit code 0**. Strict callback tuple, Auth response parametreleri, DEV/PROD/isolated scheme ayrımı, recovery event/session şartı, manifest placeholder, parola ekranı ve hesap akışı regresyonları kapsandı.
- `tool/test_email_local.ps1`: **6 test geçti, 0 başarısız, exit code 0**. İzole Supabase/Mailpit Auth confirmation, reset, double-confirm email change, invitation, malformed address, throttling/retry, replay link reddi ve statik silme/gizlilik sayfalarını kapsadı. Test sentetik Auth hesaplarını ve bunlara ait Mailpit iletilerini sonunda sildi.
- `dart analyze` (değişen Dart kaynakları ve ilgili testler): **No issues found, exit code 0**.
- `flutter build apk --debug --no-pub --target lib/main.dart --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`: **exit code 0**. APK yalnız `com.example.driveit_project.isolated_test` kimliğinde üretildi, cihaza yüklenmedi. `aapt dump badging` paket adını; APK manifest ağacı ise scheme `com.example.driveit-project.isolated-test`, host `auth` ve path `/callback` değerlerini doğruladı.
- `adb devices -l`: emülatör/cihaz doğrulanamadı; ADB daemon başlatılamadı. Bu nedenle cold-start/warm-start uygulama açılış kabulü yapılmadı.
- Yanlış host/path/scheme/port ve harici open-redirect query değeri kabul edilmez. İzole Auth testinde tek kullanımlık doğrulama linkinin ikinci kez reddedilmesi kontrol edildi. Saat bekletilerek gerçek OTP expiry entegrasyon testi yapılmadı; expired callback'in güvenli hata/session davranışı emülatör kabulünde ayrıca doğrulanmalıdır.
- Custom URI scheme aynı cihazda kötü niyetli bir uygulama tarafından sahiplenilebilir. PKCE kod değişimini sınırlar; ancak verified HTTPS App Link kadar güçlü uygulama sahipliği kanıtı değildir. Gerçek cihaz kabulünde callback chooser/hijack davranışı ve prod sertifikalı paketin scheme eşleşmesi kontrol edilmelidir. HTTPS App Link kullanımı için doğrulanmış bir alan adı ve `assetlinks.json` gerekir; bu aşamada alan adı eklenmedi.
- Test/derleme, fiziksel cihazda cold-start, warm-start, Gmail link açma, farklı cihazda link tıklama veya Gmail gerçek teslimat kabulü yerine geçmez.

## Gerçek cihaz kabul adımları

1. Yalnız isolated applicationId ile test paketi yükleyin; gerçek DriveIt uygulamasına uninstall/clear-data yapmayın ve kullanıcı sürüşlerini koruyun.
2. Isolated Supabase/Mailpit üzerinden alınmış sentetik confirmation ve recovery linklerini uygulama kapalıyken ve arka plandayken açın.
3. Doğru callback'in isolated uygulamaya gelmesini, yanlış scheme/host/path'in işlem başlatmamasını doğrulayın.
4. Recovery olayında yeni parola ekranının açıldığını; linki tekrar açınca oturum/parola güncellenmediğini ve güvenli hata gösterildiğini doğrulayın.
5. Önceden açık session'ın başarısız callback'te değişmediğini ve guest/account owner geçmişinin etkilenmediğini doğrulayın.
6. Email change onayının yalnız ilgili Auth hesabını güncellediğini ve uygulama profile/owner state'inin doğru hesaba ait kaldığını doğrulayın.
7. Play imzalı pakette test etmeden önce prod Redirect URL'nin yalnız `com.osaracx.driveit://auth/callback` içerdiğini ve Gmail/Supabase hosted link zincirinin bu URI'yi koruduğunu gözden geçirin.

Bu yerel kabul, hosted Auth ayarlarını veya gerçek cihaz uçtan uca davranışını PASS ilan etmez.
