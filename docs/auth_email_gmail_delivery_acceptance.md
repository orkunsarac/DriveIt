# DriveIt P-GR7B — Gmail SMTP gerçek teslimat kabul planı

Durum: **Hazırlık tamam; gerçek teslimat yapılmadı, SMTP yapılandırılmadı, PROD/DEV değişmedi.** Bu belge onay yerine geçmez. Kullanıcı kaydı `disable_signup=true` olarak kalmalıdır.

## Hedef ve güvenlik kararı

Teknik aday kişisel `driveit.osaracx@gmail.com` hesabının kendi Gmail SMTP servisi üzerinden gönderimdir: `smtp.gmail.com`, port `587`, SMTP authentication ve TLS/STARTTLS. Google, bu bağlantı ayarlarını belgeler; uygulama parolaları 2 adımlı doğrulama gerektirir, daha az güvenli erişim yöntemi olarak tanımlanır ve Google hesabı parolası değişince iptal edilir. Gmail ayrıca teslimatın inbox/spam olacağını garanti etmez. Bu yüzden kabul yalnız test edilen mesaj/alıcılara ilişkin PASS verebilir; Gmail'in production-grade SLA'sı varmış gibi sonuç çıkarılamaz. [Google SMTP ayarları](https://support.google.com/mail/answer/7104828?hl=en-GB), [App Password uyarıları](https://support.google.com/accounts/answer/185833?hl=en)

Supabase'in yerleşik göndericisi yalnız ekipte önceden izinli adreslere gönderir; güncel belgede saatte 2 ileti limiti ve best-effort/SLA'sız hizmet olarak tanımlıdır. Gerçek kullanıcı gönderimi için Custom SMTP yapılandırması gerekir. Hosted SMTP ayarı Dashboard'dan yapılmalı; Supabase SMTP parolasını secret alanında kabul eder ve app password asla Codex'e, terminale, kaynak koda veya loga verilmemelidir. [Supabase Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)

## Gerekli kullanıcı işlemleri ve ayrı onaylar

### Kullanıcının güvenli hazırlığı

1. Gönderen Google hesabında 2 adımlı doğrulamayı ve kurtarma yöntemlerini kontrol et.
2. Google Account > App Passwords üzerinden bu entegrasyona özel tek bir uygulama parolası üret. Parolayı yalnız kullanıcı kontrolündeki password manager'da geçici tut veya doğrudan Supabase Dashboard'un SMTP password alanına yapıştır. Codex, sohbet, terminal istemi, PowerShell, repository ve issue/CI logu bu parolayı almayacak.
3. Test e-postalarını alabilecek iki kullanıcı denetimli inbox belirle: doğrulama/kurtarma için QA adresi ve email-change için yeni adres. Bunlar kullanıcı tarafından ayrıca onaylanmalı; test dışı alıcıya e-posta gönderilmez.
4. Supabase Dashboard'a kullanıcı kendisi giriş yapar; PAT, MFA kodu veya oturum bilgisi paylaşılmaz.

### Canlı işlemden hemen önce ayrı ayrı gerekli açık onaylar

- **SMTP yapılandırma onayı:** hangi tek project ref'in Auth > SMTP ayarlarının değiştirileceği. Bu onay öncesi Dashboard/Management API yazması yapılmaz.
- **Gerçek teslimat onayı:** kontrollü test inbox'larına hangi akışların, kaç iletiyle çalıştırılacağı. SMTP kaydetme onayı tek başına e-posta gönderme izni sayılmaz.
- **Test kullanıcısı onayı:** PROD'da test yapılacaksa gerçek kullanıcı kaydı açmadan Admin API ile sınırlı sentetik QA kullanıcısı oluşturma ve test bitince silme. Kullanıcı kaydı kapalı kalır. Bu işlem ayrıca onaylanmadıkça yapılmaz.
- **Onaylı test hedefi seçimi:** en güvenlisi PROD/DEV'den bağımsız, izole ve erişimi sınırlandırılmış hosted QA projesidir. Böyle bir proje yoksa confirmation testini gerçek PROD'da yapmak için geçici kullanıcı oluşturma ve SMTP değişikliğine ek onay gerekir. PROD signup'ı test amacıyla açmak kabul edilmez.

PROD şu an kullanıcı kaydına kapalıdır; kayıt endpoint'inden signup confirmation'ı denemek mevcut güvenlik durumuyla uyumlu değildir. Admin ile geçici test hesabı oluşturma da prod verisi değişikliğidir, bu nedenle ayrı onay ve kesin temizlik doğrulaması gerektirir.

## Dashboard'a güvenli kurulum adımları

Yalnız ilgili hosted proje için SMTP yapılandırma onayı verildikten sonra:

1. Dashboard'daki project ref'i ekrandan doğrula; DEV/PROD yanlış hedef olursa devam etme. Mevcut `disable_signup=true` ve Auth e-posta doğrulama ayarlarını önce salt okunur kaydet/kanıtla; parola değerini kopyalama.
2. Auth > SMTP Settings / Custom SMTP bölümünü aç. SMTP host `smtp.gmail.com`, port `587`, TLS/STARTTLS etkin, SMTP username ve From email aynı tam `driveit.osaracx@gmail.com`, sender name `DriveIt` gir. From email, kullanıcının kontrol ettiği Gmail hesabı olmalı. Parolayı kullanıcı doğrudan secure password input'a girer; parola alanını Codex görmez.
3. Supabase Dashboard'da özel SMTP'yi kaydet. `disable_signup=true` değerini değiştirme; rate limitini yükseltme, e-posta doğrulamayı kapatma ve redirect wildcard ekleme.
4. Gerçek akış testlerinden önce site URL ve redirect allowlist'indeki gerçek HTTPS callback/Android deep-link değerlerini doğrula. DriveIt'in nihai callback değerleri onaylanmamışsa link testini başlatma.
5. SMTP kayıt sonucunu ekrandan, parola değerini açığa çıkarmadan doğrula. Hosted Auth rate limitlerini önceden oku ve test için düşürme/yükseltme yapma.

## Kontrollü gerçek teslimat kabul senaryoları

Her senaryo için başlangıç ve bitiş saati, hedef inbox takma adı, HTTP sonucunun sınıfı, SMTP/recipient redaksiyonlu olay kodu ve inbox/spam sonucu kaydedilir. E-posta adresi, doğrulama tokenı, recovery URL'si, kullanıcı ID'si veya SMTP yanıtında credential tutulmaz. Mesaj gövdesi/logu issue ya da GitHub'a eklenmez.

| Senaryo | İşlem | PASS koşulu |
|---|---|---|
| Hesap doğrulama | QA/staging'de signup confirmation; PROD ise yalnız ayrı onaylı sentetik unconfirmed hesapla test. | Onaylı inbox'a bir ileti gelir; From beklenen Gmail hesabı; Auth linki yalnız izinli callback'e gider; link bir kez çalışır, tekrar kullanım reddedilir; SMTP parola/OTP/loglarda görünmez. |
| Parola kurtarma | Onaylı mevcut QA hesabında bir recovery talebi. | İleti gelir; link doğru app/web callback'e gider, süresi ve tek kullanımı kontrol edilir; parola reseti sonrası eski parola reddedilir ve security notice davranışı gözlenir. |
| E-posta değişikliği | QA oturumunda ikinci kullanıcı kontrolündeki inbox'a adres değişikliği isteği. | `double_confirm_changes=true`; hem eski hem yeni adrese doğru ayrı onay gelir; yalnız iki onaydan sonra yeni adres doğrulanır; onaysız yanlış adrese geçiş olmaz. |
| Yanlış/geçersiz adres | Canlı sağlayıcıya bozuk recipient gönderme. Hatalı formatı yerel testte doğrula; canlıda yalnız Auth kontrollü red örneği gerekli ve ayrı onaylıysa kullan. | Geçersiz input SMTP'ye ulaşmaz, Auth 4xx/validasyon sonucu verir ve herhangi bir kullanıcı oluşturmaz; hesap varlığı ifşa edilmez. |
| Rate limit / tekrar | Tek bir QA adresi için cooldown içinde bir tekrar, cooldown sonrasında en fazla bir retry. | Rate-limit etkinse 429/uygun hata görülür, cooldown içinde ek ileti üretilmez; cooldown sonrasındaki bir retry ulaşır. Toplu/tekrarlı deneme yapılmaz. Supabase email limitleri proje genelinde de uygulanır. [Rate limit belgeleri](https://supabase.com/docs/guides/auth/rate-limits) |
| Inbox/spam ve headers | Her test iletiyi alıcı inbox'ında ve spam/junk klasöründe incele; raw headers kullanıcı tarafından kontrol edilir. | From/Reply-To, TLS, DKIM/SPF sonucu, gönderen görünümü ve link host beklenen; spam ya da red varsa ilgili akış FAIL. Header metni/alıcının adresi rapora alınmaz. Gmail gönderen kuralları teslimatı garanti etmez. [Gmail sender guidelines](https://support.google.com/mail/answer/81126?hl=en) |
| Hatalı teslimat | Sadece controlled alıcı ve normal Auth red/SMTP error; kasıtlı olarak gerçek olmayan posta kutusuna spam denemesi yapılmaz. | UI/istemci eylemi başarılı e-posta gönderildi diye göstermemeli; Auth/SMTP hatası güvenli şekilde raporlanır, token yeniden kullanılmaz, destek/runbook kurtarma yolu işler. |

Supabase rate-limit dokümanı e-posta gönderim endpoint'lerinin proje düzeyinde sınırlı olduğunu, kullanıcı bazında varsayılan 60 saniye resend penceresi bulunduğunu ve limit aşımında 429 kullanılabildiğini belirtir. Kabul, gerçek hosted config değerini önce okuyarak bu değerlerle yapılmalı; local Mailpit'teki `1s`/`email_sent=20` ayarı hosted teste taşınmamalıdır. [Supabase Rate Limits](https://supabase.com/docs/guides/auth/rate-limits), [local Mailpit test flows](https://supabase.com/docs/guides/auth/testing-auth-flows)

## Link/redirect ve gizlilik kontrolleri

- Confirmation, recovery ve email-change linklerinin host ve redirect parametresi yalnız doğrulanmış allowlist'ten gelmeli. Site URL/callback kesinleşmeden gerçek link gönderilmez.
- E-posta şablonları test edildiği gibi Türkçe, token/link yalnız doğru aksiyonda; parola, JWT, session token veya GPS içeriği yok.
- Kullanıcının MFA'sı, uygulama parolası, test inbox erişimi veya Auth hesabı soruna girerse deneme durdurulur; auth güvenliği gevşetilmez.
- Gerçek mesaj içeriği veya raw header halka açık rapora eklenmez; yalnız redaksiyonlu PASS/FAIL ve akış kodu tutulur.

## Geri alma / olay müdahalesi

1. Her SMTP kaydetmesinden sonra signup'ın `disable_signup=true` olduğunu tekrar oku. Farklıysa e-posta testi durur; kayıtları açma.
2. Bağlantı/teslimat güvenilmezse Authentication > SMTP Settings içinde custom SMTP'yi kapatıp önceden var olan güvenli duruma geri dön. Supabase yerleşik e-posta göndericisi yalnız ekip adreslerine ve düşük limitli tanılamaya uygundur; kullanıcılara ulaştığı kabul edilmez.
3. Credential'in silindiğini/etkisiz olduğunu Dashboard'da doğrula, ancak değeri dışarı kopyalama. İlgili Google App Password'ü Google Account > App Passwords'tan `Remove` ile iptal et. Google, parola değişince uygulama parolalarını iptal ettiğini ve kullanılmayanları kaldırmayı önerir. [Google App Password revoke](https://support.google.com/accounts/answer/185833?hl=en)
4. `disable_signup=true`, test kullanıcısının yokluğu (test hesabı oluşturulmuşsa), ve custom SMTP'nin kapalı/eski duruma döndüğü tekrar doğrulanır. Bunlar gerçek hosted kontrollerdir; bu görevde gerçekleştirilmedi.
5. E-posta gönderimi spam/abuse, beklenmeyen alıcı veya Gmail bloklaması gösterirse Gmail App Password'ü iptal et, Supabase custom SMTP'yi kapat, olay kayıtlarını credential/token/recipient içermeyecek şekilde sakla. Yeniden denemeden önce ayrı onay al.

Rollback sonrası default Supabase SMTP'nin ekibe izinli olmayan kullanıcı adreslerine teslimat sağlamadığı ve production fallback olmadığı açıkça belirtilmeli. Başarısız provider'ı “geri alındı ve çalışır” diye raporlama.

## Bu turdaki otomatik test ve sınırlar

P-GR7A yerel test komutu `tool/test_email_local.ps1` olarak kaldı. Önceki doğrulama 5/5 Deno testi, Deno `check`, PowerShell parse ve `git diff --check` sonucuyla tamamlanmıştı; bu testler yalnız localhost Auth/Mailpit'i kapsar, Gmail SMTP veya gerçek inbox teslimatını değil. Bu görevde yerel paket tekrar çalıştırılacak; yeni gerçek gönderim yapılmayacaktır.

## Açık kullanıcı işlemleri

1. Gerekliyse Gmail'de 2 adımlı doğrulamayı etkinleştir ve App Password'ü kendin oluştur.
2. Gmail SMTP credential'ını yalnız Supabase'in secure Dashboard alanına kendin gir; Codex'e/parola dosyasına gönderme.
3. QA hedef projesini ve iki kontrollü test inbox'ını seçip SMTP yapılandırma, gerçek e-posta gönderimi ve gerekiyorsa kısa ömürlü sentetik test Auth hesabı oluşturma için ayrı onay ver.
4. Gerçek DriveIt redirect/callback URL'lerini onayla.
5. Test kabulinden sonra Gmail App Password'ü tutma veya iptal etme kararını ver; başarısızlıkta yukarıdaki rollback uygulanır.

Bu kullanıcı işlemleri ve onaylar tamamlanmadan gerçek teslimat sonucu **NOT RUN / NOT PASS** olarak kalır.
