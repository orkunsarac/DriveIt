# DriveIt P-GR7A — Auth e-posta seçenekleri ve yerel kabul

İnceleme tarihi: 1 Kasım 2026. **Yerel test kabulü dışında canlı teslimat doğrulanmadı.** Bu not PROD SMTP etkinleştirme veya signup açma onayı değildir.

## Öneri ve karar

Özel alan adı ve ücretli servis olmadan, son kullanıcı hesap doğrulaması/parola kurtarma için belgelenmiş bir SLA ile “güvenilir production gönderimi” sağlayan seçenek doğrulanamadı. Ücretsiz kotalar, alan adı sahipliği ve gönderen itibarı sorununu tek başına çözmüyor.

- **Bugün kullanılacak:** geliştirme ve CI'da yalnız Supabase CLI + Mailpit. Mesajlar loopback test servisinde yakalanır; gerçek teslimat iddiası değildir.
- **Deneysel no-domain aday:** `driveit.osaracx@gmail.com` hesabının kendi SMTP'sine (`smtp.gmail.com`, port 587, STARTTLS) bağlanması. Bu, ücretsiz/teknik adaydır; yalnız kullanıcının ayrıca onayladığı küçük kapalı-beta teslimat denemesinden sonra değerlendirilebilir. Gmail App Password ayrıcalığı, hesap askıya alınması, kullanıcı başına kota/rate-limit ve SLA yokluğu nedeniyle production-ready değildir.
- **Send Email Hook:** gönderici değildir. Auth mesajını özel HTTP handler'a devreder; sağlayıcı, secret, sıra, timeout, retry, bounce, kötüye kullanım ve gözlemlenebilirliği uygulama işletmecisi üstlenir. Sağlayıcı kotasını veya domain gereksinimini ortadan kaldırmaz.
- **PROD:** sağlayıcı seçilmedi, credential yok, SMTP/Hook ayarı değiştirilmedi. Signup kapalı kalmalıdır.

## Seçenek karşılaştırması

| Seçenek | Ücretsiz sınır / gereksinim | Bu koşullarda değerlendirme |
|---|---|---|
| Supabase yerleşik gönderici | Şu an 2 ileti/saat; yalnız proje ekibinde önceden izinli adresler; best-effort ve SLA yok. | Yerel deneme/şablon keşfi dışında son kullanıcıya uygun değil. |
| Gmail kişisel SMTP | `smtp.gmail.com`, SMTP AUTH, TLS/STARTTLS 587. App Password için Google hesabında 2 adımlı doğrulama gerekir. Kişisel Gmail'de 500'den fazla ileti/gün geçici kısıta yol açabilir; kesin SLA yok. | Domain satın almadan teknik olarak en doğrudan aday, çünkü Gmail hesabı kendi `gmail.com` gönderen kimliğinden gönderir. App Password hesap güvenliği riski ve teslimat kabulü gerekir. Google ana parolası değiştirilirse App Password iptal olabilir. |
| Brevo Free | Güncel Free kotaları: 300 ileti/gün; ücretsiz e-posta göndereni doğrulansa bile Brevo yönetimli gönderen alan adıyla değiştirilir. Gmail/Yahoo gibi public domain'ler Brevo'da domain olarak doğrulanamaz; alan adı kimlik doğrulaması için sahip olunan domain gerekir. | DriveIt adresinden güvenilir/aligned Auth gönderimi olarak kabul edilemez; kullanıcıya gösterilen gönderen değişebilir. |
| Mailjet Free | 6.000/ay, en çok 200/gün ve 1.000 kayıtlı kontak. Bir gönderen e-posta adresi doğrulanabilir; domain doğrulama ve SPF/DKIM tavsiye edilir. | Kota yeterli görünse de Gmail adresini üçüncü taraf relay'den göndermek domain alignment/itibarını ve Gmail gönderen politikalarını kanıtlamaz. Gerçek header/inbox testi olmadan uygun veya güvenilir ilan edilmez. |
| Resend Free | 3.000/ay, en çok 100/gün ve üç domain (güncel plan). Üretim gönderimi doğrulanmış gönderim domain'i ister. | Domain satın almama koşuluna uymuyor. |

