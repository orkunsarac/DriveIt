# P-GR4B — Auth kayıt güvenliği ve e-posta hazırlığı

## Gerçek işlem ve sonuç

Hedef yalnız `arwnbogcswisfesayosy` / DriveIt-PROD. Kullanıcı adı/ref/bölge
kontrolünden sonra disable_signup=false ve Auth kullanıcı sayısı 0 okundu.
Kullanıcı sadece disable_signup=true değişikliğini açıkça onayladı.
Management API PATCH body'si yalnız `{"disable_signup":true}` idi.
Sunucu HTTP 403 ile reddetti; aynı PATCH tekrarlanmadı. Ardından salt-okunur
GET/COUNT ile disable_signup=false ve kullanıcı sayısı 0 tekrar doğrulandı.
Signup kapatılmış gibi raporlanamaz. Diğer Auth ayarları için PATCH gönderilmedi.
Migration, Edge deployment, PROD kullanıcı oluşturma veya DEV değişikliği yapılmadı.

Gerekli en dar yazma izinleri, resmi endpoint sözleşmesinde birlikte listelenir:
`auth_config_write` (Auth Read-write), `project_admin_write` (Project Settings
Read-write). Kaynak kapsamı yalnız PROD olmalı; Full access/Legacy token veya
DEV yazma erişimi gerekmez. Salt-okunur kimlik ve kullanıcı sayısı doğrulaması
için mevcut Project Settings Read ve Database Read korunabilir. Token yetkileri
kendiliğinden genişletilmedi. Yeni yetkili PAT sağlanırsa aynı açık onay
kapsamında yalnız signup kapatma işlemine devam edilebilir.

PAT sohbet/argv/log/kaynak koduna girmez; aynı Windows kullanıcısının repository
dışı DPAPI credential dosyasından yalnız bellekte alınır. Başka Auth alanları
sonuç karşılaştırmasında yalnız bellekte incelenmeli; gizli değerler yazılmamalı.
Yeni PAT'in en kısa uygulanabilir süresi ve yalnız PROD kapsamı tercih edilir.

## Özel alan adı ve SMTP için zorunlu kullanıcı kararları

1. DriveIt için sahip olunan veya ayrıca satın alınması onaylanacak gerçek alan
   adı; DNS yönetimini yapabilecek hesap. Bu aşamada alan adı satın alınmadı.
2. Transactional SMTP sağlayıcısı, veri işleme bölgesi, gönderim limiti ve açık
   bütçe tercihi. Ücretli abonelik başlatılmadı; Supabase Free ile SMTP maliyeti
   ayrı değerlendirilir. Sağlayıcı kararı gelmeden host/port/TLS tahmin edilmez.
3. Gerçek From/sender adı, Reply-To ve güvenlik/destek taleplerinin izleneceği
   adres. SMTP kullanıcı adı/parolası sadece güvenli harici secret kaydına girer.
4. Gerçek Site URL ve callback/recovery uçları; web + Android deep-link/App Link
   sahibi ve uygulamada işlenecek akış. Bunlar kesinleşmeden PROD redirect
   allowlist'i yazılmaz. Wildcard, açık redirect veya tahmini alan adı eklenmez.

`supabase/prod/email_plan.json` sadece boş hazırlık alanları ve kabul şartlarını
içerir; SMTP yapılandırması veya gerçek secret dosyası değildir. Null alanlar
ve productionEmailAcceptancePassed=false özellikle korunur.

## Beş akışın sözleşmesi

| Akış | Uygulama ve kabul koşulu |
| --- | --- |
| Hesap doğrulama | Supabase confirmation template; email confirmation açık kalır. Gerçek callback'te tek kullanımlı/expired bağlantı ve Android dönüşü sınanır. Signup ancak bütün ürün kabulü ve ayrı aktivasyon onayından sonra açılır. |
| Şifremi unuttum | Supabase recovery template; gerçek izinli recovery callback'i ve PASSWORD_RECOVERY işleyicisi gerekir. Var olmayan hesaba ilişkin genel sonuç hesap varlığını açıklamamalı; kota/retry kontrol edilir. |
| Şifre değiştirme bildirimi | Supabase password-changed security notification ayrıca etkinleştirilmeli; reset linki yerine gerçekleşen değişiklik bilgisi ve gerçek destek kanalı verilir. Yeni parola veya token e-postada/logda tutulmaz. |
| E-posta değişikliği | Secure email change eski/yeni adres doğrulaması korunur; change-email template ile işlem sonrası email-changed bildirimi ayrı değerlendirilir. Doğrulanmamış yeni adrese hesap devri yapılmaz. |
| Hesap silme bildirimi | Supabase'in belgelenmiş standart Auth template listesinde bu akış yoktur. Ayrı yetkili sunucu iş akışı gerekir; yalnız gerçek silme süreci kalıcı başarıya ulaştıktan sonra gönderilir. Yarım silmeyi başarılı diye bildirmez. Alıcı adresinin geçici saklama/silme süresi hukuki ve veri silme sözleşmesiyle kararlaştırılmalı; Auth kaydı silindikten sonra adresi yeniden sorgulayacağı varsayılmaz. |

