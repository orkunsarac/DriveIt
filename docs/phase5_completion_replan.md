# Aşama 5 — Mimari yeniden değerlendirme ve bitiş planı

> **11 Ekim 2026 kapsam güncellemesi:** Kullanıcının Teslimat 1 kararı aşağıdaki tarihsel denetimdeki geniş eski-veri arşivi/aktarım önerisinin yerine geçer. Zorunlu arşiv yalnız kaydedilmiş sürüş, GPS geometrisi, tarih, süre, mesafe, hız ve temel detayları kapsar. Eski World/Career/poster/profil/outbox birleştirmesi veya arşiv ekranları zorunlu değildir; kaynak dosyalar silinmez. Yeni sürüş kuralları değişmez. Güncel kabul ve eksik cihaz doğrulaması için `driveit_requirements.md` G.2/G.10 ve `phase5_drive_archive_delivery.md` esas alınır. Aşağıdaki geniş arşiv/merge önkoşulları yeni teslimatın engeli olarak kullanılmamalıdır; tarihsel bulgular korunmuştur.

Tarih: 11 Ekim 2026. Denetim: kaynak kod, çağrı zincirleri, test tanımları ve mevcut teknik raporlar. Bu belge bir uygulama/aktivasyon kararı değildir.

## A. Denetim sınırı ve mevcut durum matrisi

Branch `feature/gps-refactor`, yerel HEAD `f68445cb7038e50b95f0da139fc7b7b307267105`. Önceki geliştirmeler çalışma ağacında korunuyor. Başlangıçta 27 tracked dosyada değişiklik, önceki untracked altyapı/rapor/test dosyaları ve `android/build/` vardı; bunlar bu denetimde değiştirilmedi. `tatus` okunmadı ve değiştirilmedi. Uzak HEAD bu tur ağ üzerinden yeniden doğrulanmadı.

`LocalOwnershipGate.production` sabit kapalıdır. `synthetic()` release/profile derlemede reddedilir. Gate kapalı üretim yolu hesap izolasyonu sağlamıyor; eski ortak depoları kullanmayı sürdürüyor. Bu, kapalı altyapının hatası değil, henüz devreye alınmamış olmasıdır. Gate açık aşağıdaki değerlendirmeler **açık bağımlılıklarla kurulmuş debug/sentetik harness** içindir; üretim kabulü değildir.

Durumların anlamı: TAMAM = belirtilen dar bileşen uygulanmış; KISMEN = çalışan bileşen var ama bütünleşik uçtan uca yol eksik; EKSİK = gerekli bağlantı/özellik yok; BLOKE = kanıt veya ürün kararı olmadan güvenle ilerlenemez. Host başarısı native kabul yerine geçmez.

| Sistem | Gate kapalı gerçek yol | Kontrollü gate açık yol | Somut eksik / karar |
|---|---|---|---|
| Owner namespace/repository sınırı | Ortak Hive; hesap izolasyonu aktif değil | **TAMAM, depo çekirdeği:** guest/account/legacy ayrı dizin, identity marker, detached read, owner kontrolü [K5] | Uygulamanın tamamının bu depolardan çalışması ayrı iş |
| Auth / owner lifecycle | SDK Auth ve cloud profil gözlemi; yerel depolar değişmez | **KISMEN:** UUID adapter, epoch/lease iptali, store drain/close, identity bariyeri var [K3–K4] | Normal bootstrap/root navigasyon bağlantısı yok; scoped profilde gerçek hesap eylemleri ve onboarding zinciri tamamlanmalı |
| GPS start / foreground | Doğrudan journal session; normal callback | **KISMEN:** sidecar önce hazırlanır, aynı session yaratılır, descriptor ve source UUID strict doğrulanır [K6–K8] | Descriptor/attach test-only; yeni handoff'un son native koşusu yapılmadı; kişisel router `/drive` içermiyor |
| GPS recovery / stop / save UI | Aşama 1–4 ortak recovery/summmary akışı | **KISMEN:** aynı binding ile resume ve sabit hedef aktarım primitive'leri var | Harici Auth sonrası bloklu view'den güvenli kurtarma; recovery/summary/post-save navigasyonun lease zinciri eksik [K9–K10] |
| SQLite → Hive | Ortak `GpsHiveTransferSink`; source UUID garantisi yok | **TAMAM, dar transfer sözleşmesi:** manifest hedefi, telemetry/provenance read-back, journal+sidecar receipts, cleanup kanıtı [K7–K8] | Bu primitive tam sürüş tamamlama pipeline'ı değildir: scoped save skor/World/Career hazırlamadan döner |
| Sürüşlerim / detay / Score | Mevcut ortak kayıtlar ve persisted skorlar | **KISMEN:** authoritative ID lookup, lease/epoch, scoped detail/replay/export/score tüketimi var [K2–K3] | Yeni scoped sürüşün skorunu üreten pipeline ve tüm başlangıç/nested yolların root entegrasyonu eksik |
| Benim Dünyam | Global runtime, kaynaklar ve mevcut generation | **KISMEN:** scoped map/detail/index/source/jobs/rebuild/tombstone erişimi var; scoped repository global source fallback yapmaz [K11] | Yeni scoped save→source→validation/job→generation zinciri otomatik değil. Legacy iki kaynak kümesinin merge/remap'i yok |
| Kariyer | Mevcut katkı/baseline ve eski toplam tüketimi | **KISMEN:** owner alanı ve proven `source:<UUID>` append-only kayıtları var [K12] | Görünür statistics yalnız `drive:` satırlarını ve ready baseline'ı okuyor; yeni proven katkılar görünür toplama bağlı değil. History silme de `drive:<id>` kanıtını bekliyor |
| Poster | Mevcut ortak metadata/dosyalar | **KISMEN:** scoped center/editor/saved/picker staging ve strict canonical path koruması uygulanmış [K13] | Normal drive-summary sonrası poster teklifinde hâlâ ortak `getDrive`/lease'siz teklif var. Verified import listesi ayrı read-only destek; genel birleşik görünüm değil |
| Profil | Ortak yerel profil + ayrı SDK kimliği | **KISMEN:** lease üzerinden yerel profil/tercihler var | Onboarding/ready ekranları ve kontrollü root/gerçek Auth UI tamamlanmamış; server profilinin UUID kanıtı yerel legacy sahipliğini kanıtlamaz |
| Planet personal outbox | Ortak mevcut preview/outbox; parçalı backend kapalı | **KISMEN:** scoped telemetry/source, sabit owner outbox ve disabled gateway var | Root/normal save kaynak bağlantıları ve legacy belirsiz outbox politikası gerekli; ortak kabul edilmiş Planet içerik ayrı kalmalı |
| Legacy envanter/kopyalama/claim | Kendiliğinden çalışmaz | **TAMAM, dar copy-proof katmanı:** streaming/hash/capacity, fixed claim, verified partition [K14] | `completed` hesap ekranı görünürlüğü değildir. Eksik/content URI dosyalar fail-closed; bütün gerçek eski veri çeşitleri kabul edilmiş değil |
| Legacy tam World/Career birleşimi | Yok | **BLOKE:** source bundle optional provenance taşıyor ama trace/job/tombstone zinciri local ID tabanlı [K11–K12] | Tam remap/ref closure, gerçek staging/verifier, cumulative Career ürün kararı yok |
| Owner revision / visibility | Çağrılmıyor | **KISMEN:** SQLite revision rows, expected-base CAS, pointer+receipt transaction, retry API var [K15] | Concrete production domain verifier yok; ekranlar `visibleRecords` okumuyor. Immutable revision sonrası yeni yazım/silme protokolü de uçtan uca bağlı değil |
| Eski veriye ayrı güvenli erişim | Ortak uygulamadan mevcut erişim var | **EKSİK:** eski depoları hesaplardan ayrı gösteren tam read-only arşiv gezinmesi yok | Strateji A'nın etkinleştirilmesi için zorunlu; yalnız dosyaları saklamak erişilebilirlik değildir |

