# P-GR6D — e-posta, web başvurusu ve gizlilik metni hazırlığı

Durum: **yerel hazırlık; kamuya yayınlanmadı, PROD Auth/SMTP/Edge/worker ayarı yapılmadı.** Bu belge ve web sayfaları hukuki onay değildir.

## Ücretsiz sağlayıcı kararı

- **Yerel geliştirme:** Supabase CLI'nin yerel Auth + Mailpit. Test iletileri loopback'te tutulur, internete gönderilmez. Bu, gerçek teslimat/itibar testi değildir.
- **PROD Auth e-postası:** Şimdilik üretime uygun, ücretsiz gönderici kararı yok. Supabase'in paylaşılan varsayılan göndericisi yalnız organizasyon ekibinde yetkili adreslere gider, şu an proje başına saatte 2 ileti sınırı ve SLA olmaksızın best-effort/test amaçlıdır; kullanıcı doğrulama ve parola kurtarma için üretim seçeneği değildir.
- `driveit.osaracx@gmail.com` **teknik olarak** aday olabilir: Supabase Auth SMTP sunucusuna bağlanır; Gmail, `smtp.gmail.com` TLS/STARTTLS (587) ve hesapta 2 adımlı doğrulama açıkken uygulama parolasıyla SMTP AUTH destekler. Google kişisel Gmail gönderimini 500 ileti/gün aşımında geçici olarak sınırlar; uygulama parolaları daha az güvenli istemci erişim aracıdır ve ana Google parolası değiştiğinde iptal edilir. Bu nedenle seçenek ücretsiz ve çalışabilir olsa da hesap güvenliği, kötüye kullanım/askıya alınma ve teslimat SLA'sı açısından **production-ready değil**; PROD'a yapılandırılmadı. Yalnız çok küçük, davetli beta için gerçek inbox/spam, bounce ve kota kabulü yapılıp ayrı onay verilirse geçici seçenek olarak düşünülebilir.
- Send Email Hook kendi e-posta sağlayıcısını yerine koymaz; yalnız mesajı özel sağlayıcı/API'ye yönlendirir. Secret, hata/timeout, bounce, abuse, teslimat ve veri işleyen sorumluluğu DriveIt'te kalır. Hook çalışmazsa Auth eylemi başarısız olabilir. E-posta değişiminde güvenli çift onay açık tutulmalı ve eski/yeni adres eşlemesi Supabase'in belgelenmiş token/hash sözleşmesine uygun yapılmalıdır.
- Resend gibi geliştirici e-posta servisleri ücretsiz kota sunabilse de gönderen domain doğrulaması ister; alan adı alınmaması şartında bu seçeneği uygulanabilir kabul etmedik. Ücretsiz tier ve politika değişebilir; karar zamanında yeniden doğrulanmalıdır.

**Karar:** Yerel test sağlayıcısı Mailpit'tir. Gmail SMTP ücretsiz, no-domain deneysel/çok küçük davetli beta adayıdır ama teslimatı kanıtlanmış production sağlayıcısı değildir. Bu aşamada PROD provider **seçilmedi ve yapılandırılmadı**; signup kapalı kalır. Daha geniş/garantili kullanım için alan adı veya ücretli/uygun gönderici şartı değişmelidir.

## Akışlar ve durum

| Akış | Yerel hazırlık | PROD durumu / sınır |
|---|---|---|
| E-posta doğrulama | Local Auth confirmation template; gerçek Mailpit testi | Signup kapalı; PROD template/SMTP değiştirilmedi |
| Parola kurtarma | Local Auth recovery template; gerçek Mailpit testi | Gerçek site URL/callback ve gönderici yok; kullanıcı akışı açılmaz |
| Parola değişikliği uyarısı | Local security notification template; gerçek Mailpit testi | PROD Auth notification ayarı değiştirilmedi |
| E-posta değişikliği | Local çift adresli confirmation test hazırlığı | Double-confirm korunmalı; gerçek adres/teslimat olmadan tamamlanmış kabul edilmez |
| Hesap silme başvuru/sonuç bildirimi | Web sayfası ve operatör yanıt taslağı | Otomatik mail/outbox eklenmedi. Silme sonrası Auth adresi yok olur; completion bildirimi için kalıcı e-posta saklamak ayrıca hukuki/teknik karar gerektirir. |

Silme tamamlanma bildirimi ancak ayrı bir bildirim outbox'ı, alıcı adresinin kısa ve açıkça tanımlanmış geçici saklama süresi, idempotent teslimat ve Auth silmesinden bağımsız retry kararı verildikten sonra geliştirilebilir. Şu an bir bildirim gönderilmiş gibi görünmez. İstek kabulü ile tamamlanma farklı durumlar olmalıdır; Planet `blocked_planet` başarı bildirimi değildir.

### Destek için metin taslağı (otomatik gönderim değildir)

