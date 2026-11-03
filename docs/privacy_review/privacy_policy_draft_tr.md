# DriveIt Gizlilik Politikası — Taslak

> **[ONAY BEKLİYOR — HUKUKİ İNCELEME TAMAMLANMADAN KULLANILAMAZ/YAYINLANAMAZ]**
>
> Bu taslak, mevcut kod davranışını anlatmak içindir. Veri sorumlusu unvanı/adresi, yürürlük tarihi, hukuki sebepler, uluslararası aktarım mekanizması, saklama takvimi ve başvuru kanalı tamamlanmamıştır. Metin, uygulama içindeki placeholder belgelerin yerine henüz konmamıştır.

**Son güncelleme:** [TAMAMLANACAK]
**Veri sorumlusu:** [TÜZEL/KİŞİSEL KİMLİK VE ADRES — ONAY BEKLİYOR]
**İletişim:** [doğrulanmış destek ve veri sahibi başvuru kanalı — SEÇİLMEDİ]

## Hangi bilgiler işlenebilir?

DriveIt sürüş kaydı sırasında kesin konum, rota, zaman, hız, irtifa, GPS doğruluğu ve sürüşe ilişkin ölçüm verileri oluşturabilir. Bu kayıtlar cihazınızda tutulur. Uygulama kodu, rota ve telemetriyi yerel SQLite/Hive depolarında saklar. Hesaplı kişisel bulut senkronizasyonu yalnız ilgili yapılandırma ve hesap akışı etkinleştirildiğinde çalışır; misafir kayıtları kendiliğinden hesaba veya buluta aktarılmaz.

Hesap/profil kullanıldığında Auth kimliği ve e-posta, kullanıcı adı, görünen ad ve profil görseli işlenebilir. Kullanıcı adı, görünen ad ve avatar alanlarının authenticated kullanıcılar arasında okunabildiği mevcut Planet şeması kullanıcıya açıklanması/erişimin daraltılması gereken bir tasarım kararıdır.

Gezegen'e yayınlama kişisel bulut yedeklemesinden ayrıdır ve kullanıcı onayıyla başlatılır. Yayın için rota koordinatları ile zaman, hız, yön, irtifa, doğruluk ve diğer telemetri alanlarını içeren kaynak dosya private Storage alanına yüklenebilir; bundan türetilen yol/section verileri diğer kullanıcılar tarafından görülebilir. Yayın kapsamı/kimlik gösterimi ve silme davranışı **ONAY BEKLİYOR**.

Mapbox yol eşleme çağrısı yapıldığında rota koordinatları Mapbox Matching API'ye gönderilir. Google Maps SDK kullanılmaktadır; SDK'nın topladığı veri ve saklama ayrıntıları sağlayıcı belgeleri ve Play SDK beyanı ile ayrıca doğrulanacaktır.

Group Drive şu an sunucu güvenlik kilidiyle kapalıdır. Açılması ayrı karar ve kabul gerektirir. Etkinleştirilmesi halinde grup üyeleri arasında canlı konum ve doğruluk bilgisi paylaşımı olur; süre, erişim ve retention açıklamaları tamamlanmadan açılmamalıdır.

## Neden kullanılır?

Sürüşü cihazda kaydetmek, rota/mesafe/hız/puan ve replay üretmek; kullanıcı bir hesap özelliğini seçtiğinde sürüşü kişisel bulutta yedeklemek; kullanıcı ayrıca seçtiğinde Planet'e ortak yol katkısı yapmak; kimlik ve profil sunmak; güvenlik, hata giderme ve hesap taleplerini yürütmek. Hukuki dayanaklar amaç bazında hukuk danışmanı tarafından **ONAY BEKLİYOR**.

## Kimlerle paylaşılır?

- Seçili hesap bulutu etkinse Supabase altyapısı; kullanıcı hesabına bağlı sürüş kayıtları.
- Planet yayını onaylanırsa Planet kullanıcılarıyla türetilmiş yol ve yayımlanabilir ayrıntılar.
- Yol eşleme çağrısı sırasında Mapbox'a koordinatlar.
- Harita sunumu sırasında Google Maps SDK sağlayıcısına SDK'nın işlediği teknik veriler.
- Destek e-postası kullanıcı tarafından gönderilirse Google/Gmail e-posta altyapısına ve yetkili DriveIt operatörüne.

Sağlayıcı sözleşmeleri, alt işleyenler, bölge/uluslararası aktarım ve uygun KVKK aktarım mekanizması **ONAY BEKLİYOR**. Supabase projesinin Frankfurt'ta olması tek başına bütün alt işleyen işlemlerinin yalnız AB'de gerçekleştiğini kanıtlamaz.

## Saklama, silme ve yedek

Uygulamanın yerel sürüş geçmişi hesap silme worker'ı tarafından cihazdan otomatik silindiği doğrulanmamıştır. Android uygulama paketindeki yeni kurallar, yerel uygulama verisini Android Auto Backup ve cihaz aktarımından dışlar; bu nedenle yeni telefonda yerel sürüş geçmişi otomatik geri yüklenmez. Bu ayar mevcut telefondaki kayıtları silmez ve Android sağlayıcısındaki eski yedek kopyalarını geriye dönük sildiği anlamına gelmez. Android 11 ve Android 12+ fiziksel cihaz kabulü tamamlanmalıdır.

Üretim hesabı silme akışı şu anda etkin değildir. Destek e-postasıyla talep işleme ve yayımlanmamış statik sayfa, gerçek silme mekanizması değildir. Silme tamamlandı denmesi için kimlik doğrulama, Auth silme, kişisel bulut/Storage cleanup ve Planet katkı yeniden hesaplama/`blocked_planet` durumlarının doğrulanması gerekir. Yedeklerdeki kalıcı silinme ve süre **ONAY BEKLİYOR**.

Supabase Free planda otomatik günlük veritabanı yedeği yoktur ve Storage nesneleri DB yedeğine dahil değildir. Şu an doğrulanmış ayrı yedek/restore operasyonu bulunmadığından burada süre taahhüt edilmemektedir.

## Haklar ve başvuru

KVKK kapsamındaki talepler için başvuru kanalı, kimlik doğrulama yöntemi ve veri sorumlusu iletişim bilgileri tamamlanmamıştır. Önceki taslakta bulunan e-posta hesabı devre dışıdır ve başvuru kanalı değildir. Kanun kapsamındaki cevap süresi ve istisnalar hukuk incelemesiyle doğrulanacaktır.

## Açık kararlar

Bkz. [hukuki karar listesi](legal_decisions_pending.md). Bu taslak onaylanmış gizlilik politikası değildir.
