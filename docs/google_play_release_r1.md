# DriveIt R1 — Google Play derleme altyapısı

## Kapsam ve mevcut durum

- Normal Android kimliği `com.example.driveit_project` olarak kalır. İzole
  Android test kimliği `com.example.driveit_project.isolated_test` olarak kalır.
- Play derlemesi yalnız `DRIVEIT_PLAY_RELEASE=true` ile seçilir ve sabit
  `com.osaracx.driveit` kimliğini kullanır. Java/Kotlin `namespace` değeri
  `com.example.driveit_project` olarak kalır; kaynak paketleri ve mevcut
  normal/izole derleme akışları yeniden adlandırılmaz.
- Play yolunda target SDK 36, pozitif versionCode ve boş olmayan versionName
  derleme öncesi doğrulanır. Aday kaynak değeri `pubspec.yaml` üzerinden
  `1.0.1+2` olarak seçilmiştir; Play Console'daki son kullanılan sürüm kodu
  salt okunur doğrulanamadığından yüklemeden önce kullanılabilirliği teyit edin.
- Play release debug signing kullanmaz. Release yalnız repo dışındaki gerçek
  upload keystore'u, alias ve process environment üzerinden sağlanan şifrelerle
  imzalanabilir. Değerler build loguna yazılmaz.
- Play derlemesi DEV Supabase config'ini ve henüz doğrulanmamış owner aktivasyonu,
  otomatik senkronizasyon, silme ve Grup Sürüşü feature flag'lerini reddeder.
  Bulut özellikleri production ortamı doğrulanana kadar devre dışı kalır.
- `tool/build_play_aab.ps1`, AAB üretiminden önce signing materyali ve bundletool
  gerektirir. Ardından bundletool doğrulaması, manifest kimliği/SDK/version,
  64-bit ARM Flutter kütüphanesi ve AAB imzası kontrol edilir.

## Veri izolasyonu

`applicationId` Android uygulama sandbox'ını ve uygulama verisi alanını
belirler. Play kimliği eski `com.example.driveit_project` kurulumundan farklı
olduğu için Play sürümü aynı cihazda ayrı uygulama ve ayrı Hive/SQLite alanı
olarak yüklenir; eski yerel sürüş kayıtları otomatik olarak taşınmaz. Eski
kurulum korunur ve verilerinde değişiklik yapılmaz. Eski kayıtların Play
sürümüne taşınması daha sonra ayrı, açık onaylı ve doğrulanmış aktarım çalışması
gerektirir. Manifest'teki FileProvider authority `${applicationId}` ile
üretildiğinden iki kimlik arasında çakışma oluşmaz.

## Yerel upload anahtarı hazırlığı

Repo dışında bir upload keystore dosyası mevcuttur; bu görevde dosya okunmamış,
değiştirilmemiş ve içeriği raporlanmamıştır. Build process'inde alias/password
değerleri ve bundletool yolu bulunmadığından yeni imzalı AAB üretilmedi.
Kullanıcı Play Console uygulama kaydını, package ID'sini ve mevcut upload
certificate eşleşmesini doğruladıktan sonra:

1. Mevcut dosyanın Play Console'da kayıtlı upload key ile eşleştiğini güvenli
   ortamda doğrulayın. Eşleşme yoksa kullanıcı/Play Console anahtar sahibinin
   kontrollü anahtar sıfırlama veya yeni upload certificate sürecini ayrıca
   yürütmesi gerekir; mevcut keystore'u değiştirmeyin.
2. Keystore'un iki şifreli, erişimi kısıtlı yedeğini farklı güvenli konumlarda
   saklayın. JKS dosyası, şifreler ve keystore yedekleri Git/OneDrive'a
   gönderilmemelidir.
3. PowerShell build oturumunda `DRIVEIT_PLAY_KEYSTORE` (tam dosya yolu),
   `DRIVEIT_PLAY_KEY_ALIAS`, `DRIVEIT_PLAY_STORE_PASSWORD` ve
   `DRIVEIT_PLAY_KEY_PASSWORD` process environment değerlerini tanımlayın.
   Şifreleri komut argümanı, terminal çıktısı, Gradle properties veya repo
   dosyasına yazmayın.
4. `DRIVEIT_BUNDLETOOL_JAR` değerini doğrulanmış bundletool JAR yoluna ayarlayın
   ve `tool/build_play_aab.ps1` çalıştırın. Script imza SHA-256 parmak izini
   gösterir; Play Console'a yalnız upload certificate kaydedilir. Play App
   Signing etkinleştirildiğinde son kullanıcılara Play'in app-signing
   certificate'ı ile imzalı paket dağıtılır.

## Play Console ve yayın öncesi doğrulama

- Play Console'daki uygulama kaydının package name'inin tam olarak
  `com.osaracx.driveit` olduğu sahibi tarafından doğrulanmalıdır. Package name
  farklı bir kayda sonradan taşınamaz.
- Play App Signing kaydında upload certificate kullanılmalı; dağıtım
  certificate'ı Play tarafından yönetilmelidir.
- Google Maps Android client key'in Play paket adı ve Play App Signing
  certificate fingerprint'i ile kısıtlandığı Google Cloud Console'da
  doğrulanmalıdır. Manifest'te uygulama tarafından okunacak client key bulunur;
  bu anahtarın değeri rapora veya build loguna alınmamalıdır.
- `ACCESS_BACKGROUND_LOCATION`, location foreground service ve bildirim
  açıklamaları için gerekli Play Console beyanları ve mağaza açıklamaları ayrıca
  tamamlanmalıdır. Bu aşama konsol ayarı veya yükleme yapmaz.
- Mevcut Play Console kaydı, kapalı beta tester listesi, gizlilik/data safety
  formları ve `versionCode` kullanılabilirliği bu derleme denetiminden
  doğrulanamaz.

## Güvenlik sınırları

Bu aşama Supabase'e bağlanmaz; migration, Play Console yüklemesi veya cihaz
kurulumu yapmaz. Normal uygulama, izole test APK'sı ve Play release build
kimlikleri ayrı tutulur. Play App Signing ve package kaydı kullanıcı tarafından
doğrulanana kadar bu AAB lane'i gerçek anahtar olmadan çalışmaz.
