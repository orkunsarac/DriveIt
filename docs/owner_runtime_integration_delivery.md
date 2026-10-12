# Owner runtime uygulama bağlantısı teslimatı

12 Ekim 2026. Branch `feature/gps-refactor`; HEAD `638c58a720a3c5d14c214227a3c6603891f516df`. Önceki `docs/driveit_next_phase_audit.md`, `tatus` ve `android/build/` korundu. Üretim ownership gate KAPALI.

## A. Değiştirilen dosyalar

Uygulama:
- `lib/main.dart`: ortak açılış girişi, kontrollü owner uygulama kökü, guest onayı, recovery rotası, arşiv yükleyicisi ve lifecycle/notification bağlantıları.
- `lib/services/supabase_local_owner_auth.dart`: SDK initialize/restore başarısını zorunlu tutan Auth restore bağımlılığı.
- `lib/services/local_owner_lifecycle.dart`: kaydetmeden ayrı, sabit owner'a bağlı World worker planlaması ve güvenli pending hata durumu.
- `lib/services/owned_drive_finalization.dart`: World ağ doğrulaması yerine kalıcı iş kuyruğu; core finalization/read-back ve Career korunur.
- `lib/widgets/local_owner_navigator.dart`, `lib/widgets/owner_personal_navigator.dart`: başlangıç recovery rotası, epoch'a özel navigator anahtarı ve arşiv yükleyicisi.
- `lib/screens/history_screen.dart`: owner doğrulamalı lazy arşiv erişimi ve tekrarlanan açılış isteği bariyeri.

Testler:
- `test/owned_drive_delivery_test.dart`: uygulamanın ortak girişinden UI/service/storage/UI, restore/guest/arşiv/recovery/World retry testleri.
- `integration_test/owned_drive_finalization_android_test.dart`, `integration_test/owned_drive_ui_android_test.dart`: World sonucuna ilişkin assertion öncesinde bağımsız worker tamamlanmasını bekleme. Bu tur cihazda çalıştırılmadılar.
- Bu rapor.

Yeni owner, storage, import veya GPS mimarisi kurulmadı; mevcut bileşenler birleştirildi. Pubspec, Hive adapter'ları, GPS journal v3 ve sidecar şeması değiştirilmedi.

## B. Gerçek bootstrap / Auth bağlantısı

`main() → startDriveIt()` artık tek uygulama açılış girişidir. Varsayılan gate `LocalOwnershipGate.production` olduğu için normal APK aynı `_legacyBootstrap` yolunu kullanır.

Gate açık kontrollü çağrıda sıra:

1. Tam bağımlılık sözleşmesini doğrula: Auth restore, descriptor, native factory, scoped store, foreground attach/detach, writer fence, saved-drive archive kaynağı ve eski unfinished GPS sorgusu.
2. Auth restore'u bekle; hata halinde kişisel depo açma, guest'e dönüştürme.
3. Null session varsa açık guest onayı iste. Gerçek seçim ekranı mevcut `DriveItAccountSection` giriş/kayıt arayüzünü yeniden kullanır. Onaydan sonra güncel immutable UUID tekrar doğrulanır.
4. Eski sahipsiz GPS recovery varsa owner aktivasyonunu reddet. Journal'a kimlik atama veya temizleme yapma.
5. Mevcut `LocalOwnershipBootstrap` ile owner lifecycle, scoped store ve foreground attachment'ı hazırla. Verilen callback'in bu runtime'a gerçek bridge/descriptor attachment yaptığını `requireOwnerLease` ile doğrula; noop callback'te ortak journal'a recovery sorgusu yapılmadan dur.
6. `DriveItApp(ownerRuntime: ...) → OwnerPersonalNavigator` uygulama kökünü aç. Unfinished session veya pending finalization varsa ilk rota `/drive`.

`SupabaseLocalOwnerAuth.restore()` gerçek SDK initialize/restore bağımlılığı olarak kullanılabilir. Yapılandırma/restore başarısızlığı anonymous session kabul edilmez. SDK UUID/event adapter'ı ve `SupabaseAccountService`'in mevcut login/signup/logout işlevleri korunur; kontrollü bootstrap'ın mevcut identity-operation attachment'ı kullanılır. Testlerde bu bağımlılık fake Auth ile verilir; gerçek SDK/backend çağrısı yapılmaz.

