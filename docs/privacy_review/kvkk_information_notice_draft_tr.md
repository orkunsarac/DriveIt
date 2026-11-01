# DriveIt KVKK Aydınlatma Metni — Taslak

> **[ONAY BEKLİYOR — veri sorumlusu, amaç/hukuki sebep eşlemesi ve aktarım hükümleri tamamlanmadan sunulamaz.]**

**Veri sorumlusu:** [Unvan, MERSİS/vergi ve adres bilgileri — ONAY BEKLİYOR]
**İletişim:** driveit.osaracx@gmail.com [yetkili başvuru adresi olduğu doğrulanacak]
**Tarih/sürüm:** [ONAY BEKLİYOR]

## İşlenen kişisel veri kategorileri

1. **Konum ve sürüş verileri:** GPS koordinatı, rota, konum zamanı, hız, yön, irtifa, doğruluk, mesafe, ivme, sürüş başlangıç/bitiş zamanı, süre ve sürüş puanı.
2. **Kimlik ve hesap:** Auth kullanıcı kimliği, e-posta ve kimlik doğrulama durumu.
3. **Profil:** kullanıcı adı, görünen ad, avatar URL/görseli, profil zaman damgaları.
4. **Kullanıcı içeriği:** Planet yayın isteği, rotaya bağlı kaynak dosya, türetilmiş yol/section geometrisi; açık onay halinde.
5. **İşlem ve güvenlik kayıtları:** sync/outbox durumları, silme talebi durumu, hata/işlem zamanı ve servis logları. Logların alanları/retention'ı ayrıca doğrulanmalıdır.
6. **Destek başvurusu:** e-posta gönderen adresi, başvuru metni ve vaka takip bilgisi (destek adresi üzerinden başvuru yapılırsa).

## İşleme amaçları

Sürüş kaydı ve kullanıcıya sürüş geçmişi/analiz sunulması; hesap/profilin çalışması; seçildiğinde kişisel bulut yedeği ve cihazlar arası geri yükleme; ayrı açık kullanıcı işlemiyle Planet yol katkısı; harita/yol eşleme; güvenlik, hata giderme, kullanıcı taleplerinin cevaplanması ve mevzuat yükümlülükleri. Her amaç için KVKK m.5/m.6 hukuki sebebi ve varsa açık rıza gerekliliği hukuk danışmanı tarafından **ONAY BEKLİYOR**. Açık rıza, hizmet için zorunlu olmayan işleme koşulu olarak dayatılmamalıdır.

## Toplama yöntemi

Mobil uygulamada cihaz GPS/konum izinleri ve kullanıcı girdileri; yerel SQLite/Hive depoları; hesap/bulut özellikleri etkinse Supabase Auth/Database/Storage; Planet yayınında kullanıcı eylemi ve kaynak yüklemesi; yol eşleme çağrısında Mapbox API; harita gösteriminde Google Maps SDK; destek talebi e-postası.

Android manifesti foreground location service ve background location izni içerir. Mevcut izin onboarding açıklaması yalnız rota, mesafe ve hızı belirtmekte; uygulama arka plandayken/kapalı görünürken kullanımın kapsamını açıklamamaktadır. Bu nedenle mevcut onboarding metni Play/aydınlatma gereksinimini karşıladığı kabul edilemez.

## Aktarılan taraflar ve yurt dışı

Supabase; Planet paylaşımı onaylanırsa diğer authenticated Planet kullanıcıları; rota eşleme çağrısında Mapbox; harita SDK'sında Google; destek e-postası kullanılırsa Google/Gmail ve yetkili operatör. Ülke, alt işleyen, KVKK yurt dışı aktarım mekanizması, sözleşme ve veri sorumlusu/veri işleyen rolleri **ONAY BEKLİYOR**. Frankfurt proje bölgesi tek başına tüm aktarım yerlerini belirlemez.

## Saklama ve imha

Kesin teknik/yasal süreler aşağıdaki matriste yalnız kanıtlandığı ölçüde belirtilmiştir. Uygulama yerel kayıtları, Android yedekleri, Supabase log/backup, e-posta kutusu ve Planet ortak geometri için doğrulanmış tüm sistemleri kapsayan silme süresi yoktur. Veri işleme şartları sona erdiğinde silme/yok etme/anonimleştirme yükümlülüğü ve imha işlem kayıtları yönetmeliğe göre değerlendirilmelidir. İmha kayıtlarının en az üç yıl saklanması hükmünün DriveIt olaylarına uygulanması hukukça **ONAY BEKLİYOR**.

## İlgili kişi başvuruları

Kanun kapsamındaki haklar ve başvuru yöntemi açıklanacaktır. Başvurunun kimlik doğrulaması, yetkili kanal, format, cevap içeriği ve yasal süre hukuk danışmanıyla kesinleştirilecektir. KVKK Kurul duyurusunda başvuruların en kısa sürede ve en geç 30 gün içinde cevaplanması belirtilir; başvuru özel şartları için resmi mevzuat/danışman incelemesi gerekir.

## Profil erişimi ve Planet

Mevcut schema, authenticated rolüne bütün `profiles` satırları için SELECT verir. Bu nedenle username, display_name, avatar_url ve profile zaman alanları hesapla giriş yapan diğer kişilerce okunabilir. E-posta `profiles` tablosunda bulunmaz; auth.users erişimi ayrı sunucu politikalarına tabidir. Profil alanlarının herkese açık kapsamı ve Planet'te kimlik görünürlüğü **ONAY BEKLİYOR**.
