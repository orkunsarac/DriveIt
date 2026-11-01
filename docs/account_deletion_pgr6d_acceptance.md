# P-GR6D — ücretsiz e-posta ve dış hesap silme başvurusu hazırlığı

Tarih: 1 Kasım 2026. **Yerel hazırlık kabulü: PASS. PROD e-posta/yayın kabulü: NOT READY.**

## Yerel gerçek servis testi

`tool/test_email_local.ps1` özel `driveit-email-pgr6d` Supabase CLI projesini, Auth API `127.0.0.1:63121`, PostgreSQL `127.0.0.1:63122` ve CLI Mailpit `127.0.0.1:63124` ile çalıştırdı. Başlangıçta CLI `--workdir` altında `supabase/config.toml` beklediği için yapılandırma yerleşimi düzeltildi; sonra özel portlu servisler sağlıklı başladı. Var olan Phase 8 `54322` veritabanına dokunulmadı. Yerel CLI'nin oluşturduğu `.temp/start-secrets` test projesinin `.gitignore` kuralıyla korunur; hiçbir credential staged/committed değildir.

Son gerçek çıkış kodu **0**:

- Supabase Auth + Mailpit birleşik entegrasyon testi: signup doğrulama e-postası, doğrulama linki, parola kurtarma e-postası ve link doğrulaması, parola değişikliği bildirimi, eski ve yeni adrese e-posta değişikliği onayları, her iki onay sonrası adres değişimi ve güvenlik bildirimi: **PASS**.
- Başvuru web kaynağı/Play yolu ve parola/konum verisi istememe statik kontrolleri: **1 PASS**.
- Gizlilik taslağının hukuk onayı olmadığı, yerel arşiv ve Planet ayrımı kontrolleri: **1 PASS**.
- Deno sonucu: **3 PASS / 0 FAIL** (1 gerçek Auth/Mailpit entegrasyon senaryosu + 2 statik sayfa testi). Deno `check` ve PowerShell parse: **PASS**.
- Test sonrası kendi sentetik Auth hesabı ve yalnız kendisine gönderilen Mailpit mesajları bulunmadığı ayrıca doğrulandı.

Gerçek dış SMTP'ye e-posta gönderilmedi; test içeriği `example.com` sentetik adreslerine loopback'te tutuldu. Bu, Gmail/kurumsal inbox teslimatı, spam klasörü, SPF/DKIM/DMARC veya gerçek SMTP sağlayıcısı kabulü değildir.

## Sağlayıcı kararı

- Yerel test sağlayıcısı: **Mailpit**, test dışına gönderim yapmaz.
- Supabase varsayılan Auth göndericisi: ekibin izinli adresleriyle sınırlı, şu an saatte 2 mesaj ve best-effort; PROD Auth doğrulama/kurtarma için kabul edilmedi.
- `driveit.osaracx@gmail.com` SMTP ile teknik olarak kullanılabilir (Google hesabı 2SV + App Password, TLS/STARTTLS, gerçek gönderen Gmail kimliği). Google kişisel Gmail kotası 500 ileti/gün üzerindeki gönderimlerde geçici kısıtlama getirir; uygulama parolası ek hesap erişim riski taşır, ana parola değişince iptal olur ve teslimat SLA'sı yoktur. Bu nedenle yalnız çok küçük ve ayrı kabul edilmiş kapalı beta adayıdır; **bu aşamada seçilmedi/yapılandırılmadı ve production-ready sayılmadı**.
- Send Email Hook kendisi posta sağlayıcısı değildir. Resend/Brevo gibi servislerde ücretsiz plan olsa da alan adı doğrulaması/gönderici değiştirme gereksinimleri bu “alan adı satın alınmasın” koşuluyla uygun değil.

## Web başvurusu ve silme durumu

`site/account-deletion/index.html` DriveIt adını ve görünür harici e-posta başvuru bağlantısını içerir; yalnız `mailto:` taslağı açar, hiç veri/secret toplamaz, JavaScript kullanmaz ve no-referrer/CSP meta korumaları taşır. Dış kaynakta başvuru yolu olarak destek e-postası Google Play tarafından kabul edilen bir örnektir; ancak bu sayfa **kamuya yayımlanmadı**. GitHub Pages ücretsiz kullanımı public repository gerektirir; repository/site adresinin sahipliği ve yayın yolu henüz doğrulanmadı. Pages deploy workflow eklenmedi.

Kimlik doğrulama kötüye kullanım planı: başvuruyu Auth'ta `email_confirmed_at` mevcut adrese karşı doğrula; mailin `From`/`Reply-To` adresini kanıt sayma; hesap varlığını doğrulanmamış başvuruya açıklama; Auth verified adrese kısa ömürlü tek kullanımlı challenge gönder, challenge doğrulanmadan talep kabul etme. Mevcut silme request Edge'i JWT/UID eşleşmesi, güncel parola yeniden doğrulaması ve açık onay gerektirir. Fakat PROD'da P-GR6 silme zinciri ve worker kurulmuş/etkin değil; sayfa bu nedenle hazırlık uyarısı taşır ve üretim silmesini tamamlayamaz.

Hesap silme tamamlandı bildirimi otomatik değildir: Auth silindikten sonra alıcı adresi artık sorgulanamaz. Adresi bir outbox'ta geçici tutmak, silme worker'ı dışında yeni kişisel veri yaşam döngüsü yaratır; süre/erişim hukuki kararı verilmeden eklenmedi. Operatör için doğrulama, sıraya alma, tamamlanma ve `blocked_planet` inceleme mesajları taslakta bulunur; otomatik gönderildiği iddia edilmez.

`site/privacy/index.html` ve [bildirim/sağlayıcı kararı](account_deletion_email_notice_draft.md) hukuki inceleme bekleyen taslaklardır. Planet kişisel rota/katkı silme sözleşmesi uygulanacak aday mimaridir; sağlayıcı yedekleri, log/cache ömrü ve yasal saklama süresi karara bağlanmamıştır. Bu aşama veri sorumlusu hukuki onayını vermez.

## Sınırlar

PROD/DEV Auth, SMTP, Edge, worker/cron ve verileri değiştirilmedi; gerçek e-posta, gerçek kullanıcı silme, public site deploy, ücretli plan/alan adı, Android/Flutter ve Play işlemi yoktur. Signup ve Group Drive durumu değiştirilmedi.

Resmî dayanaklar: Supabase [custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook), [local Mailpit testing](https://supabase.com/docs/guides/auth/testing-auth-flows); Google [Gmail sending limits](https://support.google.com/mail/answer/22839?hl=en), [App Password](https://support.google.com/mail/answer/185833?hl=en-eu), [sender guidelines](https://support.google.com/mail/answer/81126?hl=en), [Google Play deletion web resource requirement](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en); GitHub [Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages).
