# DriveIt — Google Play kapalı beta hazırlığı

Tarih: 3 Kasım 2026. **Durum: PARTIAL; Play'e gönderime hazır yeni release adayı yok.** Bu belge taslaktır; hukuki onay, Play Console beyanı veya yayın değildir. İncelenen Git checkpoint'i `f97ad26`; R1 Android yapılandırması ve build betiğinde mevcut, checkpoint dışı yerel değişiklikler bulunmaktadır.

## Release kimliği ve build durumu

| Alan | Doğrulanan durum / gerekli işlem |
| --- | --- |
| Play applicationId | R1 yerel Gradle yapılandırmasında `com.osaracx.driveit`; diğer normal ve izole paket kimlikleri ayrıdır. Mevcut yerel Gradle farkı korunmuştur ve Git checkpoint'inde bulunduğu varsayılmamalıdır. |
| version | `pubspec.yaml`: `1.0.0+1`; mevcut AAB'de versionCode 1, versionName 1.0.0. Yeni yükleme için Play Console'daki son kod kontrol edilip kullanılmamış bir versionCode seçilmelidir. |
| SDK | Mevcut AAB: minSdk 24, targetSdk 36. Yeni Android uygulama/güncellemeleri için [Google Play'in 31 Ağustos 2026 target API şartı](https://support.google.com/googleplay/android-developer/answer/11926878) API 36'dır; Play Console'daki güncel kural yeniden kontrol edilir. |
| R1 upload imzası | Mevcut repo dışı keystore dosyası ve önceki upload sertifikası kaydı mevcut. Signing parolaları process/user/machine environment içinde bulunmadığından yeni imzalı build **çalıştırılmadı**. Keystore, alias ve parolalar yeniden oluşturulmadı. |
| Önceki AAB | `build/app/outputs/bundle/release/app-release.aab`, 1 Kasım 2026; 87.679.609 bayt; SHA-256 `d9cb27a06c5564ddcbc543698f70dacb66f15c05e7193b590d35762b87caf798`. Bu dosya mevcut checkpoint'in yeni build sonucu değildir. Bundletool validate, jarsigner, kayıtlı upload sertifikası, package ve version kontrolleri PASS. |
| 16 KB | Önceki AAB `PAGE_ALIGNMENT_16K` bildiriyor; 8 adet 64-bit ELF için program segmenti hizalama kontrolü PASS. Mevcut eski release APK'da `zipalign -c -P 16 4` exit 0. Yeni AAB'den üretilmiş APK ve 16 KB sistemde çalıştırma bu görevde doğrulanmadı. [Android doğrulama yönergesi](https://developer.android.com/guide/practices/page-sizes) hem ELF hem APK paket hizalamasının kontrol edilmesini ister. |
| Build kapıları | Yerel R1 Gradle yolu Play modunda izole test ve debug varyantlarını, Supabase URL/key tanımlarını ve etkinleştirilmiş owner/sync/delete/Group flag'lerini reddeder. Play Auth, PROD signup, Group Drive ve silme UI açılmadı. Nihai AAB üzerinde guard ve endpoint taraması yeniden yapılmalıdır. |
| Harita yapılandırması | Android manifestinde istemciye görünür Google Maps API anahtarı alanı var; anahtar değeri bu belgeye alınmaz. Play applicationId ve upload/distribution sertifikası için sağlayıcı kısıtlarının ve kota/faturalandırma durumunun sahibi tarafından doğrulanması gerekir. Mapbox kullanımı ve token kapsamı nihai build'e göre ayrıca doğrulanmalıdır. |

`tool/verify_play_candidate.ps1` bağımsız AAB kontrolü için package, hedef sürüm, target SDK, bundle 16 KB alignment, 64-bit ELF ve beklenen upload sertifikasını doğrular. Geçmiş AAB üzerinde PASS; hatalı versionCode ve hatalı sertifika negatif kontrolleri PASS. Araç, dosyanın güncel commit'ten üretildiğini, üretilen APK ZIP hizalamasını veya cihaz davranışını tek başına kanıtlamaz.

## İzin ve hizmet incelemesi

`AndroidManifest.xml` fine/coarse ve background location, internet/ağ durumu, foreground service/location, wake lock, notifications ve biometric izinlerini bildirir. Foreground service `location` tipindedir. İzin onboarding'i konum açıklamasından sonra foreground iznini ister; kaynak yorumuna göre background iznini bu adımda istemez. Aktif sürüşte foreground konum hizmeti ve GPS journal kullanılır. Background izninin gerçekten gerekli olduğu, işletim sistemi davranışı ve Play beyanı yayınlanacak sürüm üzerinde ayrıca incelenmelidir; yalnız manifestte bulunması yeterli gerekçe değildir.

Play, konum için minimum kapsam, belirgin açıklama ve gerekli olduğunda background-location beyanı ister. Android 14+ foreground service türleri Play Console'da açıklanmalı ve ilgili özellik videosu hazırlanmalıdır. Bkz. [background location](https://support.google.com/googleplay/android-developer/answer/9799150) ve [foreground service](https://support.google.com/googleplay/android-developer/answer/13392821).

## Data Safety ve hukuki hazırlık — karar bekliyor

Play beyanı nihai dağıtılacak AAB, SDK sürümleri ve gerçek ağ davranışı üzerinden hazırlanır. [Mevcut teknik veri envanteri](privacy_review/google_play_data_safety_inventory.md) temel alınır; aşağıdaki tablo otomatik doldurulacak bir Play beyanı değildir.

| Veri / işlev | Kaynak kanıtı ve doğrulama ihtiyacı |
| --- | --- |
| Kesin/yaklaşık konum, rota, hız, zaman | Android konum izinleri, `lib/services/task_handler.dart`, GPS journal ve sürüş/telemetri depoları. Harita SDK'sı ve etkinleştirilmiş Mapbox yol eşleme çağrılarının sağlayıcıya aktardığı alanlar SDK sürümleriyle doğrulanmalı. |
| Sürüş istatistikleri, Drive Score, Replay | Yerel sürüş ve telemetri depoları. Kişisel bulut/Planet yalnız ilgili özellik ve yapılandırma etkinse ayrıca değerlendirilir; kapalı beta metninde bunların etkin olduğu iddia edilmez. |
| E-posta, hesap kimliği, profil | Supabase Auth ve profil servislerinde işlenebilir; R1 Play guard'ı Auth/sync yapılandırmasını kapatır. Dağıtılan sürümün gerçek erişilebilirliği ve SDK veri akışları doğrulanmalı. |
| Fotoğraf/üretici içerik, tanılama ve cihaz tanımlayıcıları | Yerel profil görseli ve harita/diğer SDK'lar incelenmeli; üçüncü taraf SDK veri güvenliği bildirimleri, loglar, alıcılar ve saklama süreleri kesinleştirilmeden “toplanmıyor” seçilmez. |
| Yedek ve silme | `allowBackup=false` ve cihaz transfer kuralları yerel depoları dışlar. Önceki cihaz yedeklerinin silindiği kanıtlanmadı. Yerel veri ile hesap/bulut silmesi ayrı doğrulanmalıdır. |

Yayından önce gerçek veri sorumlusu kimliği/adresi, veri kategorileri ve hukuki sebepler, sağlayıcılar ve yurt dışı aktarım bilgisi, gerçek saklama/imha süreleri, kullanıcı hakları kanalı ve hukuki inceleme belirlenmelidir. Gizlilik politikası, KVKK aydınlatması ve kullanım koşulları onaylanmalı ve kamuya açık URL'leri doğrulanmalıdır. Geçmiş taslaklarda yer alan eski Gmail adresi aktif destek/silme kanalı olarak kullanılmamalıdır; yeni sahipliği ve çalışması doğrulanmış iletişim adresi **SEÇİLMEDİ**.

Hesap oluşturma sunulan bir sürümde Play, uygulama içinde ve uygulama dışında kolay bulunabilir silme başlatma yolu ile Data Safety formuna çalışan web bağlantısı ister. `delete-account` için yerel teknik kabul, PROD'da etkin bir kullanıcı kanalı veya yayımlanmış web sayfası anlamına gelmez. Gerekli URL, operatör, kimlik doğrulama ve retention açıklaması **BEKLİYOR**. Kaynak: [Google Play hesap silme şartları](https://support.google.com/googleplay/android-developer/answer/13327111).

## Play Console için taslak metinler

**Kısa açıklama — ürün ve hukuk incelemesi bekliyor:**

> Sürüşlerini kaydet, rotanı ve sürüş istatistiklerini incele.

**Uzun açıklama — ürün ve hukuk incelemesi bekliyor:**

> DriveIt ile başlattığın sürüşleri kaydedebilir, rotanı ve sürüşüne ilişkin istatistikleri görüntüleyebilirsin. Sürüş geçmişini inceleyebilir ve desteklenen kayıtlarda sürüşünü Replay ile yeniden izleyebilirsin. GPS ve cihaz koşulları ölçümlerin doğruluğunu etkileyebilir. Sürüş sırasında telefonunu güvenli kullan ve trafik kurallarına uy.

Yayınlanan özellikler, ekran görüntüleri, dil ve iddialar nihai AAB ile eşleştirilmeli; kapalı Auth, bulut, Planet yayın ve Group Drive yetenekleri aktifmiş gibi tanıtılmamalıdır. Veri güvenliği ve gizlilik metinleri doğrulanmış veri sorumlusu, sağlayıcılar ve erişilebilir URL'ler olmadan tamamlanamaz.

## Kapalı test hazırlığı

Uygulanıyorsa 13 Kasım 2023 sonrasında oluşturulmuş kişisel geliştirici hesapları için en az 12 testçinin en az 14 gün aralıksız opt-in kaldığı kapalı test, üretime erişim başvurusu için gereklidir; hesabın türü ve tarihi Play Console'dan doğrulanmalıdır. [Google Play test gereksinimi](https://support.google.com/googleplay/android-developer/answer/14151465).

Test planı: bilgilendirilmiş test katılımcılarıyla kurulum/onboarding, izin red ve ayarlardan dönüş, aktif sürüşte arka plan ve bildirim, işlem kapanması sonrası kurtarma, rota/puan/Replay bütünlüğü, çevrimdışı davranış, farklı ekran boyutları, pil kısıtları ve sürüm güncellemesi. Hesap/cloud/Planet/silme yalnız ilgili release gate'i ve hukuki/operasyonel kabul ayrıca açıldığında test kapsamına alınır. Gerçek sürüş verileriyle zorlayıcı kill/reset testleri yapılmaz.

## Yayın engelleri

1. Güncel commit ve onaylı release konfigürasyonundan yeni upload-imzalı AAB; gizli signing girdileri güvenli ortamda sağlanmalı, sürüm kodu Console ile doğrulanmalı.
2. Yeni AAB'den üretilen APK'da 16 KB ZIP/ELF doğrulaması ve uygun cihaz/emülatörde çalışma; gerçek release adayında SDK/endpoint/credential incelemesi.
3. Hukuki onaylı gizlilik, aydınlatma ve koşullar; veri sorumlusu, alıcılar, saklama ve doğrulanmış destek adresi.
4. Etkin hesap özelliği varsa üretimde onaylı uygulama içi ve kamuya açık web silme yolu, receipt/operasyon ve retention beyanı.
5. Data Safety ile background location/foreground service beyanları, gerekli video ve Play Console bilgilerinin sahibi tarafından doğrulanması.
6. Gerekliyse testçi cohort'u ve 14 günlük kapalı test, cihaz kabulü ve Play App Signing dağıtım sertifikası.

PROD ayarları ve Play Console üzerinde hiçbir değişiklik veya yayın işlemi yapılmadı.
