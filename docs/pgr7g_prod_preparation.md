# P-GR7G — Play PROD hazırlığı

## Tamamlananlar

- Play `com.osaracx.driveit` çalışırken Supabase başlangıcı yalnız `https://arwnbogcswisfesayosy.supabase.co` adresini kabul eder. Yanlış host, protokol, port, kullanıcı bilgisi, yol, query veya fragment reddedilir. Geliştirici paketinin mevcut davranışı korunmuştur; bu kural DEV uygulamasını PROD'a karşı bağımsız olarak sınırlandırmaz.
- Mevcut R1 guard'ı Play derlemesine Supabase değerleri ve henüz doğrulanmamış cloud feature flag'leri eklenmesini hâlâ reddeder. Dolayısıyla PROD Auth, kişisel sync, Planet ve hesap silme bu aşamada etkinleştirilmedi.
- Android applicationId sandbox'ları farklıdır. `com.osaracx.driveit` eski `com.example.driveit_project` uygulamasının yerel dosyalarını kendiliğinden göremez. Eski veri taşıma işlemi eklenmedi. Bu mimari değerlendirme boş cihazda gerçek ilk açılış testinin yerine geçmez.
- `pending_legal_review` engeli korunmuştur. Testte bekleyen belgelerin onboarding'i ilerletmediği ve onaylanmış sürümlü test belgelerinin geçebildiği doğrulandı; hiçbir gerçek hukuki belge onaylanmış sayılmadı.

## Doğrulama

- Flutter ortam politikası, Auth callback, GPS sahipliği, hukuki onboarding ve izole Android backend guard testleri: **31 geçti, 1 atlandı, exit 0**. Atlanan test tamamlanmış kabul edilmez.
- Değişen Dart dosyalarında `dart analyze`: **No issues found, exit 0**.
- Önceki P-GR7F kontrolünde Play AAB package/version/SDK/callback ve upload imzası doğrulandı; A55 eski uygulama paketi salt okunur kontrol edildi ve kullanıcı geçmişin göründüğünü bildirdi. Bu yeni runtime değişikliği içeren yeni AAB veya cihaz testi yapılmadı.

## PROD aktivasyonu öncesi

- Play guard'ını gevşetmeden önce PROD Auth Redirect URL allowlist'i, signup durumu ve yalnız public anahtarın güvenli yapılandırılması ayrıca doğrulanmalı. Önceki salt okunur Auth sorgusu HTTP 401 döndürdü.
- Play owner runtime mevcut haliyle doğrulanmış PROD kompozisyonu değildir; `production_owner_runtime_factory.dart` içindeki DEV proje koşulları ve Auth/owner epoch, sync, Planet ve silme bağımlılıkları ayrı izole geliştirme ve kabul gerektirir. Bu aşama bunları açmaz.
- Hesap oluşturma/giriş, recovery, profil, kişisel bulut upload/download, Planet ve hesap silme; hosted yapılandırma, sunucu izinleri, owner izolasyonu ve gerçek cihaz uçtan uca testi olmadan hazır kabul edilmez.
- Hukuki aydınlatma, gizlilik, veri saklama/imha ve gerekli izin metinleri **ONAY BEKLİYOR**. Onaylı metinler ve sürümleri olmadan onboarding yayın engeli sürer.

## Gerçek cihaz kabulü

Kullanıcı onayıyla yalnız ayrı Play applicationId ve izole veri alanında ilk açılış, boş geçmiş/istatistik, eski veriye erişilmeme, eski uygulamanın geçmişinin korunması, callback ve hesap değişimi test edilmeli. Mevcut A55 uygulaması kaldırılmamalı veya güncellenmemeli. Bu testler bu aşamada yapılmadı.
