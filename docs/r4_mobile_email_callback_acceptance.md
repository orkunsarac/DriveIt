# R4 — Web sitesi olmadan mobil Auth e-postası

2 Kasım 2026. Dar yerel callback kabulü PASS; gerçek Gmail teslimatı ve Android link açılışı NOT TESTED. PROD ayarları değiştirilmedi, gerçek e-posta gönderilmedi.

## Doğrulanan sözleşme

- `lib/services/supabase_account_service.dart:566`: signup `emailRedirectTo: DriveItAuthCallback.uri`; satır 621: recovery `redirectTo: DriveItAuthCallback.uri`.
- `lib/config/driveit_auth_callback.dart`: paket bazlı scheme; Play `com.osaracx.driveit://auth/callback`; beklenmeyen host/path/port reddedilir.
- PROD Management API `GET /v1/projects/arwnbogcswisfesayosy/config/auth` salt okunur HTTP 200: `disable_signup=true`, tam Play callback allowlist içinde, Site URL localhost. Proje ACTIVE_HEALTHY.
- API'nin `mailer_templates_{confirmation,recovery,email_change,invite}_content` alanlarının dördü de özelleştirilmiş ve `ConfirmationURL` kullanıyor. Hiçbirinde `SiteURL`, doğrudan custom-scheme href veya literal localhost bulunmadı. Şablon gövdeleri ve SMTP bilgileri kaydedilmedi. İlk denetimde yanlış alan adları boş sonuç verdi; `_content` alanlarıyla düzeltilerek tekrar doğrulandı.

Supabase [mobil deep link belgesi](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) doğrulama ve parola kurtarma e-postalarının uygulamaya dönebildiğini belirtir. [Redirect belgesi](https://supabase.com/docs/guides/auth/redirect-urls) Site URL'yi açık redirect verilmediğindeki varsayılan olarak tanımlar ve mobil URI kullanımını destekler. [Şablon sözleşmesi](https://supabase.com/docs/guides/auth/auth-email-templates) kapsamında HTTPS Auth verify bağlantısı korunur; doğrudan `RedirectTo` bağlantısı doğrulama adımının yerine konulmaz.

Sonuç: mevcut açık parametreli ve izinli mobil akış için web sitesi veya Site URL değişikliği zorunlu değildir. Localhost varsayılanı, redirect vermeyen Dashboard/başka istemci işlemleri için hâlâ uygunsuzdur. Bu yollar mobil kabul kapsamına dahil edilemez. Gelecekte varsayılanı mobil URI yapmak ayrı onay ve test gerektirir; bu çalışmada değiştirilmedi.

## Gerçek test sonuçları

- `flutter test test/driveit_auth_callback_test.dart`: 6/6 PASS, exit 0.
- `tool/test_email_local.ps1`: 6/6 PASS, exit 0 (3 gerçek localhost Auth/Mailpit entegrasyonu + 3 statik sayfa testi).
- Mailpit testi gerçek Auth verify endpoint'inden mobil callback'e redirect, signup, recovery, çift e-posta değişikliği, tekrar link, yanlış adres ve rate-limit/retry davranışını doğrular. İzole paket callback'i kullanır; Play cihaz kabulü değildir.
- Genel signup ve Group Drive açılmadı; uygulama Auth/cloud ve hukuki kapıları değiştirilmedi.

## Gerçek teslimat için kalan kontrollü adım

Genel signup kapalıyken public `signUp` ile yeni kullanıcı oluşturulması beklenmez. Signup'ı açmadan kontrollü admin davetiyle hesap doğrulama/davet ve ardından recovery test edilebilir; bu, public signup kabulü olarak adlandırılamaz. Gerçek alıcı ve gönderim sayısı açıkça onaylanmalı. Gmail Inbox/Spam, linkin aynı kurulumdaki PKCE bağlamı, cold/warm Android açılışı ve tek kullanımlılık ayrıca doğrulanmalı. Admin tarafından üretilmiş bir linkin uygulamada başlatılmış PKCE signup ile aynı olduğu varsayılmaz.

Yeni gerçek gönderim veya test hesabı bu çalışmada oluşturulmadı. Hukuki yayın ve R5 web sayfaları ayrı kapsamdır; mevcut pending_legal_review korunur.

## Onaylı gerçek gönderim denemesi — SMTP engeli

Kullanıcı destek Gmail adresine bir davet ve bir recovery e-postasını açıkça onayladı. Sonraki tek davet isteği, tam Play `redirect_to` ile yalnız PROD `/auth/v1/invite` endpoint'ine gönderildi. HTTP 500 alındı; otomatik retry yapılmadı. Recovery isteği gönderilmedi.

Management API'nin salt okunur logs endpoint'i HTTP 200 döndürdü. Son 15 dakikanın Auth kaydı bellekte sınıflandırıldı: SMTP kimlik doğrulama reddi, `535` ve `BadCredentials` kanıtı bulundu. Ham log/SMTP credential/bağlantı tokenı dosyaya veya çıktıya yazılmadı. Kaynak: [Supabase logs API](https://supabase.com/docs/reference/api/v1-get-project-logs). Bu hata, şablon veya mobil redirect hatası olarak yorumlanmaz.

Salt okunur SQL kontrolü: `auth.users=0`, `r4_delivery_run` işaretli hesap sayısı 0; son 10 dakikada Auth audit olayı yok. Başarılı teslimat ve Android callback **NOT TESTED / SMTP nedeniyle BLOCKED**. Gönderim denemesi günlüğü repository dışında Windows DPAPI ile saklandı; belirsiz gönderimi otomatik tekrarlamamak için korunuyor.

Gerekli kullanıcı adımı: Gmail uygulama parolasının geçerliliğini kontrol ederek doğru SMTP kimlik bilgisini yalnız Supabase Dashboard'un güvenli SMTP alanında güncellemek. Parola Codex'e verilmez. Genel signup, Group Drive, Site URL ve diğer Auth ayarları değişmez. Kimlik bilgisi düzeltilmeden tekrar gönderilmez. Deneme aracı `tool/r4_email_delivery.ps1` henüz tam başarılı servis kabulü almamış yerel hazırlıktır; bu belge checkpoint'ine dahil edilmez.