### Gerçek çağrı zincirleri

1. **Üretim:** `main → LocalOwnershipBootstrap.run(production) → _legacyBootstrap → ortak Hive kutuları → global World migration/recovery → ForegroundService.init/isDriveActive → Supabase initialize → cloud identity sync → HomeScreen`. Normal açılışta owner depoları, claim ledger veya revision görünürlüğü kurulmaz [K1]. Buradaki mevcut World index migration'ı Aşama 5 legacy ownership importu değildir; bütün migration'ların yok olduğu iddia edilmemelidir.
2. **Kontrollü bootstrap:** `restoreAuth → UUID doğrulama → descriptor journal/sidecar → LocalOwnerLifecycle.start → scoped store → test Auth/foreground attach`. Auth restore başarısızsa kişisel depo açılmaz. `main` bu bağımlılıkları vermiyor; yalnız gate değerini değiştirmek `Controlled owner dependencies missing` ile durur. Release'de test attach/root mekanizmaları ayrıca reddedilir [K4, K6].
3. **Kontrollü GPS:** `ForegroundService.start → LocalOwnerGpsBridge.start → owner operasyon bariyeri → OwnedGpsSessionCoordinator → sidecar prepared(owner, plannedSession, sourceUUID) → journal.create(same ID) → bind → persist handoff → native start → ownedStartCallback → DriveTaskHandler verifySessionOwner → writer restore/GPS`. Isolate Auth okumaz. Headless doğrulama sabit tuple'ı kontrol eder; kalıcı sidecar'da epoch yoktur, RAM epoch eşitliği restart kanıtı değildir [K6–K8].
4. **Save ayrımı:** `DriveSummaryDialog → DriveStorageService._saveDrive`. Controlled transfer takılıysa fixed scoped sink'e aktarır ve **erken return** eder. Ortak yoldaki `DriveScorePersistenceCoordinator`, `prepareSource`, Career katkısı ve `MyWorldRuntime.enqueueSavedDrive/drain` bu return'den sonra kalır. Scoped sink yalnız drive/telemetry/provenance ve transfer kanıtını yazıyor. Yeni scoped sürüş için skor, bağımsız World ve görünür Career tamamlanmış değildir [K8–K12].
5. **Kişisel ekranlar:** `OwnerPersonalNavigator → LocalOwnerNavigator → epoch boundary → lease-bound ekran`. Kayıtlı rotalar home/history/career/profile/world/world-trace/detail/posters. `/drive` ve legacy consent/arşiv rotası yok. ID lookup live scoped Hive'dan gelir; revision pointer okuması değil [K2–K3].
6. **Legacy:** `consent(UUID, epoch, fingerprint) → owner operasyonu + writer drain → inventory → kalıcı claim → ayrı workspace copy/hash/relations → completed → openVerified`. Revision işlemi ayrı API'dir. `OwnerRevisionRepository.prepareVerifyPublish` required evidence istiyor fakat gerçek doğrulayıcı yerine yalnız testte `_DomainVerifier` bulunuyor. `visibleRecords` çağrıları uygulama ekranlarında yok; read API ile uygulamada görünürlük aynı şey değil [K14–K15].

### Somut entegrasyon riski: harici Auth sırasında kurtarma

`LocalOwnerLifecycle._transition` aktif/kurtarılabilir A session'ı varken B context'ini `blocked` yapıyor. `authorizeIdentityChange` herhangi bir unfinished session'da sign-in/out eylemini reddediyor. Transfer ise current lease gerektiriyor. Dolayısıyla bu parçaları doğrudan UI'a bağlamak, B'ye veri sızdırmadan A'ya dönüş/kayıt tamamlama yolu sunmayan bir kurtarma kilidi yaratabilir. Bu tur üretimde gözlenmiş hata iddiası değildir; mevcut kontrollü sözleşmeler arasındaki somut eksik bağlantıdır. Sabit sahibine yeniden doğrulanmış dönüş ya da kişisel veriyi açmadan sabit hedefe güvenli finalization sözleşmesi ve testi zorunludur. Genel logout yasağını kaldırmak çözüm değildir.

## B. Başlangıçta kaçırılan mimari bağımlılıklar

