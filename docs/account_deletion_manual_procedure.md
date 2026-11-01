# DriveIt — e-posta ile hesap silme başvurusu prosedürü

**Operasyon taslağı; kamuya açılmadan ve hukuki inceleme tamamlanmadan uygulanmaz.** Destek adresi: `driveit.osaracx@gmail.com`. Bu süreç PROD'da worker veya otomatik silme etkinleştirmez.

## 1. Başvuruyu alma ve kaydetme

1. Kullanıcı `DriveIt hesap silme talebi` konulu e-postayı gönderebilir. `From`, `Reply-To` veya görünen gönderen adı sahiplik kanıtı değildir. Kullanıcıdan parola, OTP, JWT, oturum bağlantısı, rota/GPS, kimlik belgesi veya gereksiz kişisel veri istenmez.
2. Operatör her başvuruya tahmin edilemeyen bir vaka numarası atar. Durum kaydında yalnız vaka numarası, ilk alınma zamanı, aşama, son işlem zamanı ve gerekirse genel engel kodu tutulur. Ham e-posta içeriğini, rota verisini, tokenı veya gereksiz Auth tanımlayıcılarını vaka notuna kopyalamaz.
3. İlk yanıt genel olmalıdır; hesabın varlığını, e-posta eşleşmesini veya başka hesap bilgilerini ifşa etmez. Gelen e-postanın gönderen kutusu tek başına yanıta hedef seçilmez.

## 2. Hesap sahipliğini doğrulama

1. Sınırlı yetkili operatör, yalnız başvuru adresini mevcut Auth hesabının **doğrulanmış** adresiyle güvenli yönetim arayüzünde karşılaştırır. Bu görevde böyle bir dış başvuru konsolu kurulmadı; canlı başvurular için onaylı erişim yöntemi ve operatör yetkisi önkoşuldur. PROD veritabanı sorgusu, e-posta ile parola isteme veya hesap varlığını yanıtla açıklama bu prosedürün parçası değildir.
2. Eşleşme varsa yalnız Auth'taki doğrulanmış adrese tek kullanımlı doğrulama challenge'ı gönderilir; gelen adrese körlemesine gönderilmez. Challenge en az 128 bit rastgele, kısa ömürlü (24 saatten kısa), tek kullanımlı ve deneme sınırlı olmalıdır. Kalıcı kayıtta ham challenge değil hash tutulur. Mevcut sistem bu dış kanalı sağlamadığı için bu adım yayımdan önce gerçek, denetlenmiş destek operasyonu ile kurulup test edilmelidir.
3. Adres eşleşmiyorsa, erişilemiyorsa veya challenge tamamlanmıyorsa silme başlatılmaz. Yanıt genel tutulur; alternatif kimlik doğrulama ancak ayrıca tasarlanıp güvenlik/hukuk incelemesinden geçerse sunulur.
4. Başarıyla doğrulanan vaka `verified` olur; ayrı operatör doğrulaması ve mevcut hesap silme akışındaki açık onay olmadan işlem kuyruğa alınmaz. Uygulama içi akışın UID, güncel parola yeniden doğrulaması ve açık onay kontrolleri bu destek prosedürüyle gevşetilmez.

## 3. İşleme ve durum bildirimleri

Durumlar: `received` → `verification_pending` → `verified` → `processing` → `completed`; güvenli biçimde ilerleyemeyen işler `blocked_planet` veya genel `needs_review` durumunda kalır. Başarısız/yarım iş `completed` olarak işaretlenmez.

- `blocked_planet`: katkı sahipliği veya kalan ortak kaynaklar güvenle ayrıştırılamadı. Kişisel rota/GPS verisi erişime kapatılmış olmalı; ortak yol verisi sessizce korunup silme tamamlandı denmez. Güvenli çözüm yoksa vaka incelemede kalır.
- Retry yalnız idempotent iş kimliğiyle, sınırlı geri çekilme ve denetlenebilir operatör eylemiyle yapılır. Vaka ikinci kez açıldığında çift silme/yanlış hesap etkisi yaratmaz.
- `completed` yalnız worker'ın terminal onayı ve Auth, profil, kişisel bulut sürüşleri, kaynak GPS/rota nesneleri ve hesap bağlantıları için doğrulanmış silme kanıtı olduğunda bildirilir. Cihazdaki yerel arşivin uzaktan silinmediği açıkça belirtilir.
- Durum yanıtı yalnız doğrulanmış iletişim adresine gönderilir. Yanıt sağlayıcısının gönderim alındısı, hesabın silindiğine dair kanıt değildir.

## 4. Günlük/erişim ve saklama kararı

Operatör erişimi kişiye göre atanmalı, MFA ile korunmalı ve periyodik gözden geçirilmelidir. Denetim kaydı vaka numarası, operatör eylemi ve zamanla sınırlı olmalı; e-posta gövdesi, konum, challenge veya parola içermemelidir. Erişim ve vaka kayıtları için hukuki saklama süresi henüz kararlaştırılmamıştır; süre uydurulmaz ve politika sahibi onayı olmadan gerçek başvuru işlenmez.

Auth/SMTP doğrulama, parola sıfırlama ve e-posta değişikliği ile destek talebi kanalı farklıdır. Mailpit yerel testini geçen Auth akışları için ayrıca PROD SMTP ve gerçek teslimat kabulü gerekir; destek `mailto:` bağlantısı SMTP yerine geçmez.

## Yayın önkoşulları

- Veri sorumlusu/hukuk incelemesi: silme kategorileri, Planet ortak katkı davranışı, yedek/log saklama, başvuru ve durum kayıtlarının süresi.
- Destek operasyonu sahibi, MFA'lı en az ayrıcalıklı Auth doğrulama aracı, challenge gönderme/tek kullanım/deneme sınırı ve vaka takip kanalı gerçek uçtan uca kabulü.
- Gerçek işlemden önce `blocked_planet`, retry, yanlış hesaba karşı koruma, terminal silme kanıtı ve bildirim testleri.
- Açık yayın onayı; GitHub Pages ayarı ve URL'nin dışarıdan açılması kontrolü; sonrasında gerçek URL'nin Google Play Console alanına girilmesi.
- Auth e-postaları için ayrı PROD SMTP sağlayıcısı ve gerçek inbox/spam/bounce kabulü.