Auth A→B geçişinde mevcut lifecycle epoch'u derhal eski lease'i iptal eder; yeni store hazırlanmadan kişisel navigator açılmaz. Navigator anahtarı epoch'ta yenilenir, eski detail/map/poster route ağacı taşınmaz. Gate açık outer MaterialApp üzerinde ortak onboarding preview rotası da kayıtlı değildir; kişisel yollar ortak Hive ekranlarına düşmez.

## C. Gerçek /drive bağlantısı

Ortak uygulama kökü `/drive → OwnedDriveScreen → MapScreen(ownerLease)` yolunu kullanır. Mevcut `ForegroundService.start → LocalOwnerGpsBridge → sidecar/session/source UUID → owned foreground descriptor` zinciri yeniden kullanılır. Service restart, Continue ve transfer hedefi anlık Auth'tan seçilmez.

Foreground bildiriminin `openDrive` olayı owner navigator'a `/drive` olarak gider. Ortak `DriveRecoveryScreen` owner'sız açılmaz. Uygulama yeniden açıldığında recoverable owner session ve yarım finalization yeni session oluşturmak yerine `/drive` üzerinden açılır.

Harici Auth değişiminde sahibin UUID'si korunur; yanlış hesap görünümü/transferi fail-closed kalır. Kullanıcı kaynaklı hesap değiştirme mevcut unfinished-GPS bariyerinden geçer. Bu teslimat bir hesaba kayıt kurtarmak için başka hesabı yetkili kabul etmez.

## D. SQLite → owner Hive finalization

Mevcut intent, sabit hedef sink, source UUID, drive/telemetry read-back, journal acknowledgement ve sidecar receipt korunur. Score/source snapshot/Career ve World queue durable yazımı core finalization içinde tamamlanır. İki receipt + hedef kanıtı + completed kaydı olmadan History görünürlüğü/cleanup onayı verilmez.

Score/Career veya gerekli kalıcı queue yazımı başarısızsa source journal ve pending finalization korunur; başarılı save gösterilmez. Bu, ağda World doğrulamasının başarısızlığından farklıdır. Kaynağı bırakmadan retry yapabileceğimiz kalıcı iş kanıtı zorunludur.

Yeni `worldQueued` metadata'sı yalnız uygun bir işin kalıcı kuyrukta olduğunu gösterir. World doğrulaması/ownership başarısı anlamına gelmez. `derivedReady` core finalization gereksinimlerinin tamamlanması içindir; World terminal başarı beklentisi artık bu bayrağa bağlı değildir.

## E. Eski sürüş arşivi güvenliği

History'deki açık giriş, aynı uygulama kökünün `deviceArchiveLoader` fonksiyonuna gider:

`current lease → owner operation bariyeri → registered source writer pause/drain → unfinished GPS kontrolü → mevcut SavedDriveArchiveSource → doğrulanmış snapshot → mevcut Android cihaz doğrulaması → archive context → liste/detay/rota`.

Snapshot açılışta zorunlu olarak üretilmez. Böylece aktif owner sürüşünün kurtarılması, arşivin GPS-busy durumuyla kilitlenmez. Arşiv seçildiğinde eski unfinished kayıtlar, owner journal recoverable session'ları ve native producer ayrıca kontrol edilir. GPS start ve Auth değişimi aynı owner operasyonuyla seri olduğundan snapshot sırasında yeni session başlamaz. Source fence her sonuçta resume edilir.

Source ID'leri/geometri/date/metrikler korunur. Sahiplik/provenance uydurulmaz; archive source account History'ye dahil edilmez. Native cihaz authorizer varsayılan olarak aynen kullanılır. Test authorizer yalnız açık bağımlılık olarak fake verilir. Direct ID, epoch ve background capability kuralları değişmez. History'deki ikinci açılış isteği ilk istek tamamlanmadan yeni doğrulama/navigation başlatamaz.

