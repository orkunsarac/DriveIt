# P-GR7G — DEV/PROD ve Play veri izolasyonu

## Tamamlanan teknik kontroller

- Yeni uygulama derlemelerinde Play applicationId yalnız `https://arwnbogcswisfesayosy.supabase.co`, DEV applicationId yalnız `https://viqngnjfgknpxtoapzcg.supabase.co` kabul eder. Yanlış protokol, host, port, path, query, fragment veya kimlik bilgisi reddedilir; bilinmeyen applicationId başarısız olur. Isolated Android test define'ı Supabase'i başlangıçtan kapatır. Zaten kurulu A55 binary'si değiştirilmedi; bu guard onu geriye dönük değiştirmez.
- `flutter test` ortam politikası, callback, GPS sahipliği ve hukuki onboarding: **32 geçti / exit 0**. Önceki birleşik koşuda izole define gerektiren backend guard atlandı; sentetik loopback URL ve anahtarla ayrıca çalıştırıldığında **1 geçti / exit 0**. İlk ayrı denemede sentetik URL/anahtar eksik olduğu için test başarısızdı; bu beklenen test önkoşulu sağlanarak tekrarlandı.
- `tool/test_android_backup_policy.ps1`: **PASS / exit 0**. Manifest Auto Backup kapalı; Android 11 ve öncesi ile Android 12+ cloud/device transfer kuralları ilgili veri alanlarını dışlar. Daha önce alınmış yedeklerin silindiği iddia edilmez.
- Önceden üretilmiş P-GR7F AAB manifesti tekrar okundu: package `com.osaracx.driveit`, tek exact Auth callback ve `allowBackup=false`; **exit 0**. Bu AAB yeni DEV/PROD guard kodunu içermez; güncel kodla yeni AAB üretilmedi.
- Değişen Dart dosyalarında `dart analyze`: **No issues found / exit 0**.

## Kalan kabul

Farklı Android applicationId'leri ayrı uygulama sandbox'ları kullanır; eski paket dosyalarının otomatik paylaşılacağına dair bir mekanizma bu değişiklikte eklenmedi. Bununla birlikte yeni Play paketinin temiz cihazda ilk açılışında geçmişin ve istatistiklerin boş olduğu, hiçbir eski yerel veya bulut verisinin aktarılmadığı ve iki uygulamanın yan yana çalıştığı henüz uçtan uca test edilmedi. Cihaz kurulumu için açık kullanıcı onayı gereklidir; bu görevde yükleme, kaldırma veya veri temizleme yapılmadı.

PROD Auth allowlist'i son salt okunur girişimde HTTP 401 nedeniyle doğrulanamadı. Mevcut R1 Play guard'ları Supabase yapılandırmasını ve cloud feature'ları reddeder; dolayısıyla önceki AAB'de Auth ve sync kapalıdır. Grup Sürüşü ve silme worker'ı etkinleştirilmedi. Hukuki `pending_legal_review` koruması sürüyor. Mevcut R1/R1.1 ve ilgisiz çalışma ağacı değişiklikleri checkpoint kapsamına alınmadı.
