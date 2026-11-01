# DriveIt P-GR7D — Auth e-posta teslimat kalitesi kabulü

Tarih: 1 Kasım 2026. **Yerel şablon/Auth kabulü PASS. Gerçek Gmail teslimatı NOT PASS/NOT REPEATED.** Kullanıcı bildirimi: iki farklı test iletisi Gmail Spam'e düştü; ilk testte SPF, DKIM ve DMARC PASS görülmüş. Bu SMTP/mail header sonuçları bu çalışmada yeniden alınmadı. PROD ve DEV ayarlarına dokunulmadı; test e-postası gönderilmedi.

## 1. Bulgular ve kanıt düzeyleri

### Kullanıcı tarafından bildirilen, bu denetimde bağımsız görülmeyen

- DriveIt-PROD Gmail SMTP üzerinden ileti gönderebiliyor.
- İki farklı test ileti Spam'e düştü.
- İlk ileti için SPF/DKIM/DMARC PASS.
- Gmail'in gösterdiği açıklama: “Bu ileti, geçmişte spam olarak tanımlanan iletilere benziyor.”

Bu açıklama teslimatı reddeden Gmail sınıflandırmasının açıklamasıdır; tek başına içerik, URL, From kimliği, gönderici/domain itibarı ya da geçmiş kullanıcı bildiriminin hangisinin etkili olduğunu kanıtlamaz. Google, doğrulamayı zorunlu sayarken mesaj sınıflandırmasında kullanıcı bildirimleri ve başka sinyallerin de kullanıldığını, SPF/DKIM/DMARC doğrulamasının tek başına teslimatı garanti etmediğini belirtir. [Google: authenticated-message classification](https://support.google.com/mail/answer/180707?hl=en), [Gmail sender guidelines](https://support.google.com/mail/answer/81126?hl=en)

### Repository'de doğrudan gözlenen

- Yerel Mailpit Auth testinde confirmation, recovery ve invite iletileri tek bir Supabase `ConfirmationURL` action linki kullanıyor. Görsel, izleme pikseli, link shortener, pazarlama copy'si veya birden çok CTA yok. Yerel test linkleri yalnız `127.0.0.1` Auth verify endpoint'ine ve izinli `127.0.0.1:63130` callback'e gidiyor.
- Önceki e-posta değişikliği taslağı aynı “yeni adresi doğrula” metnini eski ve yeni inbox'a gönderiyordu. Çift onay akışında eski inbox'taki talebi açıklamak için bu metin yanıltıcıydı; `.NewEmail` da kişisel adresi mesaj gövdesinde gereksiz tekrar ediyordu. Aday şablon bunları genel “e-posta değişikliği isteğini onayla” metnine çevirdi ve adresi gövdeden kaldırdı.
- Yerel projede custom invite şablonu yoktu ve DriveIt uygulama kodunda `inviteUserByEmail`/Auth admin invite akışı bulunamadı. Supabase Auth Admin invitation, uygulama kodundan ayrı, yetkili sunucu/Dashboard eylemidir; gerçek PROD davet şablonunun hangisi olduğu repository'den çıkarılamaz. Supabase davet e-postası için ayrı invite template sağlar. [Auth email templates](https://supabase.com/docs/guides/auth/auth-email-templates), [Auth Admin invite](https://supabase.com/docs/guides/auth/users)
- Gmail sınıflandırma metni ve teslimat spam görünümü kaynak kodundan doğrulanamaz. Repo tarafındaki içerik iyileştirmeleri olası riskleri azaltır; Gmail gönderici itibarını/teslimat sonucunu değiştirdiği iddia edilemez.

## 2. Site URL, callback ve bağlantı uygunluğu

Yerel Auth config yalnız test için `site_url=http://127.0.0.1:63130` ve aynı loopback redirect allowlist'i kullanır: [config.toml](/C:/Users/PC/Documents/DriveIt/supabase/email-test/supabase/config.toml). Bu, production URL/redirect kabulü değildir.

Flutter hesap servisi `signUp()` ve `resetPasswordForEmail()` çağrılarında `emailRedirectTo`/`redirectTo` vermiyor; link dönüşü Supabase Auth `Site URL` varsayılanına bağlıdır: [supabase_account_service.dart](/C:/Users/PC/Documents/DriveIt/lib/services/supabase_account_service.dart:307), [password recovery](/C:/Users/PC/Documents/DriveIt/lib/services/supabase_account_service.dart:368). Android `MainActivity` manifestinde yalnız launcher intent-filter bulunuyor; Auth callback için deep-link/App Link intent-filter ve kodda OAuth callback route'u yok: [AndroidManifest.xml](/C:/Users/PC/Documents/DriveIt/android/app/src/main/AndroidManifest.xml:52). Bu nedenle geçerli HTTPS Site URL ve gerçek uygulama dönüş yolu repository'de henüz kanıtlanmıyor.

`supabase/prod/email_plan.json` hâlâ `preparation-only`, `siteUrl:null`, boş `allowedRedirectUrls` ve `smtpProvider:null` gösteriyor. Bu dosya hazırlık manifestidir ve kullanıcı beyanındaki güncel SMTP durumuyla çelişiyor; **canlı Supabase ayarlarının kanıtı olarak kullanılamaz**. Önceki P-GR4A hazırlık raporundaki `localhost:3000`, o zamanki tarihi bir PROD ayarı gözlemidir, güncel snapshot değildir. Bu görevde canlı Dashboard'a girilmedi; güncel Site URL/allowlist/From display name/Reply-To bağımsız doğrulanmadı.

Supabase Auth `ConfirmationURL` önce project-ref `.supabase.co/auth/v1/verify` endpoint'ine gider ve `redirect_to` değerine döner. Üretimde varsayılan localhost veya yanlış/izin verilmeyen redirect kullanıcıyı hatalı yere götürür. Supabase production Site URL için gerçek HTTPS URL, production allowlist için mümkün olduğunca tam URL/path öneriyor. E-posta tracking linkleri Supabase doğrulama bağlantılarını yeniden yazıp token akışını bozabilir; tracking kapalı tutulmalı. [Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), [Email templates and link tracking](https://supabase.com/docs/guides/auth/auth-email-templates)

### Davet mesajı/bağlantısı

- Supabase Auth daveti Admin eylemidir; DriveIt UI'da davet akışı bulunamadı. Gerçek sistem bu işlevi çağırmıyorsa, PROD'dan davet e-postası çıkması yalnız yetkili operasyon işlemiyle mümkün olmalıdır.
- Davet `redirectTo` adresi allowlist'te değilse Auth bunu sessizce Site URL'e düşürebilir; bu yüzden gerçek invite callback ve Site URL'in Dashboard'da ayrı ayrı kontrolü gerekir. [Auth Admin invite](https://supabase.com/docs/guides/auth/users)
- `.supabase.co` link hedefi `@gmail.com` From kimliğinden farklı görünür. Bu, kullanıcı güveni/itibar için **makul bir incelenecek sinyal**; iki Spam kararının kanıtlanmış sebebi değildir. Özel Auth domain'i/alan adı bu aşamada yok ve eklenmedi.

## 3. Şablon düzeltmeleri

Yalnız yerel Mailpit adayı düzenlendi; Dashboard'a yüklenmedi. [Aday şablonlar](/C:/Users/PC/Documents/DriveIt/supabase/email-test/templates/confirmation.html) ve ilgili `recovery.html`, `invite.html`, `email_change.html`, `password_changed.html`, `email_changed.html` dosyaları:

- Konu satırları DriveIt adını ve tek net işlemi söylüyor; reklam/satış, aciliyet baskısı, kampanya dili, logo görseli, tracking, kısaltılmış veya ek link yok.
- Confirmation, recovery ve invite yalnız bir Auth action linki taşır.
- E-posta değişikliği eski ve yeni adrese aynı template ile giderken nötr onay metni kullanır; yeni adresi gereksiz yere HTML gövdesinde tekrarlamaz.
- Parola/e-posta değişikliği bildirimleri kimlik doğrulama bağlantısı içermez; yetkisiz işlem durumunda gerçek destek e-postasını bildirir.
- `ConfirmationURL` korunur; custom URL/token oluşturulmaz. Güvenli Auth token/TTL davranışı değişmez.

Bu değişiklikler Gmail Spam kararını önleyeceğini garanti etmez. Canlı template deployment yapılmadı.

## 4. Spam nedenine ilişkin değerlendirme

| Sinyal | Durum | Değerlendirme |
|---|---|---|
| SPF/DKIM/DMARC | İlk test için kullanıcı bildirimi PASS | Gerekli olumlu sinyal; Gmail spam sınıflandırmasını tek başına çözmez. |
| Gönderici adı/From/Reply-To | Güncel hosted değerler okunmadı | Repository hazırlık manifesti boş; gerçek sender görünümü bağımsız doğrulanmalı. |
| Gönderici itibarı/hacmi/şikayet geçmişi | Gözlenmedi | Gmail mesajı geçmiş spam'e benzettiğini söylüyor; hangi geçmiş olayın tetiklediği bilinmiyor. Kişisel Gmail + düşük hacim/yeni Auth amaçlı gönderim reputasyon riski oluşturabilir; bu teşhistir, kanıt değil. |
| İçerik | Local candidate minimal; önceki exact hosted copy unknown | Pazarlama/çoklu CTA yok. Invite'ın deployed içerik birebir karşılaştırılamadı. |
| Link hedefi | Yerel test loopback; prod link/header gözlenmedi | Prod Auth linki `.supabase.co` ve son callback; sender domaini ile farklı görünmesi incelenmeye değer. Link shortener/tracker kullanma. |
| Site URL/allowlist | Repo manifesti boş/stale; hosted okumadık | Uygulamanın çağrıları `redirectTo` vermiyor ve Android'de callback handler yok; functional risk kesin, mevcut hosted URL değeri bilinmiyor. |

Kök neden **BELİRLENEMEDİ**. Gmail hata açıklamasını tek başına kök neden olarak raporlamıyoruz.

## 5. Google ile girişin e-posta bağımlılığına etkisi

Repo'da `signInWithOAuth`/Google Auth akışı bulunamadı; Android callback intent-filter'ı da yok. Google sign-in eklenmedi.

OAuth kullanıcı Google'da oturum açıp hesabını kurtaracağı için **DriveIt parola sıfırlama e-postasına** bağımlılığı azaltabilir. DriveIt e-posta/parola kullanan mevcut hesapların kurtarmasını çözmez; uygulamanın e-posta değişikliği ve güvenlik bildirimi akışını otomatik ortadan kaldırmaz. Supabase e-posta doğrulamasını provider e-postasının doğrulanmış olmasına bağlar; provider bu kanıtı vermezse Auth e-postası gerekebilir. Google sağlayıcı kurulumu Google Cloud OAuth client/brand/authorized redirect, Supabase provider client ID/secret ve uygulama callback'ini gerektirir. Supabase ayrıca branded/custom Auth domain olmadan Google onay ekranında project-ref `.supabase.co` adresinin gösterileceğini ve bunun kullanıcı güvenini düşürebileceğini belirtiyor. [Supabase Google sign-in](https://supabase.com/docs/guides/auth/social-sign-in/auth-google), [Flutter OAuth API](https://supabase.com/docs/reference/dart/auth-signinwithoauth), [redirect allowlist](https://supabase.com/docs/guides/auth/redirect-urls)

Bu nedenle Google sign-in mevcut Gmail SMTP teslimat sorununu doğrudan düzeltmez; ayrı ürün, güvenlik, OAuth secret ve callback işi olarak değerlendirilmelidir.

## 6. Kontrollü yeniden test planı

Gerçek teslimat için mevcut iki spam sonucundan sonra her değişikliği ayrı ölçmek gerekir. Bu plan gerçek gönderim izni değildir.

1. Önce Dashboard'dan yalnız okuma: doğru PROD ref; `disable_signup=true`; güncel Site URL; tam redirect allowlist; SMTP'deki From/sender name/Reply-To. Credential alanı okunmaz/kopyalanmaz. Repo manifestini canlı durum kanıtı sayma.
2. Site URL ve callback seçimi henüz çözümlenmediği için önce Android/HTTPS callback tasarımı ve uygulama dönüş testi tamamlanmalı. Local manifestte callback handler yokken PROD redirect'e rastgele scheme/path eklenmemeli.
3. Hosted template, auth ayarına yazma ve gerçek e-posta göndermeye ayrı onay alınmalı. Signup kapalı kalmalı. İki kontrollü inbox'a toplam minimal: bir invite (kullanılıyorsa), bir password reset; daha sonra eski/yeni kontrollü adresle bir email-change. Her test için birer eylem, cooldown'a uyarak tek retry.
4. Her inbox'ta Primary/Spam, Gmail “show original” header'ında SPF, DKIM ve DMARC hizası, exact From/Reply-To ve tek link hedefini kontrol et. Adres, raw header, token ve URL query/token'ı rapor veya GitHub'a koyma.
5. Bir test Spam'e düşerse template veya Auth ayarını tekrar tekrar değiştirip yeniden gönderme. Önce bu tek örneğin sağlayıcı sonucunu kaydet; değişiklik başına tek kontrollü tekrar. Inbox'a düşmeden “PASS” yok. Hem mesaj içeriği hem Auth ve Google gönderici itibar metrikleri birlikte incelensin.
6. Son olarak izinli linki aç: link doğru web/app callback'e varmalı, tek kullanımlı ve süresi dolunca reddedilmeli. Redirect host/path allowlist dışına çıkmamalı; kullanıcı signup kapalıyken yeni hesap oluşturulamamalı.

### PASS ölçütü

- Gerçek test alıcısında ileti Inbox'a düşer (Spam'e düşen bir akış PASS değildir).
- From/Reply-To beklenen Gmail kimliğidir; raw header auth sonuçları ve hizalanma beklenen.
- Her akış doğru prod callback'e gider ve link akışı gerçekten tamamlanır; retry rate-limit altında mükerrer email/link üretmez.
- `disable_signup=true` korunur; test user gerekiyorsa ayrı onayla geçici oluşturulur ve temizliği doğrulanır.
- Bu, yalnız test edilen ileti/kullanıcılar için kabul; Gmail'e genel teslimat garantisi değildir.

## 7. Yerel doğrulama sonucu

İlk çalıştırma yeni TOML şablonlarını yüklememiş çalışan yerel Auth servisine karşı eski/eksik konuları bekledi ve başarısız oldu. Resmî CLI davranışına göre config değişiklikleri için `stop` sonra `start` gerekir; yalnız `driveit-email-pgr6d` stack'i `supabase stop --workdir ...` ile durduruldu, `--no-backup` kullanılmadı ve Docker volume/veritabanı korunarak yeniden başlatıldı. [Supabase CLI config reload](https://supabase.com/docs/guides/local-development/cli/config), [stop davranışı](https://supabase.com/docs/reference/cli/global-flags)

Güncel gerçek bitiş sonucu: **6/6 PASS, exit code 0**:

- Auth confirmation, recovery, password/email change: 1 PASS
- Auth Admin invitation/local invite link: 1 PASS
- Malformed email, rate limit/no-duplicate, delayed retry: 1 PASS
- Hesap silme/privacy statik sayfa kontrolleri: 3 PASS
- Deno type check runner içinde PASS

Test Auth/Mailpit hedefleri loopback; aday action linkleri tek ve yalnız local Auth verify/callback'e gitti. Yalnız sentetik `example.com` kullanıcı/mesajlar test sonunda temizlendi. Gerçek Gmail, PROD ve DEV kullanılmadı. Test, gerçek teslimat veya Gmail inbox davranışı yerine geçmez.

## 8. Değiştirilen dosyalar ve kalan işler

- `supabase/email-test/supabase/config.toml` — yalnız yerel konu satırları ve invite template bağlantısı.
- `supabase/email-test/templates/` — altı sade yerel aday Auth/security template'i.
- `supabase/email-test/tests/auth_email_flows_test.ts` — invite ve link/redirect/content regression assertions.
- `docs/auth_email_pgr7d_acceptance.md` — bu kabul raporu.

PROD/DEV, SMTP parolası, hosted Auth, signups, callback/allowlist, Flutter, Android ve OAuth değiştirilmedi. Öncelik: canlı Site URL/redirect/From değerlerini güvenli salt okunur kontrol et; sonra uygulama callback eksiğini çöz; sonra yalnız onaylı recipientlarla gerçek inbox/spam kabulü. Gmail teslimatı ve Spam sonucu hâlâ **NOT ACCEPTED / NOT GUARANTEED**.
