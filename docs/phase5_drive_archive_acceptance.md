# Aşama 5 / Teslimat 1 — Android cihaz doğrulaması ve arşiv erişimi

Tarih: 11 Ekim 2026. Branch: `feature/gps-refactor`. HEAD:
`f68445cb7038e50b95f0da139fc7b7b307267105`. Önceki Aşama 5 çalışmaları korunmuştur.

## A. Android doğrulama yöntemi ve değişen dosyalar

Flutter ekibinin sürdürdüğü [local_auth 3.0.2](https://pub.dev/packages/local_auth)
kullanıldı; Android uygulaması 2.2.0. `biometricOnly: false`, sistemin biyometrik veya
PIN/desen/şifre doğrulamasına izin verir. `persistAcrossBackgrounding: false` ile
arka planda otomatik yeniden doğrulama yapılmaz. DriveIt'e özel şifre oluşturulmaz.

`isDeviceSupported()` tek başına ekran kilidinin mevcut olduğunu kanıtlamaz. Ayrı
MethodChannel üzerinden Android `KeyguardManager.isDeviceSecure` doğrulama öncesi ve
başarısından sonra kontrol edilir. Güvenli kilit yoksa, kanal/plugin bulunamazsa,
kullanıcı iptal ederse, kilitlenme veya native hata oluşursa erişim reddedilir.
İstisna mesajları, koordinatlar, credential ve kişisel veri loglanmaz.

Bu kapanış çalışmasında değiştirilen dosyalar:

- `pubspec.yaml`, `pubspec.lock`: local_auth ve platform bağımlılıkları.
- `android/app/src/main/kotlin/com/example/driveit_project/MainActivity.kt`:
  `FlutterFragmentActivity`, mevcut poster/storage köprüleri korunarak güvenli
  ekran kilidi sorgusu. Kanal Activity kapanırken ayrılır.
- `android/app/src/main/AndroidManifest.xml`: `USE_BIOMETRIC` izni.
- `android/app/src/main/res/values/styles.xml`, `values-night/styles.xml`,
  `values-v31/styles.xml`: plugin için AppCompat temaları; mevcut splash/renk
  özellikleri korunur. [Resmî Android kurulum gereksinimleri](https://pub.dev/packages/local_auth_android).
- `lib/services/android_device_archive_authorizer.dart`: fail-closed Android
  sağlayıcısı ve açık controlled composition fonksiyonu.
- `lib/services/device_drive_archive.dart`: kısa ömür, lifecycle ve epoch bariyeri.
- `lib/widgets/owner_personal_navigator.dart`: doğrulanmış snapshot açıkça verilirse
  gerçek Android sağlayıcısını controlled History arşiv girişine bağlar.
- `test/android_device_archive_authorizer_test.dart`, `test/device_drive_archive_test.dart`.
- Bu rapor ve önceki teslimat raporundaki tarihsel sonuç güncellemesi.

`main()` ve production gate değiştirilmedi. Android Activity/theme değişimi normal
build'e de derlenir; gate kapalıyken doğrulama çağrısı veya arşiv erişimi başlatmaz.
Bu native Activity değişiminin fiziksel kabulü henüz yapılmış sayılmaz.

## B. Erişim ve epoch güvenliği

Arşiv butonuna basılması veya Supabase oturumu erişim kanıtı değildir. Başarılı
Android doğrulamasından sonra ayrı `DeviceDriveArchiveContext` oluşturulur. İki
dakikalık süre monotonik Stopwatch ve Timer ile uygulanır. Context kaydın sahibini
değiştirmez; owner lease yalnız iptal/epoch kontrolü içindir.

Auth/owner epoch değişimi context'i kalıcı iptal eder. A→B→A eski yetkiyi yeniden
canlandırmaz. Verilmiş yetki, resumed dışındaki lifecycle durumunda iptal olur.
Arka plandan geri dönmek yeni cihaz doğrulaması gerektirir. Gecikmiş sonuçlar lease
doğrulamasından geçmeden uygulanmaz; süresi dolmuş/iptal edilmiş context ile ID
okuma reddedilir ve liste/detail/harita unavailable görünümüne geçer.

Doğrulama penceresi geçici `inactive` odağı oluşturabilir: başarılı sonuçtan sonra
resumed beklenir (en fazla 10 saniye). Buna karşılık challenge sırasında
paused/hidden/detached görülürse geç gelen başarılı sonuç da reddedilir. Bu bir
background muafiyeti değildir. Yerel PIN fallback'inin belirli Android sürümünde
Activity pause üretip üretmediği gerçek cihazda kontrol edilmelidir; güvenlik
kontrolü gevşetilerek varsayımsal başarı verilmez.

Paralel buton basımları paralel prompt açmaz. `/device-archive/detail` gibi yalnız
ID taşıyan route kayıtlı değildir; account navigator doğrudan arşiv capability'si
üretemez. Snapshot doğrulaması ve gerekli kayıtlı writer fence korunur. Gate açık
ama snapshot/owner/yetki eksikse ortak depoya fallback yapılmaz.

## C. Arşiv ekran zinciri

Controlled owner navigator'a doğrulanmış snapshot verildiğinde:

`Sürüşlerim → Cihazdaki Eski Sürüşler → Android doğrulaması → liste → detay → GPS haritası`.

Mevcut salt okunur arşiv ekranları yeniden kullanılır. Date gerçek durdurma zamanı
diye sunulmaz; kaydedilmiş temel detaylar ve sıralı/segmentli GPS geometrisi
gösterilir. Silme, düzenleme, yeni skor, poster erişimi, Career yazımı, World
rebuild, yayınlama veya hesap sahiplenmesi eklenmedi.

## D. Kaynak veri değişmezliği

Snapshot/okuyucunun source capture ve binary integrity kodu değiştirilmedi.
Kaynak Hive kaydı yeni hesaba kopyalanmaz; SQLite journal'dan tamamlanmış sürüş
üretilmez. Kaynak `.hive` bytes öncesi/sonrası eşitliği, detached nesne koruması,
bozuk snapshot reddi ve History→detay→GPS haritası sentetik testleri korunur.
Bu kanıt gerçek A55 dosyalarının okunmuş veya değiştirilmiş olduğu anlamına gelmez.

## E. Otomatik doğrulamalar

- Hedefli cihaz doğrulaması + arşiv: **29 geçti, 0 atlandı, 0 başarısız**.
- İlk tam Flutter: **873 geçti, 2 koşullu atlandı, 0 başarısız**, yaklaşık 79 saniye.
  Sonrasında yalnız yeni kodun analiz stil bildirimleri düzeltildi; son tekrar
  sonucu aşağıya kaydedilir.
- İki skip: host koşusunda isolated-Android define isteyen backend guard ve
  Windows'ta sentetik symlink oluşturma fixture'ı. Geçilmiş sayılmadı.

### Son doğrulama

- İzole debug APK derlemesi **başarılı** (yaklaşık 117 saniye):
  `flutter build apk --debug --no-pub --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`.
  `aapt dump badging` ile gerçek paket **com.example.driveit_project.isolated_test**,
  minSdk 24 / targetSdk 36 doğrulandı. Bu compile kontrolüdür, native kabul değildir.
  Dosya: `build/app/outputs/flutter-apk/app-debug.apk`. Kurulum yapılmadı.
- Derleme mevcut `flutter_foreground_task` Kotlin Gradle Plugin kullanımı için
  gelecekteki Flutter uyumluluğu uyarısı verdi; derleme başarısını engellemedi.
  Uyarıyı gidermek için GPS eklentisi/mimarisi bu görevde değiştirilmedi.
- Son tam Flutter tekrarı: **873 geçti / 2 koşullu atlandı / 0 başarısız**,
  yaklaşık 80 saniye; exit 0. Bağımsız Flutter/Gradle runner'ları eşzamanlı çalışmadı.
- Son `flutter analyze`: **yalnız mevcut 4 info**, yeni info/warning/error yok.
  `home_screen.dart` string interpolation, `map_screen.dart` WillPopScope ve
  string interpolation, `route_preview.dart` withOpacity bildirimleri kaldı.
  Info'lar nedeniyle exit 1; temiz exit 0 olarak sunulmaz. Yaklaşık 80 saniye.
- `git diff --check`: exit 0. Yeni untracked kaynak/test/raporlar ayrıca no-index
  whitespace kontrolünden geçirildi; yalnız repo CRLF uyarıları vardır. No-index
  komutunun diff bulunduğu için verdiği exit 1 whitespace hatası değildir.
- Derleme `android/.kotlin/` gibi üretilmiş yerel çıktılar bırakabilir; bunlar
  kaynak veya kullanıcı verisi değildir ve stage/commit edilmedi. Önceki
  untracked `android/build/` ve diğer çalışmalar korunmuştur.

Fake provider testleri başarı, cancel, false sonucu, lock yok, unsupported cihaz,
native hata, missing bridge, kilit değişimi ve paralel prompt engelini doğrular.
Arşiv testleri epoch yarışı, background, süre sonu, doğrudan route reddi, kaynak
değişmezliği ve tam ekran zincirini doğrular. Hostta GoogleMap native gesture/tile
ve gerçek Android PIN/parmak izi başarılı sayılmaz.

## F. A55 native kabul durumu

`adb devices -l` çıktısı boştur. Bu tur A55 native prompt gösterimi, kullanıcı
iptali ve başarılı parmak izi/PIN/desen/şifre kabulü **çalıştırılmadı**. Asıl
`com.example.driveit_project` paketine hiçbir işlem yapılmadı. Android doğrulaması
ADB ile atlatılmadı; gerçek veri okunmadı ve APK kurulmadı.

Fiziksel kabul yalnız `com.example.driveit_project.isolated_test` sandbox'ında
sentetik snapshot/fake owner ile yapılmalıdır. Her kurulum öncesi paket kimliği
kontrol edilmelidir. Kullanıcı gerçek sistem prompt'unda iptal/başarı adımlarını
yapmalı; ardından background, epoch, süre sonu ve yeniden doğrulama kontrol edilir.

## G. Açık gerçek engeller ve karar

Host entegrasyon tamamdır; fiziksel Android kimlik doğrulama kabulü açık kalır.
Ek mimari alt aşama gerekmez; cihaz bağlı olduğunda izole kabul yapılabilir.
Doğrulanmış snapshot provisioning ve source writer/GPS busy bariyerleri gerçek
kullanıcı akışına bağlanmadan üretim erişimi verilmez. Önceki in-memory snapshot
bellek maliyeti sınırları değişmemiştir.

Production ownership gate **KAPALI**. Gerçek kullanıcı migration/import/revision
publish, Supabase, GPS journal değişikliği, gerçek APK kurulumu, commit/push ve
`tatus` işlemi yapılmadı.

**Teslimat 1: KISMEN.** Android erişim kodu ve host kabul tamamlandı; fiziksel
cihaz kabulü yapılmadığı için production-ready ilan edilmez.
