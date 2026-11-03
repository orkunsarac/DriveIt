# Google Play Data Safety — Başvuruya Hazırlık Taslağı

**Durum: HUKUKİ VE BUILD KABULÜ BEKLİYOR.** Bu belge Play Console beyanı değildir ve doğrudan gönderilmemelidir. Son cevaplar, gönderilecek imzalı AAB, o AAB'nin etkin özellikleri ve kullandığı tüm SDK sürümleri incelendikten sonra doğrulanmalıdır.

## Taslak kapsamı

Envanter, DriveIt kaynak kodundaki işleme yollarını ve Google'ın Maps SDK açıklamasını temel alır. Uygulama içi özelliklerin kapalı olması SDK'nın bağımsız telemetrisini otomatik olarak kapatmaz. Yerel olarak işlenen her veriyi “toplanmıyor” saymadan önce Play tanımı ve SDK davranışıyla eşleştirin. Supabase'ten gerçek DEV/PROD ağ telemetrisi bu görevde alınmadı.

| Play veri türü | Taslak cevap / kaynak davranışı | Toplanma ve paylaşım koşulu | Formda açık kalan doğrulama |
|---|---|---|---|
| Konum — yaklaşık ve kesin | Sürüş kaydı hassas GPS/rota/zaman verisi işler. | Kullanıcı sürüş kaydını başlatınca cihazda işlenir. Mapbox eşleştirmesi çağrılırsa rota koordinatları HTTPS üzerinden Mapbox'a aktarılır. Planet yayını kullanıcı eylemiyle kaynak rota verisini sunucuya yükleyebilir. Kişisel bulut senkronizasyonu etkin özellik ve hesap oturumuna bağlıdır. | Her konum türü için “toplanır/paylaşılır”, opsiyonel/zorunlu ve silme cevaplarını gönderilecek build/flags ile doğrulayın. Background location görünür izin ve Play beyanı ayrıca gerektirir. Grup konumu Group Drive kapısı kapalı olduğundan etkin özellik olarak beyan edilmemeli. |
| Kişisel bilgi — e-posta, ad, kullanıcı kimliği | Supabase Auth e-posta/UID; profil kullanıcı adı ve görünen ad. | Auth açık bir dağıtımda oturum/hesap işlemlerinde Supabase'e gider. Profil görünürlüğü backend politikalarıyla sınırlanmalı; Planet yayınında profil verisi paylaşımı ayrıca doğrulanmalı. | PROD kayıt kapalı; gerçek dağıtım config'i ve mevcut oturumların kapsamı henüz Play AAB'de doğrulanmadı. E-posta, ad ve UID alt türlerini ayrı işaretleyin. |
| Uygulama etkinliği — uygulama etkileşimleri ve kullanıcı tarafından oluşturulan içerik | Sürüşler, skorlar, rota/telemetri, yayın durumu ve bulut senkronizasyon kayıtları. | Yerel sürüşler cihazda kalabilir; bulut kopyası hesap senkronizasyonu etkinliğine, Planet içeriği açık yayın onayına bağlıdır. Planet türetilmiş ortak yol verileri diğer kullanıcılara sunulabilir. | Hangi etkinliklerin sunucuya gittiğini son release flags ve gerçek backend sözleşmesiyle doğrulayın; içerik için görünürlük ve silme yanıtlarını kesinleştirin. |
| Fotoğraf ve video | Profil fotoğrafı seçme/kırpma kodu vardır. | Kaynak incelemesi profil fotoğrafının bu release'te uzak depoya yazıldığını kanıtlamaz. | Build içindeki etkin upload yolunu doğrulayın; doğrulanmadıkça bu veri türünü varsayımla seçmeyin veya dışlamayın. |
| Finansal bilgi | Kod envanterinde ödeme veya satın alma akışı tespit edilmedi. | Bilinen yol yok. | Play Billing veya üçüncü taraf ödeme SDK'sı eklenmediğini son dependency/SBOM incelemesiyle teyit edin. |
| Sağlık ve fitness | Sürüş telemetrisi bulunur; sağlık verisi olarak tasarlanan bir akış tespit edilmedi. | Bilinen sağlık API entegrasyonu yok. | GPS/sürüş bilgisinin Play sınıflandırmasına uygunluğunu son beyan öncesi doğrulayın; kategoriyi yalnız uygulama bağlamına bakarak seçmeyin. |
| Mesajlar, kişiler, takvim, ses | Kaynak ve bağımlılık envanterinde bu veri kaynaklarına yönelik kullanıcı akışı tespit edilmedi. | Bilinen yol yok. | Son release dependency ve manifest incelemesinde yeniden doğrulayın. |
| Dosyalar ve belgeler | Rota/sürüş kaynak JSON'ları ve yerel veritabanları. | Uygulama özel alanında yerel saklama; kişisel bulut veya yayın yüklemesi etkinleşirse servis tarafına gidebilir. | Şifreleme-at-rest iddiası uygulama seviyesinde doğrulanmadı. Android app-private sandbox'ı uygulama şifrelemesi gibi beyan etmeyin. |
| Tanılama — kilitlenme günlükleri/performans | Google Maps SDK for Android dokümantasyonu SDK'nın istek metadata'sı (cihaz/OS/model, SDK sürümü ve sonuç sayısı), dahili attribution ID, IP ve kilitlenme/performans ölçümleri gönderebildiğini bildirir. | Google Maps SDK kullanılan AAB'de uygulama etkileşiminden bağımsız/SDK kaynaklı aktarım olabilir. | Maps SDK sürümünün ve Play SDK Index beyanlarının gönderilecek AAB ile aynı olduğunu teyit edin; Play formundaki diagnostics alt türlerini SDK beyanıyla eşleştirin. |
| Cihaz veya diğer kimlikler | Auth UID/owner kimliği uygulama tarafından kullanılır; Maps SDK dokümanında attribution ID ve SDK ID davranışı bulunur. | Auth/backend ve harita sağlayıcıları ilgili isteklerde kimlik/telemetri işleyebilir. | Hangi tanımlayıcıların Play kategori tanımına girdiğini SDK sürümü ve gerçek ağ/SDK envanteriyle doğrulayın. |

