# P-GR7F — Play kimliği ve veri koruma kabulü

Durum: **KISMEN DOĞRULANDI**. Play Console paket adı kullanıcı tarafından `com.osaracx.driveit` olarak doğrulandı. Yeni upload imzalı AAB doğrulandı; hosted Auth ve cihazdaki geçmiş kabulü bekliyor.

## Doğrulananlar

- Aktif branch `feature/gps-refactor`; başlangıç HEAD `6c9c57665e8e8af5d46ae31bd5d64c497ceda8e6`. Önceden mevcut R1/R1.1 Gradle ve araç değişiklikleri çalışma ağacında korunuyor; henüz checkpoint'e alınmadı.
- `DRIVEIT_PLAY_RELEASE=true` ile yerel `:app:verifyAndroidApplicationId` görevi **PASS / exit 0**: `com.osaracx.driveit`, target SDK 36, versionName `1.0.0`, versionCode `1`. Bu görev tek başına imzalı AAB üretildiğini kanıtlamaz.
- İmza yapılandırması eksikken `:app:verifyPlayReleaseSigning` görevi beklenen biçimde **reddetti / Gradle exit 1**. Keystore olmadan debug imzalı Play release kabul edilmedi.
- Mevcut eski `app-release.aab`, resmî Google bundletool 1.18.3 ile okundu: `com.example.driveit_project`, versionCode `1`, versionName `1.0.0`, target SDK 36. `keytool -printcert -jarfile` sertifikayı `CN=Android Debug` olarak gösterdi. Bu eski AAB Play upload çıktısı olarak kabul edilmez.
- A55 bağlandıktan sonra, yalnız kurulu APK salt okunur çekilip incelendi: `com.example.driveit_project`, versionCode `1`, versionName `1.0.0`, sertifika `CN=Android Debug`, SHA-256 `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`. Kullanıcı eski uygulamada sürüş geçmişinin göründüğünü ayrıca bildirdi. Sürüş dosyaları Codex tarafından okunmadı veya değiştirilmedi. Isolated debug APK kimliği `com.example.driveit_project.isolated_test` olarak ayrıca ölçüldü.
- `flutter test --no-pub test/driveit_auth_callback_test.dart test/gps_session_ownership_test.dart`: **27 geçti / exit 0**. Testler callback eşleşmesi ve sentetik sürüş sahibi ayrımını kapsar; fiziksel cihazdaki verilerin varlığını kanıtlamaz.
- Resmî bundletool 1.18.3 JAR dosyası Google GitHub release asset'inden indirildi ve release API SHA-256 digest'iyle doğrulandı.
- Yeni `app-release.aab`: bundletool validate ve jarsigner verify **PASS / exit 0**; package `com.osaracx.driveit`, versionCode `1`, versionName `1.0.0`, target SDK `36`. Tek bir intent-filter içindeki scheme/host/path `com.osaracx.driveit://auth/callback` olarak XML düzeyinde doğrulandı. SHA-256 `d9cb27a06c5564ddcbc543698f70dacb66f15c05e7193b590d35762b87caf798`; upload sertifikası SHA-256 `9833ce68f6e38356f2690287ff04962ca55d4dec082c1e3d0100409485325ad3`. Play App Signing dağıtım sertifikası ayrıca doğrulanmadı. AAB cihaza veya Play Console'a yüklenmedi.

## Veri ve callback sınırı

Android farklı applicationId'lere ayrı uygulama veri alanı verir. Yeni Play paketi `com.osaracx.driveit`, eski `com.example.driveit_project` sürüşlerinin Hive/SQLite dosyalarını kendiliğinden devralmaz. Eski uygulamayı kaldırmadan iki uygulama yan yana bulunabilir; eski sürüş aktarımı ayrı bir güvenli aktarım ve cihaz kabulü gerektirir.

Play callback hedefi `com.osaracx.driveit://auth/callback`; eski geliştirme paketinin hedefi `com.example.driveit-project://auth/callback` olarak kodda ve Gradle placeholder'ında eşleştirilmiştir. Play AAB manifest filtresi doğrulandı. PROD Auth config salt okunur isteği HTTP 401 döndürdü; hosted allowlist ve signup durumu bu çalışmada doğrulanamadı veya değiştirilmedi.

R1 Play guard'ı Supabase URL ve publishable key dart-define değerlerini reddeder. Bu AAB Supabase yapılandırması olmadan üretildi; Auth ve kişisel bulut bu derlemede etkin değildir. Manifest eşleşmesi çalışan hosted Auth uçtan uca kabulü anlamına gelmez.

## Bekleyen kabul

1. Yeni AAB'nin package/version/target SDK/manifest callback ve upload sertifikası doğrulandı. Play App Signing dağıtım sertifikası ve gerçek cihazda çalışması ayrıca doğrulanmalı.
2. A55 kurulu paket ve imzası doğrulandı; geçmişin görüntülendiği kullanıcı tarafından bildirildi. Özel Hive/SQLite dosyaları okunmadı; root veya veri çıkarma varsayılmadı.
3. PROD Auth Redirect URL allowlist'inde exact `com.osaracx.driveit://auth/callback` kaydının salt okunur teyidi.
4. Gerçek cihazda yan yana kurulum ve geçmişin korunması kabulü; kullanıcı onayı olmadan A55'e yükleme, güncelleme veya kaldırma yapılmaz.

Bu eksikler tamamlanmadan Play AAB, cihaz veri koruması veya hosted callback için PASS verilmez.