Kotalar ve plan adları değişebilir; kuruluma başlamadan önce sağlayıcı panosunda tekrar kontrol edilmelidir. “Ücretsiz” kota veya doğrulanmış sender, inbox teslimatı, SLA, KVKK sözleşmesi ya da yasal uygunluk kanıtı değildir.

## Yerel yapılandırma ve araç

`supabase/email-test/supabase/config.toml` yalnız `driveit-email-pgr6d` yerel projesini, loopback Auth/Mailpit portlarını, doğrulamayı, eski+yeni e-posta çift onayını ve kısa test frekansını tanımlar. `[auth.rate_limit] email_sent=20` yalnız bu izole test projesinde, per-address `max_frequency=1s` 429 davranışını proje saatlik kotasına takılmadan sınamak içindir; PROD önerisi değildir.

`tool/test_email_local.ps1` test başlamadan proje kimliğini, sabit yerel portları, test rate ayarlarını, PROD/DEV ref yokluğunu ve dış SMTP hedefi olmadığını doğrular. Supabase CLI `status --output env` değerleri yalnız işlem belleğinde tutulur; terminale anahtar yazdırılmaz. Auth/Mailpit erişimi Deno'da yalnız `127.0.0.1` ile sınırlandırılır. Testler yalnız kendilerinin oluşturduğu `example.com` sentetik Auth hesaplarını ve Mailpit mesajlarını temizler. Gerçek SMTP, dış e-posta, PROD/DEV veya gerçek kullanıcı kullanmaz.

## Test kapsamı

`tool/test_email_local.ps1` şu senaryoları gerçek yerel Supabase Auth ve Mailpit üzerinde çalıştırır:

- Kayıt doğrulama mesajı ve tek kullanımlık doğrulama linki
- Parola kurtarma mesajı/linki ve sentetik kullanıcı ile giriş
- Parola değişikliği bildirimi; mesajda parola/oturum tokenı olmadığının kontrolü
- E-posta değişiminde eski ve yeni adrese ayrı onay, iki onaydan sonra adres değişimi ve güvenlik bildirimi
- Hatalı adresli kayıt ve recovery isteğinin reddi
- Recovery isteği için anlık tekrarın `429 over_email_send_rate_limit` alması ve yeni mesaj üretmemesi
- Bekleme aralığı sonrasında kontrollü recovery tekrarının yeni mesaj üretmesi
- Her sentetik Auth hesabı ve yalnız bu hesaba ait Mailpit mesajlarının temizlendiğinin doğrulanması

Bu testler SMTP sağlayıcısının gerçek teslimatı, spam/bounce, DNS SPF/DKIM/DMARC, Gmail hesap limitleri veya Supabase hosted SMTP yapılandırmasını doğrulamaz.

## Gmail SMTP için güvenli, onaylı kurulum prosedürü

Bu prosedür yalnız ayrı PROD SMTP ve gerçek teslimat onayından sonra uygulanabilir. Bu belge bir credential istemez ve SMTP secret saklamaz.

1. Gmail hesabında 2 adımlı doğrulamayı aç; Google'ın verdiği App Password'ü yalnız parola yöneticisinde veya doğrudan Supabase Dashboard'un Auth SMTP credential alanında oluştur/kullan. App Password'ü Codex'e, sohbete, PowerShell argümanına, kaynak koda, repo dosyasına veya loga verme.
2. Supabase Dashboard'da yalnız doğrulanmış PROD proje ref'ini kontrol et. Custom SMTP host `smtp.gmail.com`, port `587`, güvenli STARTTLS; kullanıcı adı ve From adresi aynı tam `driveit.osaracx@gmail.com`; görünen sender `DriveIt` olarak ayarla. Supabase'in SMTP TLS doğrulamasını kapatma. Parola yalnız dashboard'un gizli alanına girilir.
3. `disable_signup=true` korunur. Önce yalnız önceden belirlenmiş yetkili alıcılarla gerçek gönderim testi için ayrı onay alınır; hesabı açmadan önce SMTP teslimat, SPF/DKIM/DMARC başlıkları, inbox/spam, link host/redirect, expiry, tek kullanımlık doğrulama, recovery, iki adresli email-change ve mesaj şablonları kabul edilir. Gönderim limiti ve abuse izlemi seçilir.
4. Test başarısızsa custom SMTP'den gelen başarısızlığı başarı gibi yorumlama; signup kapalı kalır. Auth rate limitini yükseltme veya confirmation kapatma yoluyla aşma.