1. **Depo izolasyonu, domain birleştirme ve görünürlük üç ayrı iş.** Owner klasörü eski veriyi sahiplenmez; claim completion domain merge değildir; SQLite pointer da Hive/UI consumer'larını otomatik değiştirmez.
2. **GPS transfer receipt ile tam sürüş finalization aynı değil.** Controlled erken return ortak yan etkileri doğru biçimde engelliyor, fakat karşılığında scoped score/source/contribution/job orchestration gerekli.
3. **`drive.id`, session ID, proven source UUID ve arşiv fingerprint'i ayrı kimlikler.** Yeni kontrollü session ID UUID olduğundan tek owner alanındaki yeni kayıtlar için geniş legacy collision remap'i zorunlu değil. Çok kaynaklı importta aynı local ID çakışması ve tombstone referans closure'ı zorunlu.
4. **Career yeni proven kayıtları için okuma/silme kanıtları eski key'lere bağlı.** `source:` yazma mevcut; görünür statistics, score attachment ve History deletion'ın kalan `drive:` kabulleri birlikte kapanmalı.
5. **Yeni World kaynakları için proven metadata tüketimi ile eski iki World'ü birleştirmek farklı teslimatlar.** Mevcut scoped algoritma kullanılabilir; legacy trace/road/job/tombstone remap'i çekirdek A/B izolasyonundan ayrı tutulabilir.
6. **Eski veriye erişim bir teslimat.** Arşiv diskte durduğu halde yeni hesabın listesi boşsa veri korunmuş olabilir ama ürünün erişilebilirlik şartı sağlanmaz. UI filtresi veya ortak depoya fallback uygun değil.
7. **Mutable live owner store + immutable import revision ilişkisi karara bağlanmalı.** Import pointer'ından okuma açıldıktan sonra yeni sürüş, isim/poster düzenleme, silme ve tombstone hangi version'a yazılacak? Mevcut `put/remove` live Hive'a, revision read SQLite payload'a gider. Bu çözülmeden tam birleşim sonrası güncellik garantisi yok.
8. **Test attach protokolü üretim bootstrap değildir.** Debug/test root, release guard ve headless callback bağımlılıkları yeniden kullanılacak ama sırf gate flip ile rollout yapılamaz.
9. **Yerel owner namespace şifreleme veya cihazlar arası yetkilendirme değildir.** Owner'ı bilinmeyen eski verinin asıl kişisini geriye dönük kanıtlayamayız. Yeni bulut/lease/merge garantileri sonraki fazların işidir.

## C. Strateji A / B karşılaştırması

| Boyut | A — yeni owner verisi + ayrı erişilebilir eski arşiv | B — izolasyon + tüm legacy tam birleşim |
|---|---|---|
| Veri kaybı riski | Kaynakları salt-okunur koruyup alanları ayırır; hesap merge'i ertelenir. Arşiv hazırlığı yine copy/flush/read-back ister | Çok domain/dosya/remap/rebuild/aggregate staging; eksik tek kanıt görünürlük commit'ini engeller |
| Kullanıcı deneyimi | Yeni hesap ve eski cihaz arşivi iki açık alan; tek toplam/tek World değildir | Başarılı birleşimden sonra tek görünüm; belirsiz Career/dosya/provenance tüm importu bloke edebilir |
| Eski sürüş erişimi | **Bugün hazır değil.** Aşağıdaki arşiv teslimatı olmadan önerilemez | Mevcut verified partitions tek başına erişim sağlamaz; tüm domain facade'ları gerekir |
| World/Career bağımsızlığı | Eski generation ve tarihsel Career aynen ayrı okunur; yeni owner defteri bağımsızdır | Kaynaklar+tombstone closure ve gerçek World rebuild; kanıtlı Career exactly-once merge gerekir |
| Mevcut kodla uygulanabilirlik | Scoped live store/lifecycle/GPS/ekranlar çoğunlukla yeniden kullanılabilir. Read-only legacy arşiv eksik | Revision primitive'leri hazır; domain motorları, verifiers ve revision-aware writable/read facade eksik |
| Yeni geliştirme | Eski arşiv erişimi; scoped finalization/Career; gerçek bootstrap/GPS/UI bağlama; native kabul | A'nın çekirdek işleri + provenance remap, tüm domain staging/verifier, conflict UX, cumulative ürün kararı, immutable revision sonrası yazma |
| Test kapsamı | Alan ayrımı, tüm eski ekran/dosya read-only erişimi, yeni drive uçtan uca, A/B/guest, native headless | Buna ek tüm archive/owner kombinasyonları, remap closure, tombstone, aggregate, collision, revision publish/read/write ve fault matrisi |
| Teknik borç | Arşiv deposu ayrı kalır; future import kaynağı korunur. Açıkça takip edilirse geri dönüşsüz borç değil | Birleşik mimari maliyeti şimdi ödenir; belirsiz legacy provenance yine kendiliğinden çözülemez |
| Tahmini karmaşıklık | Orta-yüksek; bounded core teslimatı. Takvim tahmini için gerçek native/hacim ölçümü gerekli | Çok yüksek; ürün kararına ve eski veri kanıtına bağımlı, yalnız mühendislik süresiyle kapatılamaz |

### A için zorunlu ve somut eski veri erişim yolu

Öneri, **hesap ekranına overlay yapmak değil**, ürünün misafir kullanımında ayrı seçilen **“Bu cihazdaki eski kayıtlar”** read-only alanıdır. İç namespace `legacy_unassigned` kalır; yeni `guest` kayıtlarıyla birleşmez. Şartname G.2'nin misafir erişimi ile sonraki teknik sözleşmenin ayrı legacy namespace'i böyle birlikte korunabilir. Bu arayüz henüz uygulanmış değildir.

- Mevcut eski Hive/dosyalar kaynak olarak yerinde kalır. Tam envanter ve kalıcı hazırlık kanıtı olmadan legacy → account kopyası, relabel veya silme yok.
- Tercih edilen okuma kaynağı, kaynak writer'lar quiesced iken hazırlanmış, close/reopen/hash ile doğrulanmış ayrı legacy arşiv kopyasıdır; sadece repository API'sinde read-only görünmesi, kaynak Hive'ın açılış/maintenance sırasında hiç yazmadığını kanıtlamaz. `LegacyOwnerPreparation` mevcut copy-only temel olarak kullanılabilir ama manifest'inin `activationAllowed=false` olması, dosyaları kapsamaması ve bütün payload'ları bellekte tutması nedeniyle tek başına arşiv erişim izni değildir. Asset envanteri/copy kanıtı ve read-only capability ayrıca tamamlanmalı; hiçbir embedded owner alanı account diye değiştirilmemeli.
- Arşiv yalnız açık yerel/misafir alanı seçimiyle açılır; hesap A/B home/history/career/world/poster listelerine otomatik dahil edilmez. Account oturumu kapanınca eski account lease/navigator/cache iptal edilir; arşiv kendi salt-okunur capability ve ekran zincirini alır. Üretim global widget'ları capability vermeden yeniden kullanmak yeterli değildir.
- History/detail/score/telemetry/poster read-only görünür; Career eski kaydedilmiş toplam/baseline olarak aynen gösterilir, yeni hesap toplamına eklenmez. World eski pointer/snapshot ve gerekli road/source referanslarıyla okunur; merge/rebuild/pending worker başlatılmaz. History silinmiş fakat World/Career kaynağı duruyorsa bu bağımsız kayıtlar korunur.
- Poster PNG, seçilmiş arka plan ve `mapImagePath` gerçek erişimle çözülür. Eksik dosya kayıt gizleme/başarılı import yerine açık unavailable durumu olur. Kaynak dosya değiştirilmez. İleride importer aynı orijinal namespace/fingerprint üzerinden çalışır; arşiv kopyası yeni bir sahiplenilebilir kaynak diye tanınmaz.
- Legacy outbox salt okunur eski durum kanıtıdır; başka account adına retry/send açılamaz. Kabul edilmiş ortak Planet yayınları değişmez.
- Aktif/belirsiz eski GPS session varsa archive hazırlığı ve ownership aktivasyonu ertelenir; mevcut güvenli recovery korunur. Session'a yeni proven owner/source kimliği uydurulmaz.
- Arşiv depoları writable owner repository olarak açılmaz; silme/isim değiştirme/dosya save/job admission yolları read-only repository sınırında reddedilir. Ayrı gezinme bir koşulsuz iki-kaynak union değildir.

