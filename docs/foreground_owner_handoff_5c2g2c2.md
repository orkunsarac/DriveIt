# Foreground GPS Owner Handoff — Phase 5C.2G.2C.2

## Sonuç özeti

Kontrollü, debug-only owner-scoped GPS başlangıcında foreground task'a artık yalnızca depo kökü değil, sidecar ile eşleştirilen sabit session/owner/source kimliği de devrediliyor. Production ownership gate kapalı kaldı; normal üretim GPS başlangıcı ve ortak Hive yolu bu değişiklikle etkinleştirilmedi. Android headless-engine testi güncellendi, fakat bu çalışma turunda ADB bağlı cihaz göstermediği için fiziksel native test çalıştırılmadı.

## A) Bu aşamada değiştirilen dosyalar

- `lib/services/owned_foreground_bootstrap.dart`
- `lib/services/foreground_service.dart`
- `test/local_owner_bootstrap_writer_test.dart`
- `integration_test/owned_foreground_bootstrap_android_test.dart`
- `docs/foreground_owner_handoff_5c2g2c2.md`

Çalışma alanında bunların dışında önceki Aşama 5'e ait değişiklikler de bulunuyor; korunmuştur. Untracked `tatus` dosyasına dokunulmamıştır.

## B) Gate kapalı/açık başlangıç davranışı

- `LocalOwnershipGate.production` disabled olarak kalır. `ForegroundService.attachForTesting` yalnız debug modda, etkin sentetik gate ve doğrulanmış sentetik test kökü ile çalışır.
- Gate kapalı normal `ForegroundService.start()` yolu mevcut `journal.create()` ve `startCallback()` akışını kullanmaya devam eder. Ortak Hive transfer yolu veya legacy kayıtlar bu aşamada değiştirilmedi.
- Kontrollü bridge bağlıyken aynı public `ForegroundService.start()` owner-scoped `LocalOwnerGpsBridge.start()` yoluna gider; bridge yoksa gate açıkmış gibi owner tahmini/fallback yapılmaz.
- Kontrollü bootstrap Auth restore tamamlanmadan journal/owner deposunu açmaz. Guest ancak test Auth açıkça `null` kullanıcı kimliği döndürdüğünde guest scope olarak seçilir. `legacy_unassigned` yeni session sahibi olamaz.

## C) Owner/session/provenance handoff

`OwnedForegroundBootstrap.forSession()` yalnız ready sidecar manifest'inden şu alanları alarak handoff oluşturur: `journalId`, `sessionId`, `reservationId`, owner türü ve UUID'si, `targetStore`, proven source UUID, source identity version/namespace ve UI owner epoch. Session, manifest veya provenance eksik/çelişkiliyse descriptor üretimi reddedilir.

Descriptor FlutterForegroundTask kalıcı verisine kaydedilir ve kaydetme sonucu `false` ise native servis çağrılmaz. `_startNative()` çağrısından hemen önce owner lease tekrar doğrulanır. Böylece sidecar/journal yazımından sonra handoff kalıcılığı veya lifecycle doğrulaması başarısız olsa dahi GPS kaydı silinmez; mevcut session recovery için kalır.

Owner epoch descriptor'da handoff anının kanıt/izleme alanıdır. Kalıcı sidecar v3 epoch saklamadığı için foreground isolate bu sayıyı yeni process'in RAM epoch'u ile karşılaştırmaz. İlk servis başlangıcında lease doğrulanır; recovery'de güncel lifecycle lease'i owner scope ile eşleştirilir. Değişmez güvenlik bağı session + reservation + owner + target + source identity tuple'ıdır.

## D) Foreground isolate doğrulaması

`ownedStartCallback` yalnız kalıcı task descriptor'ını okur; Auth veya global aktif kullanıcıyı okumaz. `DriveTaskHandler` aktif journal session'ını yükledikten ve GPS stream'e abone olmadan önce `verifyHandoff()` çağrılır. Bu kontrol descriptor'daki session/reservation/owner/target/source UUID/version/namespace değerlerini sidecar'ın ready kaydıyla ve journal içindeki session varlığıyla karşılaştırır. Herhangi bir uyuşmazlıkta GPS aboneliği başlamadan hata verir; session/journal korunur.

Eski veya eksik sidecar ile oluşturulmuş legacy session, strict handoff descriptor'ı oluşturamaz ve callback tarafından proven kabul edilmez. Generic bootstrap doğrulaması strict native callback'in yerine geçmez.

## E) Resume/recovery güvenliği ve crash pencereleri

1. Sidecar reservation, önceden seçilmiş session UUID ve source UUID ile kalıcılaştırılır.
2. Journal aynı session UUID ile oluşturulur.
3. Sidecar, journal session'ı kanıtlayınca ready olarak bind edilir. Aradaki kapanma mevcut planned-session recovery mekanizmasıyla tamamlanır; ilgisiz session benimsenmez.
4. Tam handoff descriptor kalıcı task verisine yazılır; başarılı yazımdan sonra Android servisi başlatılır.
5. Native servis/isolate yeniden oluştuğunda aynı descriptor ve aynı journal/sidecar kanıtını doğrular.