### Geri alma

1. PROD signup kapalı tutulurken Dashboard'dan önceki Auth SMTP değerlerini/ayar durumunu kontrol et; credential değerini dışarı kopyalama veya raporlama.
2. Gmail göndereni istikrarlı değilse Custom SMTP'yi devre dışı bırakıp Supabase'in yerleşik göndericisine dönülebilir; bu yalnız ekip adresleri ve geçici düşük limitli tanılama içindir, kullanıcı e-postası için güvenilir geri dönüş değildir. Kullanıcı akışını açma.
3. Gmail hesabındaki ilgili App Password'ü Google hesap güvenliğinden iptal et; başka Auth ayarını, Signup'ı veya redirect listesini değiştirme.
4. Dashboard'da SMTP'nin kapalı/eski güvenli duruma döndüğünü ve signup'ın hâlâ kapalı olduğunu tekrar oku. Eski custom credential'ın provider/hosted secret kasasından kaldırılması sağlayıcının gerçek arayüzünde ayrıca doğrulanmalıdır.

## PROD kabul kapıları

- Ürün/veri koruma ve gerçek callback URL'leri onaylanmış olmalı.
- SMTP sağlayıcı şartları, gönderim verisinin bölgesi/işlenmesi ve ücretsiz plan kullanım koşulları ayrıca değerlendirilmiş olmalı.
- Gerçek QA alıcılarına gönderim ayrı onaylanmalı; test adresi dışında gönderim bu görevde yapılmadı.
- Başarılı inbox teslimatı, spam/bounce, kimlik doğrulama başlıkları, rate-limit ve retry, güvenli link yönlendirmesi, gizlilik içerikleri ve destek prosedürü gerçek uçtan uca kabulden geçmeli.
- Supabase Auth hesabına App Password veya başka SMTP credential yalnız dashboard secret alanından girilmeli; repository, CI log, test fixture veya analytics'e girmemeli.
- `disable_signup=true` ve diğer güvenlik ayarları ayrıca doğrulanmalı. Bu çalışma signup, PROD/DEV, SMTP, kullanıcı veya deployment durumunu değiştirmez.

## Kaynaklar (resmî, 1 Kasım 2026'da kontrol edildi)

- Supabase: [Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook), [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits), [local Auth/Mailpit test flows](https://supabase.com/docs/guides/auth/testing-auth-flows), [CLI config](https://supabase.com/docs/guides/local-development/cli/config).
- Google: [Gmail SMTP setup](https://support.google.com/mail/answer/7104828?hl=en-GB), [App Passwords](https://support.google.com/accounts/answer/185833?hl=en), [sending limits](https://support.google.com/mail/answer/22839?hl=en), [sender guidelines](https://support.google.com/mail/answer/81126?hl=en).
- Brevo: [Free plan limits](https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan), [domain authentication](https://help.brevo.com/hc/en-us/articles/12163873383186-Authenticate-your-domain-with-Brevo-Brevo-code-DKIM-DMARC), [sender setup](https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email).
- Mailjet: [Free plan limits](https://documentation.mailjet.com/hc/en-us/articles/19154256993051-Understanding-Mailjet-Free-Plan-Limits), [sender validation and SPF/DKIM setup](https://documentation.mailjet.com/hc/en-us/articles/37251169295003--Quick-Start-with-Mailjet).
- Resend: [current pricing](https://resend.com/pricing), [domain verification overview](https://resend.com/migrate/sendgrid).