**Mahremiyet sınırı / açık karar:** Eski kaydın gerçek hesap sahibi bilinmiyorsa B'nin fiziksel cihaz erişiminden kayıt sahibini teknik olarak çıkaramayız. Önerilen erişim hesabın yetkisi değil, mevcut yerel misafir/cihaz erişimidir; account B'ye otomatik kişisel erişim sağlamaz. Kullanıcının istediği “farklı kişi bu cihazın misafir arşivini de göremesin” ise yerel arşiv erişim politikası/koruması ayrıca kararlaştırılmalıdır. Bu kararın verilmiş olduğu varsayılmaz. Şartname G.2 ve ayrı legacy alanının kullanıcıya sunumu onaylanmadan production activation bloke kalır.

**Öneri:** A'yı kısa güvenli **çekirdek izolasyon teslimatı** olarak seçmek; eski arşiv erişimini ilk ve vazgeçilmez kabul koşulu yapmak. A bugün hazır değildir. Tam onaylı legacy birleşimini ertelemek, özgün Faz 5'in onaylı taşıma gereksinimini kaldırmaz: kapsam değişikliği onaylanmazsa A yalnız ara teslimat olur, Aşama 5'in bütünü “tamamlandı” denemez. B bu şartı aynı teslimatta kapatmayı hedefler ama bugün belirtilen provenance/ürün kararları nedeniyle bloke.

## D. Tek bağımlılık sırası ve en kısa güvenli bitiş planı

Sıra: **eski arşiv erişim sözleşmesi ve uygulaması → yeni scoped sürüşün tam finalization/bağımsız domain tüketimi → bütünleşik bootstrap/Auth/GPS/kişisel navigasyon → native kabul ve rollout kararı**. Mevcut primitive'ler yeniden yazılmayacak. Legacy multi-source merge bu sıranın önkoşulu yapılmayacak; ayrı bloke backlog olarak kalacak.

### Teslimat 1 — Eski veriye read-only, ayrı ve eksiksiz erişim

- Somut çıktı: yerel misafir içinde explicit legacy arşiv; History/detail/Score, eski Career, eski World ve poster dosyaları açılır. Account ekranları arşivi enumerate edemez.
- Önkoşul: G.2/legacy namespace sunumu ve yerel erişim kararı; envanter; unfinished GPS varsa stop/activation değil güvenli erteleme.
- Yeniden kullanılacak: typed Hive adapter, `LegacyOwnerPreparation` copy-only sınırı, legacy inventory/asset resolver, `LocalOwnerBoundary`, authoritative ID/detail servisleri. Eksik: files dahil reopen-verified archive hazırlığı, read-only archive capability/repositories, root/route ve tüm nested ekranlara geçiş. Bunlar yeni bileşenlerdir; mevcut `VerifiedLegacyImport` account claim gerektirdiğinden doğrudan unclaimed archive facade değildir. Scoped writable repository'nin embedded `ownerScope` kontrolü de eski `unassigned` bundle'ı kendiliğinden legacy görünümüne dönüştürmez.
- Değişecek yollar: ileride kontrollü navigasyon, read-only veri/dosya sağlayıcıları ve sentetik arşiv fixtures. Değişmeyecek: kaynak Hive/SQLite/SharedPreferences, Career hesapları, World geometri/pointer, claim/visibility anlamı ve normal gate-OFF davranışı.
- Kabul: eski ve yeni aynı ID; archive→A→B→archive; History silinmiş World/Career kaynakları; eski field-254 fixture; poster/background/mapImage erişimi; eksik asset açıklaması; bütün box/dosya hash'leri okuma öncesi/sonrası aynı; hesap UI'dan doğrudan arşiv ID lookup reddi; read-only mutasyon reddi.
- Başarı/durma: eski dört veri grubundan biri erişilemez veya account görünümüne sızarsa sonraki activation işi başlamaz. Yalnız byte-copy başarı raporu yeterli değildir.

### Teslimat 2 — Bir yeni scoped sürüşün bütün kişisel çıktıları

- Somut çıktı: fake A/guest ile start→native descriptor→resume→stop→save→read-back→Score/N/A→independent World source/job→Career→poster teklifinin tek owner'da çalışması. A→B external event kaynak sahibini değiştirmez; recover/save için güvenli kullanıcı yolu vardır.
- Önkoşul: mevcut immutable session owner/source UUID, dual receipt ve store sınırları; bir legacy remap motoru gerekmez.
- Değişecek yollar: `DriveStorageService` controlled finalization, scoped Score load/save adapter'ı (mevcut calculator), `ScopedLocalRepositories`, Career visible source-key tüketimi/deletion proof, source preparation/job orchestration, summary/recovery/post-save lease navigasyonu. Aynı owner operasi̇yon bariyerinde nested `run` deadlock yaratmadan orkestre edilmeli.
- Değişmeyecek: GPS journal v3, hız/ivme filtreleri, score v1 formülleri/yeterlilik, worldRulesVersion=6/ownership/offset, eski `drive:`/countedIds/baseline kayıtları; legacy birleşim veya toplu trace remap yok.
- Kimlik şartı: yeni source UUID→local drive/road/section/trace/job/tombstone ilişkisi typed resolver veya geriye uyumlu metadata ile izlenebilir. Aynı provenance conflict fail-closed; mevcut local anahtarlar algoritma değiştirerek remap edilmez. Tam **çoklu arşiv** remap bu teslimat değildir.
- Kabul: yeni boş owner Career baseline'ı ve source contribution görünürlüğü; duplicate save ile tek katkı; secondary score hata/retry; History silme World/Career'ı azaltmaz; World silme History/Career'ı azaltmaz; source UUID restart/owner dönüşünde aynı; A/B aynı ID; fixed-owner recovery; her durable sınırda injected failure. Hive primary receipt ile secondary finalization completion ayrı durable durumlar olmalı; primary journal erken temizlenmemeli.
- Başarı/durma: yeni save sonrası Career saymama/çift sayma, World source eksikliği, ortak Hive/dosya fallback veya blocked recovery kilidi kalırsa teslimat tamam değildir.