## Form kararı için zorunlu doğrulama

1. Tam release AAB ve kullanılan tüm Dart define/manifest değerlerini dondurun; debug, test ve DEV yapılandırmalarını üretim beyanına karıştırmayın.
2. AAB'nin Gradle/Flutter bağımlılık ağacını, Android manifestini, Google Play SDK Index bilgisini ve ilgili SDK Data Safety beyanlarını dışa aktarın.
3. Her tür için Google'ın “collected”, “shared”, “processed ephemerally”, optional/required, encryption-in-transit ve deletion sorularını özellik bazında kanıtlayın. Kaynakta TLS kullanımı, tüm SDK aktarımını tek başına kanıtlamaz.
4. Google Maps SDK'nın dokümante ettiği aktarımı ve Mapbox'a kullanıcı eylemiyle gidebilen rota koordinatlarını dahil edin. “Hiçbir veri paylaşılmaz” cevabı mevcut envanterle desteklenmiyor.
5. Hesap silme için çalışan ve uygulama dışından erişilebilen resmi yol şu anda yok. E-posta/başvuru adresi seçilmedi, web taslağı yayımlanmadı ve silme operatörü kabul edilmedi. Bu gereksinim çözülmeden hesap açma içeren release adayını Play'e gönderilebilir saymayın.
6. Veri sorumlusu kimliği, KVKK amaç/hukuki sebep, aktarım, saklama ve yerel verinin cihaz değişimindeki etkisi için hukuk onayı alın. Taslaklar kullanıcıya sunulmuş veya onaylanmış değildir.

## Kaynaklar

- [Google Play Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [Google Play background location requirements](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en)
- [Google Maps SDK for Android Data Safety](https://developers.google.com/maps/documentation/android-sdk/play-data-disclosure)
- Teknik kaynak envanteri: `docs/privacy_review/pgr6g_data_inventory.md`, `docs/privacy_review/google_play_data_safety_inventory.md`