Hesap silme bildirimi şu aşamada uygulanmadı; Auth/profil/kişisel bulut/Storage/
grup/Planet kapsamındaki silme kabulü ve saklama politikası tamamlanmalıdır.
Bildirim hatası silinmiş hesabı yeniden oluşturamaz; yeniden deneme ve sınırlı
alıcı metadata saklama tasarımı ayrıca kabul edilmelidir. Kullanıcıya başarı
bildirimi ile hukuken saklanan veriler arasındaki ayrım açık olmalıdır.

## Kurulum sırası (bu aşamada uygulanmaz)

1. Domain/provider/gerçek callback kararlarını al. Sahiplik ve DNS yetkisini doğrula.
2. Transactional mail için ayrı sending subdomain ve dar sender kimliği oluştur;
   pazarlama itibarını Auth mesajlarıyla karıştırma. Sağlayıcının verdiği gerçek
   SPF/DKIM/DMARC kayıtlarını doğrula; uydurma TXT kaydı üretme, mevcut SPF'i bozma.
   DMARC raporlama/alignment ve geçiş politikası DNS sahibinin kabulüyle belirlenir.
3. SMTP host/port/TLS ayarını sağlayıcıdan doğrula; sertifika doğrulamasını kapatma.
   Yalnız gönderime yetkili PROD credential üret; repository dışında şifreli sakla.
4. From/Reply-To sahipliğini ve bounce/complaint takibini doğrula. Supabase Auth
   SMTP, uygulama bildirim servisi ve pazarlama kimliklerini birbirine karıştırma.
5. Resmi Supabase ConfirmationURL/TokenHash sözleşmesine uygun Türkçe HTML/text
   template'lerini hazırla; kullanıcı girdisini HTML'e ham ekleme. Kimlik doğrulama
   bağlantılarında provider link tracking'i kapat; URL rewrite token akışını bozabilir.
   E-posta tarayıcılarının tek kullanımlı linki tüketmesi senaryosunu test et.
6. Ayrı config onayıyla yalnız doğrulanmış SMTP ve URL ayarlarını PROD'a uygula.
   Kayıt kapatma onayı SMTP/redirect veya notification ayarlarını değiştirme izni değildir.
7. Önce izole yerel Mailpit'te template/akış testleri; sonra açıkça onaylı QA
   alıcılarına sınırlı gerçek teslimat. Mevcut görevde e-posta gönderilmedi ve
   PROD'da hesap açılmadı. SPF/DKIM/DMARC header sonuçları, inbox/spam, link
   expiry/replay, recovery ve email-change eski/yeni alıcı davranışı doğrulanır.
8. Limit/abuse/bounce izleme, secret rotasyonu, destek ve alarmlar kabul edilir.
   Confirmation'ı kapatarak e-posta sorununu aşma; varsayılan Supabase mail
   servisini son kullanıcı üretim SMTP'si olarak sunma.

Özel gönderim domain'i, ücretli Supabase custom API/Auth domain add-on'ı
satın alma anlamına gelmez. Bu aşama böyle bir satın alımı onaylamaz.

## Kontrol sonucu ve dağıtım sınırı

Önceki 22 kontrol yeniden geçti: hedef 10, fiziksel izolasyon 8, atomik paket
unit 3, gerçek yerel PostgreSQL rollback/concurrency 1. 25 migration sırası,
hash ve final Group gate FALSE assertion'ı korundu. PROD'da gate henüz kurulu
değildir. Yeni migration veya function dağıtılmadı. diff/secret taraması yapılır.

Yerel hazırlık PASS; PROD signup güvenliği FAIL/BLOCKED (403, false kaldı).
SMTP üretim kabulü FAIL/NOT CONFIGURED. Gerçek migration/Edge deployment ve
kullanıcıya açılma için ayrı açık onay gerekir. Bu belge yetki hatasını gizleyen
bir başarı raporu değildir.

Resmî kaynaklar:
- https://supabase.com/docs/reference/api/v1-update-auth-service-config
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/reference/csharp/auth-updateuser
- https://supabase.com/docs/guides/auth/testing-auth-flows