### Teslimat 3 — Uygulama kökünde bütünleşik owner erişimi

- Somut çıktı: kontrollü app bootstrap/root, gerçek SDK event adapter'ının fake stream kabulü, tüm kişisel/nested rotalar ve GPS bildirim dönüşünün aynı owner context'i kullanması. Misafir/legacy/account ayrı ve açık.
- Önkoşul: teslimat 1 ve 2; store-open hata politikası; eksiksiz tüketici/yazıcı envanteri.
- Değişecek yollar: `LocalOwnershipBootstrap`, `SupabaseAccountService` adapter seam'i, `OwnerPersonalNavigator` `/drive`/recovery ve profile/onboarding/auth rotaları, foreground descriptor provisioning. Test-only attach/root güvenliği kaldırılmadan production-capable explicit composition tasarlanmalı; aktivasyon bu teslimatın başarı varsayımı değildir.
- Değişmeyecek: gate-OFF legacy sırası, kaynak veriler, Supabase backend, gerçek segment gateway ve import visibility. Ekranlar live scoped store'u okur; deferred revision'ın kısmi payload'ına bağlanmaz.
- Kabul: guest→A→logout→B→A; Future/Stream/map/controller/picker sonuçları epoch'ta iptal; authoritative ID lookup; aktif session'da kullanıcı hesap değişimi engeli; dış Auth sonrası sabit sahibi koruyan recovery; açılmayan store'da fail-closed; bildirim/deep/nested route shared ekran bypass taraması; release gate kapalı ve test define ile açılamıyor.
- Başarı/durma: tek tüketicinin global profile/drive/world/poster/outbox fallback'i bile kalırsa activation adayı değil. Guard/helper testleri tam uygulama senaryosunun yerine geçmez.

### Teslimat 4 — İzole native uçtan uca kabul ve kapanış kararı

- Somut çıktı: sabit kaynak sürümünde host + izole A55 sonuçları; upgrade/read-only arşiv/sqflite/headless/save/dosya güvenliği kanıtı; kapalı gate release regresyonu; rollback/backup sınırları ve açık release kararı.
- Önkoşul: 1–3 tamam; native test APK applicationId ve gerçek backend izolasyonu doğrulanmış; fiziksel cihaz bağlı. Sonradan kod değişirse ilgili native kabul yeniden yapılır.
- Değişecek: yalnız gerekiyorsa test/harness/kanıt belgeleri. Yeni feature veya legacy merge bu kabul teslimatına eklenmez. Asıl A55 paketine kurulum ancak ayrı kullanıcı yetkisi ve backup/aktif-session önkontrolüyle yapılabilir; burada izole test yeterli gerçek veri kabulü değildir.
- Kabul: aşağıdaki F/G test matrisi; uzun GPS kayıt, service recreation, paused UI, permission failure, dual receipt, actual sqflite reopen; native map/poster/path alias ve hesabın dönüşü. OS process kill/power loss ayrı raporlanır.
- Başarı/durma: native foreground/SQLite/dosya erişimi çalıştırılamadıysa core üretime hazır denmez. Veri kaybı, cross-owner leak, eski verinin erişilememesi veya restore kilidi varsa gate kapalı kalır.
- Kapanış: A'nın yeni-owner izolasyon teslimatı kapanabilir. Tam legacy birleşim gereksinimi ve kapsam onayı yoksa bütün Faz 5 kapanmaz. Gate açılması otomatik test komutu sonucu değil, ayrıca açık rollout kararıdır.

### Kalan işlerin bağlantı/test haritası

| İş | Mevcut temel | Eksik tam bağlantı | Önkoşul / kanıt | Yeniden yazım? |
|---|---|---|---|---|
| Read-only legacy erişimi | Inventory, typed adapters, asset resolver | Unclaimed archive facade ve ayrı bütün ekran zinciri | Mahremiyet/sunum kararı; hash/read-only/ID izolasyon testleri | Yeni bounded adapter; importer/World motoru yeniden yazılmaz |
| Yeni scoped finalization | Scoped sink + dual receipts | Score/source/Career/jobs durable completion, summary sonrası owner route | Provenance read-back; duplicate/fault/delete tests | Mevcut calculator/repositories kullanılır |
| Proven Career görünürlüğü | `source:` writer | Visible aggregate, score attachment ve deletion proof aynı source identity'yi tüketmeli | Exactly-once/legacy baseline ayrımı | Formül değil identity tüketimi değişir |
| Yeni World identity | Bundle optional provenance + scoped rebuild | Yeni kaydın refs/job/tombstone→source UUID zinciri ve post-save hazırlığı | Ref closure/History bağımsızlığı | Mevcut planner aynen; legacy bulk remap yok |
| Auth/GPS root entegrasyonu | Lifecycle/bootstrap/handoff | Supported root composition, tüm route entry'leri, fixed-owner blocked recovery | 1–2; fake SDK + native isolate test | Yeni paralel Auth sistemi yok |
| Native handoff kabulü | Güncellenmiş probe | Güncel Android koşusu ve gerçek callback/harness zinciri | İzole APK, backend guard | Probe sonucu gerçek production handler sonucu diye gösterilmez |
| Legacy World/Career tam merge | Revision + provenance temel | Multi-source deterministic remap, staging rebuild/aggregate ve gerçek domain verifier | Unproven/tombstone/cumulative kararları | Algoritma korunur; merge adapter'ı yeni iş |
| Tam revision görünürlüğü | CAS/transaction/read API | Tüm-domain verifiers, read facade, normal yeni yazım/silme ve stale-base protokolü | Domain merge + fixed assets | UI filtre değil ortak facade gerektirir |