Yeni kök üzerinden sentetik arşiv liste→detay→harita açılışında kaynak `drives.hive` dosyasının önce/sonra byte'ları aynı çıktı. Hesap B'ye geçince açık arşiv route ağacı kaldırıldı. Eski World/Career/poster/profile/outbox kaynaklarına import veya merge yapılmadı.

## F. World / Career ve kaydetme bağımsızlığı

Önceki owned save ağdaki World validation'ı ve generation commit'i bekliyordu. Şimdi:

`verified drive + telemetry + Score + source + exactly-once Career + durable World job → receipts → completed History → ayrı World worker`.

Worker, aynı lease/store kapsamında mevcut v6 job processor/matcher/index motorunu kullanır. World kuralları, minimum 5 km ve Score v1/coverage/N/A değiştirilmez. Kaydetme Future'ı worker'ın ağ sonucunu beklemez. Eksik matcher, network retry veya worker exception completed History'yi geri kapatmaz; job kalır ve `owner_world_retry_pending` durumu kullanıcıya “Benim Dünyam işlemi bekliyor” olarak sunulur.

Worker tetikleri: save completion, owner-ready uygulama kökü ve app resume. Pending finalization varken worker başlatılmaz. Auth geçişinin ready bildirimi içinde worker nested işlem açmaz; geçişten sonra ayrı operasyon sıraya alınır. Eski lease sonucu yeni owner'a uygulanmaz. Exactly-once Career ve World job idempotency anahtarları değişmez.

Mevcut owner işlem/drain bariyeri korunmuştur. Uzun matcher işi başka owner işlemlerinin sıraya alınmasını geciktirebilir; bütün owner eylemlerinin sıfır gecikmeyle paralel çalıştığı iddia edilmez. Mevcut matcher timeout'ları değiştirilmedi. Birden fazla Hive kutusu/SQLite dosyası hâlâ tek transaction değildir; fiziksel power-loss/atomik rollback garantisi eklenmedi.

## G. Guest / A / B

Başlangıçtaki guest seçimi açık onaylıdır. Guest kökünde kayıtların cihazda ayrı kaldığı ve login ile otomatik taşınmadığı yazısı gösterilir. Guest→A→B→A→guest testinde guest sürüşü yalnız guest alanına geri dönünce görünür. Yeni guest→account aktarımı bu teslimatta yoktur.

Yeni A sürüşü yalnız A History/Score/World/Career alanında kalır. Aynı UUID/source receipt kuralları save retry'da kayıt/katkı çoğalmasını engeller. Önceki poster, profile, outbox ve async-owner sınır regresyonları tam pakette korunmuştur.

## H. Testler ve kanıt sınırı

- Hedefli bootstrap/owned-drive/archive paketi: **65 geçti, 0 başarısız**. Son ek World close/reopen ve noop-foreground-attachment testleri ayrıca nihai tam pakette geçti.
- Nihai `flutter test --timeout=2m --no-pub`: **897 geçti, 2 koşullu atlandı, 0 başarısız**, yaklaşık 2 dakika 14 saniye, exit 0.
- Nihai `flutter analyze --no-pub`: **yalnız mevcut 4 info**, error/warning veya yeni bulgu yok; info nedeniyle exit 1. İlk analyze'ın yeni 5 brace-style bulgusu giderildi. `git diff --check`: exit 0.
- Atlamalar mevcut Windows symlink oluşturma koşulu ve isolated-Android define gerektiren backend guard'dır; başarı sayılmadılar.
- Tam UI dikey test, önceki yalnız navigator harness'i yerine `main` ile ortak `startDriveIt → DriveItApp → owner navigator` kökünü açar. Gerçek `/drive`, MapScreen start/stop ve summary save metotları; gerçek SQLite/Hive; History/detail/route, Score, World ve Career doğrulanır. Platform foreground/maps/GPS/Auth host fake'idir; sentetik 301 nokta / 6 km kullanılır.
- Auth restore beklerken store açılmadı; restore hatası veya guest iptalinde owner store açılmadı; eksik composition, noop foreground attachment ve unfinished legacy journal reddedildi.
- World provider Completer ile bekletildiğinde save tamamlandı, History ve receipts hazırdı. Network/worker hatasında pending job ve completed History korundu; ikinci işleme tek Career/World sonucu verdi. Close/reopen sonrası source/telemetry ve pending World işinden yeniden işleme doğrulandı.
- Recovery açılış testinde ortak girişin ürettiği gerçek `DriveItApp` yakalanıp `/drive` konfigürasyonu ve aynı kalıcı source identity doğrulandı. Bu test yeni bir native recovery ekran kabulü olarak sayılmaz; UI/service dikey akış ayrı testtedir.
- İlk yeni widget denemelerinde FFI Future'ın fake-clock/real-async sınırı ve runApp warm-up progress ticker'ı sorunları görüldü; loglar saklandı. Auth bekleme Future'ları aynı `runAsync` alanına alındı. Recovery entry/persistence assertion'ı normal async testte, UI assertion'ları ayrı gerçek root widget testlerinde tutuldu. Animated Home turunda sonsuz settle beklemek yerine owner epoch'unun route ağacını kaldırması doğrudan doğrulandı. Test skip veya timeout artırımı yapılmadı.
- Bu tur **Android native test çalıştırılmadı, APK üretilmedi/kurulmadı**. Önceki izole A55 kabulü tarihsel kanıttır; yeni root/worker değişikliğinin native kabulü değildir. Güncellenen iki native test sadece source/analyze kontrolünden geçti. Sonraki fiziksel kabul yalnız izole package'ta yapılmalı; gerçek DriveIt verisi kullanılmamalı.