Servis başlangıcı başarısız olursa ikinci `start()` aktif/recoverable session nedeniyle yeni session/source UUID üretmez. `resumeRecording()` mevcut binding'den aynı kimliklerle descriptor'ı yeniden yazar ve tekrar başlatmayı dener. Stop/continue ve iki headless service döngüsü testinde session ve source UUID sabit tutulur; sequence zinciri mevcut journal'da devam eder.

Sidecar prepare, journal create, sidecar bind, Flutter task-data kaydı ve Android service start ayrı kalıcı sistemlerdir; tek transaction değildir. Her kapanma penceresinde fail-closed kalmak ve eski GPS noktalarını korumak tasarlanmıştır; gerçek cihaz power-loss garantisi bu testlerle kanıtlanmış sayılmaz.

## F) Başlangıç bypass kontrolü

İncelenen uygulama giriş noktaları:

- Yeni sürüş UI: `MapScreen` → `ForegroundService.start()`.
- UI/recovery geri dönüşü: `MapScreen` restore → `ForegroundService.resumeRecording()`.
- Headless servis yeniden yaratılması: FlutterForegroundTask saklı callback; gate kapalıda `startCallback`, kontrollü attached test bridge'de `ownedStartCallback`.
- Kaydet/durdur: aynı journal session ID; owner-scoped test transferi bridge binding'ini kullanır, yeni kimlik üretmez.

Test, public `ForegroundService.start()` çağrısının handoff'ı servis çağrısından önce sakladığını ve platform `startService` isteğinde `ownedStartCallback` handle'ının seçildiğini kontrol eder. Ayrı native probe aynı formatlı descriptor'ı Android headless engine'de çözüp sidecar ile doğrular. Gerçek üretim uygulamasının gate'i açılmamış ve üretim callback'i owner-scoped akışa geçirilmemiştir.

## G) Test sonuçları

- `test/local_owner_bootstrap_writer_test.dart`: **25/25 geçti**. Gate kapalı bootstrap, Auth restore başarısızlığı, guest seçimi, A→B değişimi, eksik/çelişkili handoff, native-start hatasında aynı binding'in korunması, public service start callback/descriptor, ve resume kimlik devamlılığı kapsandı.
- `test/gps_session_ownership_test.dart`, `test/drive_source_provenance_test.dart`, `test/local_owner_integration_test.dart`: **43/43 geçti**. Planned sidecar/journal recovery ve sahiplik/kimlik devamlılığı dahil.
- `flutter test --timeout=2m`: **844 geçti, 2 koşullu atlandı; başarısız test yok**.
- `flutter analyze`: yeni analiz bulgusu yok; önceki dört `info` kaldı (`home_screen.dart`, `map_screen.dart` iki kayıt, `route_preview.dart`). Analyzer info seviyesinde 4 bulgu bildirdi.
- `git diff --check`: başarılı. Git'in mevcut fsmonitor IPC ve CRLF uyarıları içerik whitespace hatası değildir.
- ADB: ADB 1.0.41 yanıt verdi, ancak `adb devices -l` boş liste döndürdü. Samsung A55/native isolated test bu nedenle çalıştırılmadı; APK kurulmadı ve gerçek DriveIt paketi/verileri hedeflenmedi.

Güncellenen native test `integration_test/owned_foreground_bootstrap_android_test.dart` iki headless service turunda session, owner ve source identity doğrulayıp sentetik sequence devamını kontrol eder. Bu testin Android'de çalıştırıldığı iddia edilmemektedir.

## H) Kalan GPS→Hive bağlantıları

Bu çalışma mevcut test-only owner bridge / scoped transfer sözleşmesini kullanır; normal üretim GPS→Hive transfer rotasını yeni owner-scoped sisteme etkinleştirmez. GPS journal v3 veya ownership sidecar v3 şeması değiştirilmedi. Gerçek kullanıcı verilerindeki eski Hive sürüşleri proven hale getirilmedi. Üretim GPS→Hive owner handoff ve fiziksel Android task recreation kabulü sonraki açık kapsam olarak kalır.

## I) Açık riskler

- A55 bağlı olmadığı için Android MethodChannel/sqflite gerçek foreground callback testi doğrulanamadı.
- Android proses ölümü/power-loss testi yapılmadı; test kodundaki ikinci servis döngüsü bunu temsil etmez.
- Sidecar, journal, plugin task-data ve Android servis başlangıcı arasında ortak atomik transaction yoktur. Handoff yazımı başarısızsa servis başlamaz ve session kurtarılabilir kalır; bu davranış sentetik test edildi.
- `ownerEpoch` kalıcı sidecar v3'te saklanmadığından restart sonrasında epoch eşitliği değil, sabit owner/session/source kanıtı doğrulanır.
- Gate kapalı gerçek üretim akışında GPS→Hive ve ekran davranışı bu aşamada değiştirilmemiştir.

## J) Aşama kararı

**Aşama 5C.2G.2C.2: KISMEN.** Kontrollü owner-scoped başlangıç, descriptor handoff, isolate-side strict doğrulama ve host regresyonları tamamlandı. İstenen gerçek Android foreground service/recreation doğrulaması ADB cihazı bağlı olmadığı için eksik. Üretim gate kapalıdır; bu aşama üretim owner-scoped GPS aktivasyonu veya gerçek A55 kabulü olarak değerlendirilmemelidir.