Son iki satırın sırası: ürün conflict/cumulative kararı → typed provenance/ref remap → gerçek World/Career staging → History/Score/Poster/Profile/Planet domain verifiers → immutable revision sonrası normal yazma/silme sözleşmesi → bütün consumer facade/restart kabulü → açık consent ile publish. Bunlar çekirdek A/B depolama izolasyonunun değil, **tam legacy birleşimin** bağımlılıklarıdır.

## E. Ertelenebilecek işler ve ertelenemeyecek şartlar

**Ertelenebilir (ayrı arşiv teslimatı ve kapsam onayıyla):** iki World generation'ının birleşik rebuild'i; eski provenance remap'i; cumulative-only Career'ın account toplamıyla birleştirilmesi; bütün legacy domain'lerin tek revision'a publish edilmesi; profile/outbox legacy conflict çözüm UX'i. Bunlar sessizce atlanmaz: arşivde kaynak değerler korunur, transfer bekliyor/belirsiz açıklanır, account aggregate'a karıştırılmaz. Import ledger/revision çekirdeği korunur; disable edilip silinmez. Future import kaynak namespace'i/kopya ilişkisi muhafaza edilir.

**Ertelenemez:** eski verinin kullanılabilir ayrı erişimi; yeni session owner/source sabitleme; scoped save ve durable recovery; görünür yeni Career'ın doğru exactly-once hesabı; World/Career bağımsız silme; poster dosya owner sınırı; A/B epoch/async/nested route izolasyonu; belirsiz owner/store hatasında fail-closed; native kabul; source veriyi koruyan aktivasyon/rollback sınırı.

Gerçek cloud upload/download, otomatik özel backup, server lease ve çoklu cihaz merge, gerçek parçalı Planet backend, Grup Sürüşü bu planın dışında ve şartnamedeki sonraki fazlarda kalır. Yerel izolasyon bunları tamamlamış sayılmaz.

## F. Zorunlu veri güvenliği ve test stratejisi

1. **Host Flutter:** source sabitken tek runner; `flutter test --timeout=2m`, hedefli lifecycle/ownership/scoped transfer/provenance/World/Career/poster/import/revision paketleri; `flutter analyze`, `git diff --check`. Test sonuçları teslimat bazlı kaydedilmeli.
2. **Owner A/B/guest/legacy:** aynı ID, A→B→A stale Future/Stream, direct route, cache/controller/picker, repository and file denial; guest ile legacy namespace ayrımı; account'larda arşiv otomatik açılmaz. B ekranı A'nın diskte korunmuş verisini okuyamaz.
3. **GPS foreground/recovery:** owner/source UUID/sequence continuity; Auth race; sidecar prepare→journal create→bind→descriptor→native start hata sınırları; service stop/continue; current-user reread olmadan transfer; eksik sidecar; blocked-owner recovery; duplicate save; iki receipt ve hedef read-back olmadan cleanup yok.
4. **Veri bütünlüğü:** gerçek source payload'ını taklit eden sentetik binary fixture, count/hash/relations; SQLite v3 korunur; sidecar v1/v2→v3 additive; claim ledger v1→v2 korunur; Hive field 254 ve eski DateTime field ID rezervi; copy/flush/close/reopen; primary save ile secondary domain retry ayrı; disk dolması/eksik dosya/conflict source'u değiştirmez.
5. **Eski gerçek veri koruması:** testler gerçek veride migration/kill/bozma yapmaz. İleride rollout öncesi güvenli backup erişilebilirliği gerçek Android signing/debuggable sınırlamalarıyla değerlendirilmeli; tam yedek alınamadıysa bu risk bildirilir. Yeni sidecar/scoped verileri sonrası eski APK'ya downgrade güvenli varsayılmaz. Kaynaklar ancak ayrı onaylı politika ile silinebilir, bu plan silmez.
6. **Merge defer güvenliği:** `completed` claim hiçbir account ekranını kendiliğinden açmaz; fake verifier production'a kurulmaz; unproven kaynak global UUID almaz; career totals parçalanmaz; tombstone local-ID benzerliğiyle başka kaynağı silmez; kabul edilmiş Planet içeriğe dokunulmaz.
7. **Writer quiescence:** history/GPS sink/telemetry/score/Career/source/index/jobs/lifecycle/poster/profile/settings/outbox kaynak kategorileri mevcut fence kapsamındadır. Registration bildirimi bütün gelecekteki doğrudan dosya/Box writer'larını otomatik kanıtlamaz. Registry/path coverage eksik, native GPS busy veya poisoned drain varsa import yok. Bu yerel fence process'ler arası global kilit değildir.

### Bu denetimde test kanıtı

Yeni runtime kodu yazılmadığı için bu tur tam Flutter veya native test çalıştırılmadı. Son raporlanan kaynak doğrulaması **844 geçti / 2 koşullu atlandı / 0 başarısız**, analyze **4 mevcut info**. Bu denetim bu sayıları yeniden üretilmiş sonuç olarak sunmaz.

İki skip kaynakta doğrulandı: `isolated_android_backend_guard_test` izolasyon define'ı olmayan hostta; `owner_world_poster_boundary_test` Windows synthetic symlink oluşturma kısıtında. Bu kontroller native/uygun platform kabulüne taşınmalı; 2 skip = 2 başarılı test değildir.

Yeni handoff native testi son raporda bağlı cihaz olmadığı için çalıştırılmamış. Önceki A55 poster/owner başarıları yeni descriptor/provenance versiyonunun native kabulünü kapsamaz. `OwnedNativeProbe` gerçek headless engine/MethodChannel'da sentetik noktalar üreten probe'dur; test edilen descriptor doğrulaması, gerçek GPS hareketi veya bütün `DriveTaskHandler` lifecycle'ı ile eşdeğer değildir. Test definition inspection, test execution değildir.

## G. Fiziksel Android kabul gereklilikleri