Loglar `build/owner_runtime_targeted_success.log`, `build/owner_runtime_full_flutter_final.log`, `build/owner_runtime_analyze_final.log`, `build/owner_runtime_diff_check.log`. İlk başarısız/yarıda durdurulan denemelerin `build/owner_runtime_*` logları da korunmuştur; build çıktıları Git'e eklenmedi.

## I. Gate kapalı üretim uyumluluğu

`main → startDriveIt(default production OFF) → mevcut _legacyBootstrap` aynı ortak Hive/foreground/recovery/World startup/Auth yolunu kullanır. Yeni archive snapshot, guest onayı, scoped transfer veya worker composition kendiliğinden kurulmaz. Mevcut World index sürüm rebuild'i Aşama 5 ownership migration'ı değildir; eski davranış korunur.

Normal main veya release'de yeni davranışı açan dart-define eklenmedi. Synthetic gate/foreground descriptor/attachment'ın mevcut debug/test güvenlik kontrolleri korunmuştur. GPS journal v3, Hive RoutePoint field 254, mevcut source kayıtları ve production Supabase yapılandırması değiştirilmedi. Test root'u gerçek Supabase'i initialize etmez; isolated Android backend guard mevcut hâliyle korunur.

## J. Eksikler / aktivasyon sınırı

Gate-açık **kontrollü** uygulama kökünde istenen bootstrap/navigation/save/arşiv bağlantıları tamamlandı. Gerçek release rollout hâlâ etkin değildir: main'in varsayılanı OFF'tur ve enabled çağrı açıkça tam kontrollü bağımlılıklar gerektirir. Descriptor/attach debug güvenlik sınırını kaldırmadan üretim kaynaklarının seçimi ve native rollout kabulü ayrıca yapılmalıdır. Bu teslimat yalnız gate değerini değiştirmenin yeterli olduğunu iddia etmez.

Gerçek kullanıcı kaynaklarında archive hazırlama, native cihaz doğrulamalı yeni uygulama kökü, canlı GPS hareketi ve fiziksel power-loss bu tur denenmedi. Ortak transaction bulunmaması ve uzun matcher'ın writer bariyerini meşgul etmesi açık sınırlardır. Guest onaylı aktarım, bulut sync ve legacy merge bu teslimatın parçası değildir.

## K. Karar

**Teslimat: EVET — talep edilen gate-açık kontrollü gerçek uygulama girişine entegrasyon kapsamı için.** Üretim gate KAPALI; gerçek kullanıcı aktivasyonu/dağıtım onayı verilmedi. Mevcut kayıtlar veya sunucu verileri üzerinde işlem, APK kurulumu, branch değişimi, stage/commit/push yapılmadı.