- **Doğrulama:** “DriveIt hesabınız için silme talebi alındı. Bu talebi siz başlatmadıysanız onaylamayın. Talebin sahibi olduğunuzu doğrulamadan hesap veya işlem durumu açıklanmaz. Parola/OTP/oturum bağlantısı paylaşmayın.” Operatör yanıtı başvuru e-postasının `From`/`Reply-To` değerine değil, Auth'taki **verified** adrese göndermeli. Challenge tek kullanımlı, en az 128-bit rastgele ve 24 saatten kısa ömürlü olmalı; saklanırsa yalnız hash tutulmalı ve deneme limiti uygulanmalı.
- **Kuyruğa alındı:** “Talebiniz doğrulandı ve silme incelemesine alındı. Bu, tamamlandığı anlamına gelmez. Gezegen katkılarında doğrulanamayan bağımlılık varsa işlem ek inceleme bekleyebilir.”
- **Tamamlandı:** Yalnız terminal `completed` durumu ve Auth/Storage/DB yokluğu doğrulandığında: “Silme işlemi tamamlandı. Cihazınızdaki yerel sürüş geçmişi bu sunucu işlemiyle silinmez.” Auth silindikten sonra e-posta adresi yeniden sorgulanamaz; alıcıyı geçici saklayacak outbox kararı yoktur.
- **İnceleme gerekiyor:** “Talep henüz tamamlanmadı; güvenli inceleme sürüyor.” `blocked_planet`, retry, SMTP başarısızlığı veya sunucu hatası başarı metnine dönüştürülmez.

## Dış web başvurusu ve kötüye kullanım koruması

`site/account-deletion/index.html` Play'de gereken harici başvuru yolunun statik taslağıdır. E-posta bağlantısı kullanıcı hesabı, parola, OTP, JWT veya rota/GPS yüklemez. Talep mevcut doğrulanmış hesap adresinden başlatılmalı; destek görevlisi Auth'daki **doğrulanmış** adrese kısa ömürlü tek kullanımlık challenge göndermeli, reply-to/From alanını tek başına kimlik kanıtı saymamalı, challenge doğrulanmadan hesabın varlığını açıklamamalı veya silme başlatmamalıdır. Uygulama içi mevcut akış JWT UID eşleşmesi, aynı UID'ye parola yeniden doğrulaması ve açık silme onayını korur.

Statik GitHub Pages benzeri hosting bir form backend'i sağlamaz. Mailto yalnız ileti taslağı oluşturur; gönderim için kullanıcının onayı gerekir. Dışarıdan erişilen gerçek Play URL'si yoktur ve sayfa yayımlanmamıştır. Ücretsiz statik hosting olasılığı repo görünürlüğü, site sahibi ve URL kabulü doğrulanmadan kesinleştirilemez. Yayından önce destek yanıt süresi, challenge ömrü/yeniden kullanım koruması, operatör erişim denetimi, olay kaydı (ham e-posta/rota olmadan), tamamlanma ve başarısızlık bildirimleri uçtan uca kabul edilmelidir.

## Veri silme ve gizlilik taslağı

`site/privacy/index.html` **hukuki inceleme bekleyen taslaktır**. Mevcut P-GR6A–C adayının niyeti; Auth/profil, kişisel bulut sürüşü ve kaynak GPS/rota nesnesini silmek, Auth'ı son aşamada kaldırmak ve yerel cihaz arşivini uzaktan silmemektir. Bulut senkronizasyonu açık Planet yayın izni değildir. Planet katkısı yeniden hesaplanamaz veya sahipliği doğrulanamazsa iş `blocked_planet` kalır; silindi/tamamlandı denmez. Üretici yedekleri, e-posta sağlayıcı kayıtları, log/cache ömrü ve kanunen gerekebilecek kayıtlar hukuki inceleme bekler; kesin fiziksel silme süresi vaat edilmez.

Mevcut PROD'da signup kapalı; P-GR6 silme zinciri, dış başvuru sayfası ve worker PROD'a kurulmuş/etkin değildir. Bu sayfalar yayınlanırsa önce gerçek işleyiş ve metin düzeltmeleri gerekir.

## Yerel tekrar

`tool/test_email_local.ps1` yalnız `supabase/email-test/supabase/config.toml` içindeki sabit `driveit-email-pgr6d` yerel proje kimliği, 127.0.0.1 portları ve Supabase CLI Mailpit'i kullanır. Hiçbir DEV/PROD ref kabul etmez. Deno testi yalnız `example.com` için ayrılmış sentetik adres üretir, email/password içeriklerini test belleğinde tutar ve yalnız kendi Auth hesabı ile Mailpit mesajlarını temizler. Test gerçek e-posta göndermez. `supabase start` normal yerel CLI yaşam döngüsüdür; bu test aracı volume silme/reset/prune yapmaz.

Kaynaklar (1 Kasım 2026'da incelendi): Supabase [Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Auth Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook), [Auth e-posta testi/Mailpit](https://supabase.com/docs/guides/auth/testing-auth-flows), [CLI yerel SMTP ayarları](https://supabase.com/docs/guides/local-development/cli/config), [e-posta şablonları ve güvenlik bildirimleri](https://supabase.com/docs/guides/auth/auth-email-templates); Google [kişisel Gmail gönderim sınırı](https://support.google.com/mail/answer/22839?hl=en), [Gmail gönderen kuralları](https://support.google.com/mail/answer/81126?hl=en), [Gmail SMTP/app password](https://support.google.com/mail/answer/185833?hl=en-eu); [GitHub Pages erişilebilirlik](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages); Google Play [hesap silme URL şartı](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