- Yalnız `com.example.driveit_project.isolated_test`, fake Auth/sentetik depolar, gerçek Supabase initialization kill switch. A55 gerçek `com.example.driveit_project` paketi değiştirilmez/stop/uninstall edilmez; izinler yalnız test paketine.
- Her build/install öncesi APK applicationId doğrulanır. Seri runner; `--no-uninstall`, `--dart-define=DRIVEIT_ISOLATED_ANDROID_TEST=true`; DEV/PROD config test komutuna verilmez [K16].
- Mevcut ilgili testler: `owned_foreground_bootstrap_android_test`, `owner_world_poster_android_test`, `owner_personal_screen_android_test`, `owner_scoped_storage_android_test`, `gps_ownership_android_test`, `gps_android_test`, `independent_lifecycle_android_test`, `hive_legacy_startup_test`, `legacy_account_import_android_test`. Bunlara delivery 1–3'ün uçtan uca app/root/recovery/finalization fixture'ları eklenmeli.
- Native sqflite/schema reopen + two-service handoff + dual receipt; Android canonical sandbox alias ve escaping symlink reddi; picker/poster owner change; actual map controller dispose; old Hive detail/poster; new scoped Career/source/job generation; backend request oluşmaması.
- Ekran kilidi/background, permission/service denial, service recreation ve mümkünse **izole** app process ölümünde owner/source/GPS zinciri ayrıca test edilir. Controlled exception, service stop/start ve OS process kill ayrı sonuçlardır. Power-loss kabulü ayrı sınıftır; fiziksel hareket/uzun GPS gap testleri sentetik sabit cihaz testi diye geçilmiş sayılmaz.
- `ServiceRequestFailure` altta yatan native neden logu yoksa çözülmüş denmez. `unsafe_symlink` düzeltmesinin owner dışına çıkış korumasını native tekrar doğrulamalı. Gerçek kullanıcı migration acceptance başka açık yetki gerektirir.

## H. Açık kararlar ve riskler

1. Eski alanın şartname G.2'deki misafir erişimi ile ayrı `legacy_unassigned` namespace'inin sunumu: önerilen explicit read-only arşiv ve mahremiyet sınırı onaylanmalı. Bu denetim ürün kuralını değiştirmedi.
2. A'nın core milestone'ı ile Faz 5'in bütün onaylı-transfer gereksiniminin kapanışı ayrı mı olacak? Legacy merge ertelenecekse kapsam onayı gerekli; aksi halde Faz 5 bütün olarak açık kalır.
3. Cumulative-only Career kaynaklarında kanıtlanmamış örtüşme nasıl çözülecek? Ayrı tarihsel değer gösterimi arşiv erişimini sağlar ama **account merge** için çözüm değildir. Kaynak toplamın otomatik toplama/sıfırlama/sentetik contribution'a parçalanması yok.
4. Unproven aynı-ID/source tombstone/asset/profil/outbox conflict kararları yok; fail-closed kalır. Archive fingerprint'i gerçek sürüş eşdeğerliğinin kanıtı değildir.
5. Immutable import revision ile yeni live owner yazımları için authoritative read/write model kararı ve implementation eksik. Eski pointer'ı sabitleyip yeni Hive kayıtlarını görünmez bırakmak uygun değil.
6. SQLite sidecar+journal+plugin task data+Hive+dosyalar ortak transaction değil. Read-back/intents/receipts/retry güvenliği var; tam power-loss/fsync garantisi yok.
7. Çoklu Hive box işlemlerinin transaction atomikliği ve World generation pointer flush rollback sınırı devam ediyor. Yeni scoped namespace bu riski ortadan kaldırmaz.
8. Kaynak copy descriptor'ları O(kayıt+asset) büyüyor, Hive açık kutu RAM'i de var. Streaming dosya kopyası tüm uygulamanın bounded RAM'i olduğunu kanıtlamaz; gerçekçi sentetik hacim ve native ölçüm gerekir.
9. Android backup/debug/signing, `content://` grant, eksik cache/user asset ve app-private path taşıma gerçek erişimle kanıtlanmalı. Erişilemeyen asset başarılı aktarım diye işaretlenmez.
10. Son native handoff koşusu eksik. Üretim gate'i kapalı olduğundan yeni-owner izolasyonu gerçek A55 kullanıcı sürüşlerinde bugün kanıtlanmış değil.

## Son dört cevap

1. **Temel hesap izolasyonu legacy tam birleşim olmadan tamamlanabilir mi?** Evet, yeni owner kayıtları ve ayrı erişilebilir legacy arşiv teslimatıyla. Bugün hazır değil. Onaylı legacy birleşimi özgün Faz 5 gereksinimi olarak açık kalır; kapsam onayı olmadan Faz 5'in bütünü tamamlandı denemez.
2. **Mevcut veriler nasıl korunur/erişilir?** Kaynak Hive/SQLite/dosyalar yerinde ve sahiplenilmeden korunur; hesap listelerine karıştırılmayan, explicit misafir/cihaz legacy arşivinde mevcut History/World/Career/poster değerleri salt-okunur açılır. Bu facade henüz eksik; gate açılmadan önce teslim edilir. Sonraki onaylı importer aynı orijinal kaynağı kullanır.
3. **Sıradaki en doğru tek geliştirme?** Teslimat 1: bütün eski kişisel verileri account görünümünden ayırarak erişilebilir tutan read-only legacy arşiv facade'ı ve tam navigasyonu; önce erişim/mahremiyet kararını netleştir. Yeni World/Career merge motoruna tekrar başlamadan bu aktivasyon önkoşulunu kapat.
4. **Hangi işler birleştirilmemeli?** Yeni sürüşün owner-scoped finalization'ı ile legacy multi-source merge; namespace izolasyonu ile source eşdeğerliği; veri kopya completion ile visibility publish; read-only eski Career gösterimi ile cumulative account merge; host/helper kabulü ile native/power-loss kabulü; yerel izolasyon ile cloud backup/lease/sync. Her birinin ayrı kabul sınırı olmalı.

## Kod kanıtları

Aşağıdaki linkler bu denetimde incelenen çalışma kopyasını gösterir. Önceki raporlarda artık eski olan “henüz yok” notları, yukarıdaki gerçek kaynak değerlendirmesiyle ayrılmıştır.

