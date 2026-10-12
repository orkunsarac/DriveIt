# Owner runtime Android kabulü — 12 Ekim 2026

## Kapsam ve güvenlik

Branch `feature/gps-refactor`, checkpoint `638c58a720a3c5d14c214227a3c6603891f516df`. Önceki runtime değişiklikleri korundu. Bu tur yalnız iki native kabul testi ve bu belge değiştirildi; runtime algoritması, journal v3 ve production gate değiştirilmedi.

A55 SM-A556E / API 36 / `R5CX42V8GSJ` authorized. Her hedef APK build sonrası aapt ile `com.example.driveit_project.isolated_test` olarak doğrulandı. Runner `--no-uninstall` ve isolated define kullandı. Backend guard logda Supabase'in kapalı olduğunu bildirdi; fake Auth, sentetik GPS ve test-owned sandbox kullanıldı. Gerçek konum enjekte edilmedi.

Asıl `com.example.driveit_project` paketinin APK yolu, versionCode 1 ve lastUpdateTime `2026-10-12 01:48:53` başlangıç/son kontrolde aynı kaldı. Asıl pakette install, force-stop, uninstall, clear, izin değişikliği veya veri okuma yapılmadı. Bu metadata kontrolü kullanıcı dosyalarının hash denetimi değildir; gerçek veriler okunmadı.

## Değiştirilen testler

- `integration_test/owned_drive_ui_android_test.dart`: eski bağımsız navigator harness yerine gerçek `startDriveIt → DriveItApp` bootstrap; guest/A/B, MapScreen start/stop/save, native foreground isolate, sqflite journal, scoped Hive, History/detail/score, World worker, Career ve lazy archive zinciri.
- `integration_test/owned_drive_process_kill_android_test.dart`: aynı gerçek bootstrap/recovery navigasyonu, bağımsız sentetik fixture namespace, harici Auth ve handoff uyuşmazlığı kontrolleri, native drain.

## Android sonuçları

1. Runtime UI: **1/1 geçti**, exit 0. Guest açık seçim, 16 örnekte doğru N/A; A'nın 301 noktalı 6 km sürüşü History/Score/Career'a kaydedildi. A→B→A→guest izolasyonu ve save retry exactly-once doğrulandı.
2. World non-blocking: matcher Completer ile beklerken save/receipt/journal finalization tamamlandı; History rota/detail erişilebilir, World henüz başarı olarak gösterilmedi. Retryable hatada durable pending kaldı; runtime/store close-reopen sonrası korundu. Retry bir World generation/trace üretti. İkinci sürüş permanent World reddinde de History ve Career korundu; generation değişmedi.
3. Recovery hazırlığı: kalıcı 16 nokta ve source UUID doğrulandı, harici A→B Auth değişiminde sahibi A kaldı. Eksik binding ve çelişkili descriptor reddedildi. `PHASE5_PROCESS_KILL_READY` sonrası yalnız isolated PID 27526 Android `cmd activity crash` ile kapatıldı. Android olay kaydı `CrashedByAdbException / shell-induced crash` ve süreç ölümünü doğruladı. Hazırlık runner exit 1 normal geçti sayılmadı; beklenen bağlantı kaybına ek Windows geçici listener cleanup `PathNotFoundException` saklandı.
4. Ayrı recovery process: **1/1 geçti**, exit 0. Aynı fixture açıldı; session/source UUID ve 16 satır korundu. Gerçek `/drive` recovery ekranı, Continue/MapScreen ve güvenli native drain/stop kontrol edildi. Sentetik fixture sonrasında yalnız kendi test dizini temizlendi. Gerçek power-loss testi değildir.

Arşiv gerçek root üzerinden list→detail→GPS map zincirinde açıldı, sentetik legacy Hive dosya bytes öncesi/sonrası aynıydı. Bu tur device-auth sağlayıcısı fake idi; gerçek PIN/biometri penceresi yeniden kabul edilmedi. Maps platformu fake olduğundan fiziksel Google Maps rendering/hareket kabulü değildir. Gerçek Android foreground service ve sqflite MethodChannel kullanıldı, GPS örnekleri sentetikti.

## Loglar

`build/owner_runtime_a55_ui.log`, `build/owner_runtime_crash_prepare.log`, `build/owner_runtime_crash_recover.log`, ilgili build logları ve `build/owner_runtime_acceptance_full.log`. İlk test-only compile denemesindeki `GpsSession.status` yerine gerçek `.state` kullanıldı; başarısız build logu korundu. Log/build çıktıları commit edilmedi.

## Host regresyonu

- Tam `flutter test --timeout=2m --no-pub`: **897 geçti, 2 koşullu atlandı, 0 başarısız**, exit 0, 2 dakika 28 saniye. Atlamalar Windows symlink oluşturma koşulu ve isolated Android define gerektiren backend guard'dır; başarı sayılmadı.
- İlk analyze: native UI testte kullanılmayan import warning'i ve mevcut 4 info. Yalnız kullanılmayan import kaldırıldı; tam paket sonrası davranış değişikliği yok.
- Nihai `flutter analyze --no-pub`: yalnız mevcut **4 info**, warning/error yok; info nedeniyle exit 1, 13.6 saniye.
- `git diff --check`: exit 0. Satır sonu LF→CRLF uyarıları whitespace başarısızlığı değildir.

## Aktivasyon kararı

**KISMEN:** kontrollü runtime native kabulü başarılıdır; production aktivasyonu verilmedi. `main → startDriveIt` varsayılanı production OFF; synthetic gate yalnız debug'da açılır. Release kaynak composition seçimi, debug-only descriptor/attachment güvenlik sınırları ve gerçek cihaz-auth ile yeni kökün uçtan uca kabulü ayrıca değerlendirilmelidir. Gerçek GPS hareketi ve power-loss kabulü bu turun kapsamı değildir. Yalnız gate değerini değiştirmek yeterli değildir.

Commit/push, Supabase işlemi, gerçek legacy import veya asıl APK kurulumu yapılmadı. `tatus` ve `android/build/` korunmuştur.
