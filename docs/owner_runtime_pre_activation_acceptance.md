# Owner runtime — aktivasyon öncesi son kabul

12 Ekim 2026. Branch `feature/gps-refactor`, checkpoint `638c58a720a3c5d14c214227a3c6603891f516df`. Önceki tüm çalışma alanı değişiklikleri korundu.

## A. Composition denetimi

**Kontrollü runtime composition: EVET. Gate-açık gerçek release composition: HAYIR.**

`lib/main.dart` içindeki `main → startDriveIt(default LocalOwnershipGate.production OFF) → LocalOwnershipBootstrap → _legacyBootstrap` kapalı üretim yoludur. Yeni paket bariyeri yalnız enabled branch'te, kişisel depolar açılmadan çalışır. Kapalı akışın Hive/GPS/Auth sırası değişmedi. Yeni migration/import açılmadı.

Enabled root tam `ControlledOwnershipDependencies`, arşiv kaynağı ve writer fence ister. Auth restore tamamlanmadan store açılmaz; restore hatası guest sayılmaz, null kullanıcı için açık guest kararı gerekir. Lifecycle lease/epoch, scoped store ve navigator `/drive` bağlantıları ortak `DriveItApp` kökündedir.

Bu turun native testi `startDriveIt` ile aynı kökü oluşturdu; uygulamanın kendi lazy archive loader'ını ve default `AndroidDeviceArchiveAuthorizer` adapter'ını kullandı. Device-auth fake override verilmedi. Test Auth'u fake A/B; journal/sidecar sqflite, scoped kayıtlar Hive; legacy kaynak tamamen sentetik. Testin arşiv lifecycle aşamaları ayrı MaterialApp route harness'ında list→detail→map açar; History butonunu yeniden end-to-end tıklama değildir. Önceki gerçek root History giriş kabulü bu farktan ayrı kanıttır.

Üretimden farklar: descriptor `prepareForTesting`, foreground attachment `attachForTesting`, fake Auth, sentetik depolar ve platform maps fake. Gerçek Supabase Auth restore adapter'ı mevcut olsa da gerçek release kaynaklarını seçen gate-açık composition kurulmuş değildir. Bu tur rollout geliştirmesi yapılmadı. Yalnız gate'i açmak yeterli değildir.

## B. Paket bariyeri

`startDriveIt` enabled Android yolunda isolated define ve native `isIsolatedDebugRuntime` sonucu zorunlu. `MainActivity` gerçek `packageName == com.example.driveit_project.isolated_test` ve Android debuggable flag'i birlikte doğrular. Normal paket, release paket, false/missing native kanıt fail-closed olur; backend guard yokken kontrollü start reddedilir. Method gate açmaz, sadece mevcut kontrollü start talebini sınırlar. Production gate hâlâ OFF; synthetic gate release/profile'da zaten reddedilir.

Normal pakette negatif native test için gerçek uygulamaya test kurulmadı. Bu ret koşulu kaynak/compile kanıtıdır; pozitif izole koşul A55 üzerinde gerçek bootstrap tarafından yürütüldü.

## C. Gerçek Android cihaz doğrulaması

**PIN/biometri cihaz doğrulaması: EVET.** A55 SM-A556E / API36 / `R5CX42V8GSJ`, yalnız isolated debug APK. Aapt kimliği kurulum öncesinde doğrulandı. `local_auth` gerçek Android prompt ve Keyguard secure-lock kontrolü kullandı. Kullanıcı ilk pencereyi iptal etti, sonraki pencereleri telefon üzerinden doğruladı; credential sohbete alınmadı, ADB bypass yapılmadı.

`device_archive_lifecycle_android_test.dart`: **1/1 geçti**, exit0, native test 39 saniye. Log işaretleri:

- `ARCHIVE_NATIVE_CANCEL_DENIED`: iptal sonrası capability verilmedi.
- `ARCHIVE_NATIVE_GRANTED`: gerçek OS doğrulaması ardından context açıldı.
- `ARCHIVE_HOME_REVOKED`: Home/geri dönüş eski context'i geçersiz kıldı; detail ID okuması reddedildi.
- `ARCHIVE_LOCK_REVOKED`: ekran kilidi/geri dönüş eski context'i iptal etti; yeniden doğrulama gerekti.
- `ARCHIVE_OWNER_REVOKED`: A→B epoch değişimi cihaz yetkisini iptal etti.

Sentetik list→detail→GPS map açıldı; legacy Hive dosyasının önce/sonra bytes'ı aynı. Harita platformu fake; gerçek harita render/movement kabulü değildir.

Yanlış PIN veya kayıtlı olmayan parmakla başarısız deneme bu tur **fiziksel olarak uygulanmadı**; native yanlış-credential ret kabulü tamamlandı diye gösterilmez. Host `failed challenge denies`, native exception/cancellation ve erişim sınır testleri geçti. Android'in yanlış denemeden sonra açık tutabildiği prompt başarılı doğrulama sonucu değildir; uygulama yalnız başarılı sonuçtan capability üretir. Yetkisiz deep link/detail/map sınırları host testlerinde doğrulandı; normal gerçek pakete saldırı testi yapılmadı.

## D. Testler

- Hedefli bootstrap/writer/archive/authorizer: **54/54**.
- Tam Flutter: **897 geçti, 2 koşullu atlandı, 0 başarısız**, 1 dakika 31 saniye, exit0. Atlamalar Windows symlink koşulu ve isolated define isteyen backend guard.
- İlk analyze: mevcut 4 info + 5 test `print` style info; test logları `debugPrint` yapıldı. Runtime davranışı değiştirilmedi.
- Nihai analyze: yalnız mevcut **4 info**, yeni warning/error yok; info nedeniyle exit1, 46.6 saniye.
- `git diff --check`: exit0.
- Isolated native build başarılı. Native test `--no-uninstall --dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`; 8 dakikalık dış timeout yalnız çok adımlı manuel kabul içindir, iç beklemeler süre sınırlıdır. Önceki başarısız testi geçirmek için timeout artırımı yapılmadı.

Loglar: `build/owner_activation_targeted.log`, `build/owner_activation_full.log`, `build/owner_activation_archive_native.log`, `build/owner_activation_analyze_final.log`. Native logdaki modal barrier hit-test uyarısı saklandı; test başarısızlığı/exception değildir, lifecycle ve invalidation assertion'ları geçti.

## E. Değiştirilen dosyalar

- `lib/main.dart`: enabled Android girişinde native paket bariyeri.
- `android/app/src/main/kotlin/com/example/driveit_project/MainActivity.kt`: paket/debug kanıtı, gate aktivasyonu yok.
- `integration_test/device_archive_lifecycle_android_test.dart`: gerçek root/default authorizer/lazy loader composition, cancellation ve güvenli aşama logları.
- Bu rapor.

## F. Koruma ve karar

Asıl DriveIt'in APK yolu, versionCode1 ve lastUpdateTime `2026-10-12 01:48:53` değişmedi. Gerçek uygulamaya install, uninstall, force-stop, clear, izin değişikliği veya kullanıcı verisi okuma/yazma yapılmadı. Sadece sentetik test kaynakları kullanıldı. Production gate OFF; Supabase backend/cloud, journal v3, World/Score ve legacy import değiştirilmedi. Branch/commit/push işlemi yok; `tatus` ve `android/build/` korunmuştur.

**Son karar: KISMEN.** Gerçek cihaz doğrulamalı kontrollü runtime kabulü başarılı. Aktivasyon öncesi kesin engel: gate-açık gerçek release kaynak composition/foreground attachment seçimi henüz yok ve mevcut descriptor/attachment debug-only. Bu güvenlik sınırı bu tur kaldırılmadı. Ayrıca yanlış-credential native negatif kabulü açık kaldı. Bu rapor production gate'i açma veya gerçek APK dağıtım onayı değildir.