- K1: [main ve gerçek bootstrap](C:/Users/PC/Documents/DriveIt/lib/main.dart:31), [merkezi gate](C:/Users/PC/Documents/DriveIt/lib/config/local_ownership_gate.dart:3).
- K2: [kişisel route envanteri](C:/Users/PC/Documents/DriveIt/lib/widgets/owner_personal_navigator.dart:25), [epoch içindeki Navigator](C:/Users/PC/Documents/DriveIt/lib/widgets/local_owner_navigator.dart:24), [home /drive çağrısı](C:/Users/PC/Documents/DriveIt/lib/screens/home_screen.dart:598).
- K3: [lease/repository erişimi](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_lifecycle.dart:50), [Auth geçişi ve GPS block](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_lifecycle.dart:591), [identity action guard](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_lifecycle.dart:702).
- K4: [SDK UUID event adapter](C:/Users/PC/Documents/DriveIt/lib/services/supabase_local_owner_auth.dart:6), [Auth test attach/identity seam](C:/Users/PC/Documents/DriveIt/lib/services/supabase_account_service.dart:130), [kontrollü bootstrap](C:/Users/PC/Documents/DriveIt/lib/services/local_ownership_bootstrap.dart:69).
- K5: [scoped depolar/groups](C:/Users/PC/Documents/DriveIt/lib/services/owner_scoped_local_store.dart:40), [owner ve detached read sınırı](C:/Users/PC/Documents/DriveIt/lib/services/owner_scoped_local_store.dart:155).
- K6: [foreground callback/attach](C:/Users/PC/Documents/DriveIt/lib/services/foreground_service.dart:15), [start/protocol ayrımı](C:/Users/PC/Documents/DriveIt/lib/services/foreground_service.dart:107), [strict descriptor](C:/Users/PC/Documents/DriveIt/lib/services/owned_foreground_bootstrap.dart:28).
- K7: [owner GPS operasyonu](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_gps_bridge.dart:46), [sidecar→journal coordinator](C:/Users/PC/Documents/DriveIt/lib/services/owned_gps_session_coordinator.dart:29), [sidecar v3](C:/Users/PC/Documents/DriveIt/lib/services/gps_session_ownership.dart:86).
- K8: [scoped transfer read/write/proof](C:/Users/PC/Documents/DriveIt/lib/services/scoped_gps_transfer_sink.dart:13), [provenance reader](C:/Users/PC/Documents/DriveIt/lib/services/drive_source_provenance_repository.dart:16).
- K9: [save erken dönüş ve ortak yan etkiler](C:/Users/PC/Documents/DriveIt/lib/services/drive_storage_service.dart:49), [mevcut ortak Score coordinator](C:/Users/PC/Documents/DriveIt/lib/features/drive_score/services/drive_score_persistence_coordinator.dart:20).
- K10: [summary save sonrası ortak lookup/poster](C:/Users/PC/Documents/DriveIt/lib/widgets/drive_summary_dialog.dart:170), [recovery injectable fakat owner'sız varsayılanlar](C:/Users/PC/Documents/DriveIt/lib/screens/drive_recovery_screen.dart:9).
- K11: [scoped World repository](C:/Users/PC/Documents/DriveIt/lib/features/my_world/repositories/hive_my_world_repository.dart:17), [source payload/key](C:/Users/PC/Documents/DriveIt/lib/features/my_world/repositories/world_source_snapshot_repository.dart:18), [trace referansları](C:/Users/PC/Documents/DriveIt/lib/features/my_world/models/active_world_trace.dart:5), [job kimliği](C:/Users/PC/Documents/DriveIt/lib/features/my_world/models/world_pending_job.dart:14), [tombstone filtreleri](C:/Users/PC/Documents/DriveIt/lib/services/local_lifecycle_journal.dart:18), [controlled job drain](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_lifecycle.dart:389).
- K12: [Career source/drive key ayrımı](C:/Users/PC/Documents/DriveIt/lib/services/career_contribution_repository.dart:38), [proven katkı listesi ve eski statistics tüketimi](C:/Users/PC/Documents/DriveIt/lib/services/career_contribution_repository.dart:287), [scoped Career ve bağımsız silme](C:/Users/PC/Documents/DriveIt/lib/services/owner_scoped_local_store.dart:462).
- K13: [poster strict canonical resolver](C:/Users/PC/Documents/DriveIt/lib/features/drive_poster/poster_store.dart:184), [scoped editor](C:/Users/PC/Documents/DriveIt/lib/features/drive_poster/poster_screens.dart:319), [ayrı verified legacy poster listesi](C:/Users/PC/Documents/DriveIt/lib/features/drive_poster/poster_screens.dart:1364).
- K14: [lossless kaynak envanteri](C:/Users/PC/Documents/DriveIt/lib/services/legacy_import_inventory.dart:55), [importer](C:/Users/PC/Documents/DriveIt/lib/services/legacy_account_import.dart:19), [claim ledger](C:/Users/PC/Documents/DriveIt/lib/services/legacy_claim_ledger.dart:119), [writer fence](C:/Users/PC/Documents/DriveIt/lib/services/local_source_writer_fence.dart:14), [consent bridge](C:/Users/PC/Documents/DriveIt/lib/services/local_owner_import_bridge.dart:18), [asset streaming](C:/Users/PC/Documents/DriveIt/lib/services/legacy_asset_transfer.dart:73), [World bundle mapImagePath ayrımı](C:/Users/PC/Documents/DriveIt/lib/services/local_source_bundle.dart:28).
- K14a: [mevcut copy-only legacy hazırlığı ve activation yasağı](C:/Users/PC/Documents/DriveIt/lib/services/legacy_owner_preparation.dart:58).
- K15: [verifier interface / revision prepare](C:/Users/PC/Documents/DriveIt/lib/services/owner_revision_repository.dart:17), [required evidence](C:/Users/PC/Documents/DriveIt/lib/services/owner_revision_repository.dart:447), [pointer-only visible API](C:/Users/PC/Documents/DriveIt/lib/services/owner_revision_repository.dart:676), [yalnız sentetik verifier](C:/Users/PC/Documents/DriveIt/test/owner_revision_repository_test.dart:24).
- K16: [izole Android komutları ve sınırlar](C:/Users/PC/Documents/DriveIt/docs/android_isolated_integration_tests.md), [backend kill switch](C:/Users/PC/Documents/DriveIt/lib/config/supabase_bootstrap.dart:24), [headless probe kapsamı](C:/Users/PC/Documents/DriveIt/integration_test/owned_foreground_bootstrap_android_test.dart:15), [son test/native raporu](C:/Users/PC/Documents/DriveIt/docs/foreground_owner_handoff_5c2g2c2.md).

İncelenen belgeler: şartname, GPS ownership contract, local owner storage/lifecycle/integration/bootstrap/personal-screen/World-poster/World-chain raporları; legacy import 5C.1; import visibility/revision/World-Career merge incelemesi; provenance foundation/end-to-end GPS/foreground handoff; izole Android test sözleşmesi. Bu denetimde yalnız bu yeni plan belgesi oluşturuldu; runtime, gate, branch ve kullanıcı verileri değiştirilmedi.
