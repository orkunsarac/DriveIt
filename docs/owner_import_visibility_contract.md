# DriveIt — Legacy Import Görünürlük ve Birleştirme Sözleşmesi

Durum: **5C.2G.2 repository/ledger çekirdeği sentetik testler için uygulanmıştır; production görünürlüğü ve ekran entegrasyonu uygulanmamıştır**

Kapsam: Aşama 5C.2G.1. Bu belge gerçek importu, production feature gate'ini veya yeni bir hesap deposu davranışını etkinleştirmez.

## A) Mevcut sistemin doğrulanmış envanteri

| Alan | Mevcut bileşen / davranış | Görünürlük açısından anlamı |
|---|---|---|
| Owner ve epoch | `LocalOwnerLifecycle`, `LocalOwnerLease`, `OwnerViewBarrier` | Lease belirli owner scope ve epoch'u temsil eder; stale lease sonuçları reddedilebilir. Tek başına completed import keşfetmez veya importu owner deposuna birleştirmez. |
| Feature gate | `LocalOwnershipGate.production` kapalı; `synthetic()` test amaçlıdır | Normal üretim yolu ortak mevcut depoları kullanmaya devam eder. Bu tasarım gate'i açmayı önermez. |
| Owner depoları | `OwnerScopedLocalStore`, `ScopedLocalRepositories` | Owner başına ayrı, deterministik namespace/box seti ve repository sınırı sağlar. Drives, Career, World, poster/profil metadata ve Planet kişisel outbox gibi gruplar burada tutulabilir. |
| Legacy hazırlama/import | `LegacyAccountImporter`, `LocalOwnerImportBridge`, `LegacyOwnerConsentController` | Kaynağı salt okunur inceleyip verified import workspace/partition'ına kopyalar. Import bridge aktif GPS ve kayıtlı writer fence koşullarını denetler. |
| Claim ledger | `LegacyClaimLedger` | SQLite üzerinde source namespace için kalıcı tekil claim, manifest fingerprint, hedef owner UUID, operation ID, durum ve doğrulama kanıtı tutar. 5C.2G.2, additive ledger schema v2 ile immutable owner revisions, prepared record/asset evidence, per-owner pointer ve `import_visibility` receipt ekler. `completed`, yalnız kopyalama/doğrulamanın tamamlandığını belirtir; görünürlük anlamına gelmez. |
| Doğrulanmış partition | `VerifiedLegacyImport` | `read`, `keys`, `file`, `posterFile`, `isForLease` gibi salt okunur erişim verir; canlı owner store değildir. `openVerified(namespace, lease)` belirli namespace için claim/kanıt/lease kontrollerini yeniden yapar. |
| Kariyer | `CareerContributionRepository`, owner-scoped `career_contributions_v1` ve `career_totals` | Owner alanında idempotent katkı defteri vardır. Eski yalnız-kümülatif toplamın tekil katkı provenance'ı olduğu varsayılamaz. |
| World | `WorldSourceSnapshotRepository`, owner-scoped World index/pointer ve `MyWorldRebuildService` / `WorldIndexMutationPlanner` | Her owner'ın kaynakları ve generation pointer'ı ayrıdır. İki pointer değeri birleştirilmiş snapshot değildir; v6 kuralları ve mevcut ownership algoritmaları korunmalıdır. |
| Poster ve dosyalar | `PosterStore`, `OwnerAssetTransfer`, `legacy_asset_transfer.dart` | Metadata ile dosya referansları ilişkilidir; verified import dosyaları hash/receipt ile okunabilir. `mapImagePath` ve poster dosyaları başarı kanıtı olmadan taşınmış sayılamaz. |
| Tombstone / lifecycle | owner-scoped `local_lifecycle_v1` ve World lifecycle/pending kayıtları | Silme ve pending işaretleri owner kapsamındadır. Merge bunları atlayıp silinmiş içeriği diriltemez. |
| GPS | `gps_session_ownership` sidecar ve SQLite GPS journal v3 | Session'ın başlangıç owner'ı sabittir. Journal v3 bu aşamada değiştirilmez; aktif/belirsiz GPS session legacy importu bloke eder. |
| Planet kişisel outbox | owner-scoped `planet_segment_outbox_v1`, `local_publish_state_v1` | Pending/mock durumlar kişisel ve owner-scoped kalır. Import bunları gerçek kabul edilmiş yayın gibi gösteremez veya tekrar gönderemez. Accepted ortak yayınlar kişisel importun dışında ve değişmezdir. |
| Ekranlar | `OwnerPersonalNavigator` ve owner-scoped History/Detail/Career/Profile/World/Poster akışları | Kontrollü ekranlar tek owner lease'in canlı store'unu okur. Consent paneli production navigasyonuna bağlı değildir; poster ekranlarına verified partition otomatik aktarılmıyor. Bütün kişisel ekranların birleşik import görünümünü okuduğu ortak bir katman mevcut değildir. |

Bu nedenle bugün `ledger.completed → hesap ekranlarında görünür` geçişi **yoktur**. 5C.2G.2'de `completedForOwner` discovery API'si ve `OwnerRevisionRepository` prepare/verify/publish/read API'si eklenmiştir; bunlar yalnız debug synthetic gate ile ve açıkça sağlanan verifier/fence bağımlılıklarıyla çalışır. Henüz production bootstrap veya ekran tüketicilerine bağlanmamıştır. `completed` import partition kopyasının kanıtıdır; yalnız başarılı pointer + visibility transaction'ı revision'ı repository API'sinde görünür kılar.

### 5C.2G.2 implementation boundary (supersedes older “not implemented” notes below)

- `LegacyClaimLedger.open` now opens schema v2 and additively creates revision tables when upgrading v1. Existing claims/receipts are retained; the GPS journal is separate and unchanged.
- `OwnerRevisionRepository` provides a dormant synthetic-test API to capture, prepare, verify, publish, retry, and page records for the active revision. It stores adapter-encoded Hive bytes as opaque payloads in the claim-ledger SQLite database; it does **not** promote data into owner Hive boxes.
- One SQLite transaction marks a revision published, advances the owner pointer with generation CAS, and writes the immutable import visibility receipt. Failure rolls back all three. Retry uses deterministic revision identity and receipt.
- Provenance conflicts, unresolved identity, ambiguous singleton values, owner/claim mismatch, stale base, invalid asset evidence, incomplete groups, closed gate, or writer-drain failure block publication.
- `OwnerRevisionDomainVerifier` and `RegisteredSourceWriterFence` are required injected interfaces. Current tests use synthetic implementations. There is no concrete production verifier proving actual World rebuild, Career merge, profile, poster, or Planet invariants, and no bootstrap/screen/background reader calls this repository.
- `visibleRecords` exposes only the current published revision through this repository API. Since live personal consumers have not been switched to it, no claim is made that staged rows are visible in application screens.

## B) Seçilen mimari ve alternatif

### Değerlendirilen A — verified partition'ı salt okunur overlay olarak bağlamak

| Boyut | Değerlendirme |
|---|---|
| Mevcut kodla uyum | `VerifiedLegacyImport` zaten read-only; bir overlay adaptörü ilk bakışta küçük görünür. Ancak her ekran/repository için overlay davranışı ve aynı ID'de öncelik kuralları gerekir. |
| Veri kaybı / recovery | Kopyalanmış kaynak korunur, fakat import ve owner store arasındaki kısmi görünüm için ortak bir commit noktası yoktur. Birkaç box/asset başarıp bir tanesi kalırsa ekranlar farklı birleşimler gösterebilir. |
| Performans | Her okuma iki repository/partition'a gidebilir; listeler birleştirilir ve kimlik çakışmaları sürekli çözülür. |
| Multi-Hive atomiklik | Overlay atomikliği çözmez; ekranın farklı çağrıları farklı durum görebilir. |
| World | İki World snapshot/generation kaynağını anlık birleştirmek, tek canonical pointer semantiğini bozar. |
| Career | Her read'de katkıları birleştirme, exactly-once ve eski toplam provenance sorununu zorlaştırır. |
| Owner izolasyonu | Her overlay çağrısında import lease ve owner UUID doğrulanmalıdır; unutulan bir tüketici veri sızıntısı oluşturabilir. |
| Bakım | Her ekran/repository'de overlay ve precedence kodu kalıcı karmaşıklık yaratır. |

### Değerlendirilen B — doğrulanmış owner revision hazırlayıp tek görünürlük referansı ile yayınlamak

Mevcut owner verisi ile verified import'tan gelen veriler, çakışmalar çözüldükten sonra **yeni ve immutable bir owner revision** için hazırlanır. Ekranlar yalnızca kalıcı görünür revision'ın repository facade'ını okur. Hazırlık kopyaları görünür değildir. Tüm veriler, dosyalar ve ilişkiler doğrulanınca tek durable pointer/revision commit edilir.

Bu yaklaşım seçilmiştir: current repository tüketicilerine tek kaynak görünümü sunar, World için tek generation/pointer sağlar ve Career katkılarını yayın öncesi doğrulamaya imkân verir. Mevcut Hive box'ları arasında transaction olmadığından, revision read barrier olmadan yeni box'lara kopya yazmak **yeterli değildir**. Her kişisel read revision facade'ından geçmeli; commit öncesi hazırlanmış alanlar hiçbir normal ekran veya background consumer tarafından enumerate edilememelidir.

Önerilen revision içeriği normal kayıtları silmeden, owner store'un mevcut kaynakları + import kaynakları için yeni revision'a ait ilişki/indeks görünümüdür. Büyük binary payload'ları tekrar belleğe toplamak yerine verified owner-scoped asset yollarına referans verir. Revision immutable olmalı; aktif referans tek ve kalıcı olmalıdır.

| Boyut | Değerlendirme |
|---|---|
| Mevcut kodla uyum | Owner lease, store, import partition ve rebuild servisleri korunur; üstlerine revision-aware read facade ve publisher eklenir. Entegrasyon maliyeti vardır, fakat her domain'in tek owner görünümü olur. |
| Veri kaybı / recovery | Kaynak ve eski active revision korunur. Hazırlık yarıda kalırsa staged revision görünmez; yeniden denenebilir. Eski revision pointer'ı ancak doğrulama sonrası değiştirilir. |
| Performans | Bir defalık hazırlama ve indeksleme maliyeti; sonraki ekran read'leri tek aktif revision üzerinden çalışır. Dosyalar hash doğrulamalı stream copy/reference olarak kalır. |
| Multi-Hive atomiklik | Hive kutuları arasında atomiklik iddia edilmez. Bütün hedefler flush+read-back doğrulanır; ardından ayrı durable control store'daki tek revision/pointer commit görünürlük noktasıdır. Bütün read yolları bu pointer'a uymalıdır. |
| World | Kaynaklar birleştirilerek yeni World generation rebuild edilir; iki generation pointer doğrudan birleştirilmez. |
| Career | Katkılar provenance/idempotency kimlikleriyle önceden çözülür; cumulative-only belirsizlik görünürlük öncesinde durdurur. |
| Owner izolasyonu | Pointer owner UUID ve epoch/lease ile doğrulanır; partition claim hedef UUID'si eşleşmeden owner revision'a giremez. |
| Bakım | Merkezi facade/publisher karmaşıklığı vardır; ancak her ekranın özel overlay kuralları yazmasından daha az ve denetlenebilirdir. |

Alternatif A uygun görülmedi; read-only partition davranışı yalnız import inceleme/preview için korunabilir. Ekranların kalıcı ortak görünümü olarak kullanılmamalıdır.

## C) Owner UUID → completed import keşif yolu

1. Auth adapter `LocalOwnerLifecycle` üzerinden hazır bir `LocalOwnerLease` üretir. Yalnız UUID biliniyor diye legacy kayıtlar otomatik claim edilmez.
2. `LegacyClaimLedger.completedForOwner(ownerUuid)` ledger'dan hedef UUID'si eşleşen `completed` claim'leri listeler. Bu discovery partition'ı otomatik sahiplenmez veya görünür kılmaz. Ledger'ın source namespace tekilliği korunur; başka owner claim'i yeniden atanamaz.
3. Her kayıt için `LegacyAccountImporter.openVerified(namespace, lease)` çağrılır. Namespace yalnız ledger'dan gelir; dışarıdan gelen key/path ile workspace açılmaz.
4. `openVerified` source/claim namespace, manifest fingerprint, owner UUID, copy receipts, files, store relationships ve `lease` eşleşmesini tekrar doğrular. Kaynak manifest sonradan değişmiş veya claim/receipt çelişkiliyse fail-closed.
5. Keşif completed kopyayı bulur ama henüz visible saymaz. Visibility control store'da aynı owner için `activeRevision` içeren kalıcı yayın receipt'i ayrıca aranır.
6. Tamamlanmış claim'in owner UUID'si başka ise sonuç dışarı verilmez; claim transfer/reassign API'si bulunmamalı.

Ledger içinde owner index'i eklemek yeterlidir; ikinci bir claim ledger oluşturmak gereksizdir. Büyük partition'larda listing sayfalı olmalı ve açılan her partition lease'e bağlı read-only nesne olarak kalmalıdır.

## D) Durable görünürlük commit noktası

`LegacyClaimLedger.completed` sadece **import partition kopyası ve doğrulaması tamamlandı** demektir. 5C.2G.2 bu anlamı değiştirmez: claim'i `completed` bırakıp aynı ledger DB'ye sürümlü `owner_revision` ve `import_visibility` tabloları ekler. Repository düzeyinde visibility commit'i implemented; canlı ekran görünürlüğü hâlâ yoktur.

Görünürlüğün tek commit noktası, claim ledger DB içindeki SQLite transaction ile yazılan owner-scoped `active_revision` pointer ve import fingerprint → visible revision receipt'inin birlikte commit edilmesidir. Bu transaction ancak şu işler tamamlandıktan sonra başlar:

- Yeni revision'ın tüm Hive kutuları flush edilmiş, tekrar okunmuş ve kaynakla ilişkileri doğrulanmış olmalı.
- Poster/harita dosyaları owner root içinde bulunmalı, stream SHA-256 receipt'i eşleşmeli; `mapImagePath` gibi metadata yalnız erişilebilir hedef referansına çevrilmiş olmalı.
- World combined-source rebuild tamamlanmış ve beklenen owner generation doğrulanmış olmalı.
- Career contribution identity/payload kontrolü ve aggregate doğrulaması tamamlanmış olmalı.
- Tombstone, Planet outbox ve diğer domain kayıtları sınıflandırılmış olmalı.
- Aktif owner lease/epoch ile import consent hedefi aynı olmalı; writer fence hâlâ quiesced olmalı.

SQLite control pointer'ın atomic commit'i dosya sistemi ve Hive flush'larını tek transaction'a dönüştürmez. Güvenlik garantisi, **pointer'dan önce** her şeyin durable/verified olması ve her okuma consumer'ının yalnız pointer'ın gösterdiği revision'ı açmasıdır. Crash pointer commit öncesi olursa eski revision görünür kalır; commit sonrası olursa önceden doğrulanmış yeni revision görünür. Pointer commit sonrası gerekli bir dosyanın kaybolması tespit edilirse ilgili revision fail-closed açılır ve veri kaynağı korunur; eski kayıtları silerek otomatik düzeltme yapılmaz.

## E) World merge kuralları

1. Kaynaklar owner-scoped `WorldSourceSnapshotRepository` üzerinden okunur. Existing owner kaynakları ile verified legacy kaynakları stabil source identity/fingerprint ile sıralanıp dedupe edilir.
2. İki `WorldIndexSnapshot`/generation pointer birleştirilmiş kabul edilmez. Combined source set için `MyWorldRebuildService` / mevcut planner ile yeni owner generation hazırlanır. `worldRulesVersion=6`, overlap/ownership/minimum/offset algoritmaları değişmez.
3. Aynı source identity ve aynı doğrulanmış payload/fingerprint varsa aynı kaynaktır; bir kez tutulur. Aynı kimlik ama farklı geometry, owner/source drive veya provenance varsa **çakışma**; otomatik kazanma kuralı yok, yayın yok.
4. Current owner tombstone aynı kanıtlanmış kaynak/trace'i hedefliyorsa tombstone üstün gelir; import onu diriltemez. Legacy tombstone da kendi source namespace içindeki kaydı suppress eder. Bir tombstone'ın yalnız ID benzerliği üzerinden başka provenance'a uygulanması yasaktır.
5. History silinmiş olabilir; bağımsız World source hâlâ mevcutsa World'e katılabilir. History kaydının olmaması World kaynağını otomatik silmez. World tombstone ayrı kalır.
6. Import öncesi ve publish'e kadar World rebuild writer'ı pause/drain veya aynı owner generation CAS/serialization bariyerinde olmalı. Base generation değişirse staged plan atılır/yeniden kurulur; stale plan commit edilmez.
7. Crash'te active pointer eski generation'da kalır. Aynı source fingerprint + deterministic operation/revision kimliğiyle staging tekrar doğrulanır; ikinci World izi üretilmez.

## F) Career merge kuralları

1. Career input `CareerContributionRepository` semantiğine uygun append-only contribution'dır; History veya World silme Career'ı azaltmaz.
2. Stable identity sadece `drive:<id>` değildir. Önerilen idempotency/source key, claim namespace + immutable manifest fingerprint + original drive identity (ve varsa canonical source identity) içerir. Yeni format version'lanmalıdır; aynı sürüş kaynağının doğru eşdeğerliği doğrulanmadan key yeniden yazılmaz.
3. Owner'da ve legacy importta aynı stable contribution identity varsa contribution payload'ları (metric basis, drive/source identity, score validity) eşitse tek katkı tutulur. Payload farklıysa conflict; toplamlar hesaplanıp overwrite edilmez.
4. Aynı `driveId` fakat farklı source/provenance ayrı kayıtlar olabilir; collision review olmadan dedupe veya overwrite yapılmaz. Eşleşme kesin değilse import fail-closed.
5. Legacy'de yalnız career total/rekor snapshot varsa ve per-drive receipts/contributions yoksa bu değerlerden sahte contribution listesi türetilmez. Mevcut owner contribution defteriyle birleştirmek veya ondan toplam üretmek güvenli değildir; ilgili Career importu quarantine'de kalır ve görünürlük tüm atomik revision için durur. Ayrı tarihsel baseline gösterimi ürün kararı gerektirir; bu aşamada önerilmez.
6. Tüm katkılar birleştirildikten sonra yeni revision total'ı contribution setinden deterministik olarak doğrulanır. Eski N/A/score metadata sıfır puana çevrilmez.

## G) Diğer kişisel verilerin merge kuralları

| Veri | Identity / doğrulama | Çakışma ve görünürlük |
|---|---|---|
| History / detail / telemetry | Drive id + source namespace/fingerprint; route/telemetry count ve içerik hash'i; skoru oluşturan metadata aynı bundle | Aynı identity ve payload dedupe. Aynı ID farklı payload/provenance ise conflict. Drive summary tek başına görünür olmamalı; telemetry, score, detay ve gerekli asset ilişkileri aynı revision'da tutarlı olmalı. |
| GPS canonical source | Var olan completed `DriveSession`/telemetry bundle; aktif SQLite journal ayrı | Legacy import var olan canonical rotayı yeniden hesaplamaz. GPS journal v3 / aktif session import edilmez ve sahibini değiştirmez. |
| Drive Score | Kaynağa bağlı kayıtlı score + algoritma/version ve N/A bilgisi | Recalculate veya skoru uydurma yok. Aynı drive farklı score basis ise conflict. |
| Poster metadata, PNG, mapImagePath | Drive/poster ID ilişkisi, metadata fingerprint; her referansın erişilebilir owner-scoped dosyası ve SHA-256'sı | PNG veya zorunlu map image eksik/erişilemiyorsa poster complete sayılmaz. `content://`/dosya izinleri gerçek erişimle doğrulanmazsa fail-closed; path string'i var diye başarı varsayılmaz. Accepted Planet trace/public content bu poster importundan bağımsızdır. |
| Profile / display preferences | Owner key ve alan bazlı kaynak manifest | Varsayılan olmayan veya kullanıcı tarafından değişmiş iki farklı değer çakışırsa sessiz last-write-wins yok; preview'da çözüm gerekir ya da ilgili import bloklanır. Username/email ownership kimliği olmaz. |
| Planet personal outbox | Mevcut segment/idempotency key + import namespace | Pending/mock/failed durumları private outbox'ta aynı kimlikle kalır, hiçbir zaman published UI'ına geçmez veya otomatik gönderilmez. Başka owner'a ait/unknown source outbox reddedilir. Server-accepted yayınlar immutable ve bu importun dışında kalır. |
| Lifecycle intent / tombstones | Owner scope + operation/source identity | Tamamlanmış ve kanıtlanmış tombstone restore edilmeyi engeller. Pending job aynı owner/base generation ile yeniden doğrulanır; stale/unknown job visibility öncesi çözülmelidir. |
| Cache / türetilmiş dosya | Revision + owner epoch | Canonical source değildir; merge etme yerine yeni revision için invalidate/rebuild. Owner/revision anahtarı olmadan cache okunmaz. |

## H) Consent/Auth state machine

| Durum | İşlem / geçiş koşulu |
|---|---|
| `discover` | Auth/owner lease hazırlanır; yalnız güvenli legacy inventory/manifest okunur. |
| `preview` | Aktarılabilir/belirsiz sayılar, mesafe ve asset durumu fingerprint ile gösterilir; bu henüz claim değildir. |
| `awaiting_consent` | Açık hedef UUID, mevcut owner epoch ve manifest fingerprint ile consent oluşturulur. Varsayılan kabul yoktur. |
| `skipped` | “Şimdilik Geç” legacy kaynağı ve claim'i değiştirmez; başka hesapta otomatik gösterim sağlamaz. Aynı consent tekrar açılabilir. |
| `quiescing` | Bütün bilinen source writer'lar pause/drain; aktif veya owner'ı belirsiz GPS session varsa durdur. Fence eksik/başarısız ise import başlamaz. |
| `reserved` / `copying` | `LegacyClaimLedger` source namespace için hedef UUID/fingerprint'i kalıcı sabitler. Başka owner claim'i alamaz. |
| `completed_not_visible` | Importer verified partition ve receipts'i tamamlamıştır; kullanıcı ekranları bunu owner live data saymaz. |
| `preparing_revision` | Mevcut owner + import için collision-checked staged revision, World rebuild, Career validation, asset validation hazırlanır. |
| `verifying` | Her domain ve dosya read-back/hash/invariant doğrulaması; owner lease/epoch/consent tekrar kontrol edilir. |
| `visible` | Owner revision pointer ve visibility receipt SQLite transaction'da atomik commit olur; yalnız bundan sonra revision-aware read facade açar. |
| `retryable_failed` | Kaynak ve önceki active revision korunur; aynı owner/manifest ile deterministic stage tekrar kullanılabilir veya yeniden doğrulanır. |
| `conflict_blocked` | Fingerprint, identity, Career provenance, World pointer/tombstone veya asset çatışmasında görünürlük yok; kullanıcı/ürün kararı bekler. |

Auth A→B geçişinde A lease/epoch hemen geçersizleşir ve B ekranları A future/cache sonuçlarını kabul etmez. `copying` veya `completed_not_visible` import A'ya sabit kalır; B'ye yönlendirilmez. A geri geldiğinde aynı UUID için yeni epoch alınır, partition tekrar açılır ve manifest/claim yeniden doğrulanır. Henüz visible değilse A altında güvenle devam edilebilir. Visible ise pointer A'ya bağlıdır; B kendi pointer'ını açar. Aktif sürüş varsa import başlamaz; sürüşü bitirme/sahip değiştirme yapılmaz.

## I) Crash recovery ve idempotency

1. **Reserve öncesi crash:** kaynaklar değişmez; consent yeniden istenir.
2. **Claim rezervasyonu/kopya sırasında crash:** claim hedefi/fingerprint değişmez; staged dosyalar geçici ve görünmezdir. Aynı owner için tekrar deneme hash/receipt ile devam eder; başka owner reddedilir.
3. **Import `completed`, revision hazırlanmadan crash:** `completed_not_visible` olarak keşfedilir; kişisel ekranlarda görünmez. `openVerified` ile yeniden doğrulanır ve merge planı hazırlanır.
4. **Hive/asset/World staging sırasında crash:** active revision pointer değişmemiştir. Partial staging kayıtları revision key'iyle izole edilir; retry aynı operation ID'yi kullanır, geçersiz kısmı görünür yapmaz ve kaynağı temizlemez.
5. **Verifying sırasında crash:** bütün kontroller tekrar yapılır; kısa yol ile visible işaretlenmez.
6. **SQLite visibility transaction öncesi crash:** eski pointer geçerlidir. Commit transaction atomik rollback/commit semantiğindedir.
7. **Commit sonrası yanıt/uygulama kapanması:** yeniden açılışta Auth UUID belirlenir, owner'ın active revision'ı okunur, visible receipt ve revision manifest'i tekrar doğrulanır. Aynı claim yeni generation/contribution oluşturmaz.
8. **Eski epoch callback:** lease revision/owner UUID ve epoch ile karşılaştırılır; stale Future/Stream sonucu reddedilir, B görünümüne uygulanamaz.

Bu sözleşme process interruption/retry dayanımını tanımlar; gerçek Android power-loss garantisi değildir. Hive flush davranışı, SQLite FULL/WAL durability, filesystem rename ve Android process-kill gerçek cihaz/emülatör kabul testleriyle ayrıca doğrulanmalıdır.

## J) Dosya/sınıf bazında uygulanacak değişiklikler

Bunlar sonraki aşamalar için plandır; bu doküman aşamasında uygulanmamıştır.

### 5C.2G.2 — domain ve kalıcı merge/visibility altyapısı

- `lib/services/legacy_claim_ledger.dart`: owner UUID ile sayfalı completed claim keşfi; mevcut tekil source claim'i koruma; aynı SQLite DB'de revision/visibility tabloları ve transaction API'si. Mevcut claim `completed` anlamını değiştirmeme.
- `lib/services/legacy_account_import.dart`: verified partition keşfi/reopen; manifest fingerprint ve relationship doğrulaması; stable import operation/source identity.
- Yeni domain tipleri: `OwnerRevision`, `OwnerRevisionManifest`, `LegacyMergePlan`, `LegacyMergeConflict`, `ImportVisibilityReceipt`; typed fail-closed conflict'ler ve codec/version.
- `lib/services/owner_scoped_local_store.dart`: revision-qualified staging/read adapters veya store facade; görünür revision dışındaki kayıtların `keys/read` ile sızmaması.
- `lib/features/my_world/...` ve `MyWorldRebuildService`: birleşik source set'ten mevcut kurallarla staged generation üretmek; tombstone/collision kontrolü ve base generation CAS.
- Career contribution repository: provenance-scoped idempotency identity, conflict classifier ve staged aggregate read-back.
- `lib/services/legacy_asset_transfer.dart`, PosterStore/import resolver: verified asset closure ve revision-scoped path reference; eksik asset'te blocked.
- Import bridge/consent controller: UUID+epoch+fingerprint ile staged merge; `completed_not_visible` ile `visible` ayrımı; writer fence ve active GPS barrier korunur.
- Unit/fault-injection tests: ledger unique reservation, retry, conflicts, pointer atomicity, World/Career/provenance.

### 5C.2G.3 — bootstrap, ekranlar ve kullanıcı akışı

- `lib/config/supabase_bootstrap.dart` / owner bootstrap integration point: gate açık kontrollü testte Auth owner hazırla, ledger'dan visible revision keşfet/doğrula, sonra revision facade ver; gate kapalı eski akış aynen.
- `lib/widgets/legacy_owner_consent_panel.dart` ve `lib/widgets/owner_personal_navigator.dart`: yalnız gate açık ve fake/test bağımlılıklarıyla consent preview/approve/skip; hedef UUID/epoch değişince onayı iptal et. Production wiring gate kapalıyken ulaşılamaz kalır.
- History/home/detail/score/Career/World/World-detail/Poster/Profile/Planet personal outbox repository adaptörleri: hepsi aynı `LocalOwnerLease + activeRevision` facade'ından okur; ID lookup dahil owner ve revision doğrular.
- World map, poster, drive detail ve diğer cache anahtarları owner UUID + revision + epoch içerir; owner switch'de controller ve async result fence'i uygulanır.
- Restart/visibility tests: completed not visible saklı; visible A→B→A; sadece A'nın revision'ı A'da açılır; normal yeni A kayıtları import beklemez.
- Uygulama navigasyonuna entegrasyon yalnız sentetik owner ortamında doğrulanır. Gerçek veriye açma ayrı kabul/karar gerektirir.

## K) Sentetik test kabul planı

| Senaryo | Beklenen kabul |
|---|---|
| Boş owner'a tek ve çok kayıtlı import | Tüm ilişkiler/asset'ler doğrulanır; tek revision görünür olur. |
| Mevcut owner kayıtları + legacy | Mevcut kayıtlar korunur; verified duplicate tekilleşir; unrelated kayıtlar aynen kalır. |
| Guest → A → B → A | Legacy sadece açıkça onaylanmış A revision'ında görünür; B'de yok; A dönüşte aynı içerik/identity. |
| Drive ID aynı, payload/provenance farklı | Merge `conflict_blocked`; hiçbir kısmi kayıt görünmez. |
| Career duplicate contribution aynı payload | Tek contribution ve doğru aggregate. |
| Career aynı identity farklı payload / yalnız cumulative total | Fail-closed; kaynak ve mevcut Career korunur. |
| World mevcut + legacy source / iki pointer | Yeni deterministic generation; eski pointer'lar doğrudan birleştirilmez; v6 sonucu oracle ile uyumlu. |
| World tombstone conflict | Doğrulanmış tombstone suppress eder; farklı provenance'a ID benzerliğiyle uygulanmaz. |
| Poster missing/inaccessible asset, path traversal | Revision görünür olmaz; kaynak ve eski active owner revision sağlam kalır. |
| Completed, not visible restart | Owner keşfeder, tekrar doğrular; ekranlarda hâlâ yoktur; retry duplicate üretmez. |
| Her staging flush öncesi/sonrası interruption | Active pointer eski kalır; tekrar deneme idempotent; kaynak korunur. |
| Visibility transaction öncesi/sonrası interruption | Önce eski veya sonra tam yeni revision; ara/kısmi görünüm yoktur. |
| Auth/epoch yarışı, A→B | Eski callback B'de reddedilir; import A'da sabit kalır. |
| Skip / consent değişimi | Skip claim/import başlatmaz; UUID, epoch veya fingerprint değişince eski consent reddedilir. |
| Import sırasında active GPS veya writer drain failure | Import başlamaz; sürüş ve kaynak kayıtları değiştirilmez. |
| Planet pending/outbox | Kişisel owner altında korunur; gerçek gönderim/published state oluşmaz. |
| Normal yeni owner kayıtları | Owner store'a normal yazılan kayıtlar legacy import completion'a bağımlı olmadan görünür. |
| Eski Hive ve GPS SQLite v3 | Adapter/journal uyumluluğu korunur; gerçek kullanıcı verisi testte kullanılmaz. |

Kontrollü exception/process-kill testleri raporda ayrı sınıflandırılmalı; sentetik exception gerçek OS process death veya power loss kanıtı sayılmaz.

## L) Açık kararlar ve teknik riskler

1. **ID/provenance collision UX:** Aynı UUID/drive id fakat farklı doğrulanmış kaynak içeriği varsa kullanıcıya seçenek sunulup sunulmayacağı ve güvenli çözüm biçimi belirlenmeli. Bu karara kadar otomatik merge yok.
2. **Legacy cumulative Career:** Tekil contribution receipt'i olmayan totals/rekorların ayrı, açıkça tarihsel ve katkı olmayan gösterimi ürün kararı gerektirir. Varsayılan davranış Career importunu bloklamaktır.
3. **World merge kaynak semantiği:** Legacy World snapshot yalnız active trace değil kaynak seti ve tombstone içerebilir. Bütün source/provenance bağları doğrulanmadan yeni generation hazırlanamaz.
4. **Tombstone identity:** Eski tombstone'ların source namespace/fingerprint'e bağlanabilirliği kanıtlanmalı; yalnız ID eşleşmesi ile suppression veri kaybı/diriltme yaratabilir.
5. **Tek durable pointer ve çoklu repository read:** Her kişisel tüketicinin pointer-aware facade'a taşınması gerekir. Bir consumer doğrudan box açarsa partial staged content görünme riski kalır.
6. **Hive + filesystem atomiklik:** Control SQLite pointer ancak tüm target flush/hash/read-back sonrasında commit edilebilir. Power loss/fsync/rename garantileri kullanılan plugin ve filesystem üzerinde ayrıca ölçülmelidir.
7. **Writer registry completeness:** Import fence'e katılmayan tek bir background/service writer quiescence varsayımını bozar. Writer envanteri/runtime registration fail-closed olmalı.
8. **Dosya erişimi:** `content://` izinlerinin kalıcılığı, eski cache/temp paths, silinmiş poster kaynakları ve Android scoped storage'da erişim gerçek cihaz kabulüne bağlıdır. Erişilemeyen asset complete sayılamaz.
9. **Büyük veri seti:** Manifest tarama/kopyalama bounded memory ve progress/resume ile uygulanmalı; World rebuild ve hash CPU/memory ölçülmeli.
10. **Recovery ve işletim sistemi:** Kontrollü testler gerçek kapanma/power-loss ile eşdeğer değildir. A55 gerçek legacy verisinde kapalı gate kabulü ve backup planı gereklidir; bu aşamada yapılmaz.
11. **Güvenlik sınırı:** Bu tamamen yerel veri sahipliği/visibility modelidir; şifreleme veya bulut hesap güvenliği garantisi değildir. Bulut Faz 8 kapsamındadır.

### Kararlar / sonraki adıma hazır oluş

- **Mimari uygulanabilir mi?** Evet. Owner-scoped immutable revision + durable active-revision pointer ile; tüm consumers pointer'a bağlanmalı ve conflict'ler fail-closed kalmalıdır.
- **Yeniden kullanılacaklar:** `LegacyAccountImporter`, `LegacyClaimLedger`, `VerifiedLegacyImport`, `LegacyOwnerConsentController`, `LocalOwnerImportBridge`, `LegacySourceWriterFence`, `LocalOwnerLifecycle`/`LocalOwnerLease`, `OwnerScopedLocalStore`/`ScopedLocalRepositories`, `CareerContributionRepository`, World snapshot/rebuild/planner, `PosterStore`/`OwnerAssetTransfer`, GPS owner sidecar.
- **Geliştirilecekler:** owner UUID ile completed claim discovery; merge/conflict planner ve stable provenance identity; revision-qualified repositories; kalıcı visibility receipt/active pointer; bütün kişisel ekranlarda tek read facade; consent/navigator bağlantısı; restart/retry ve fault-injection kabul testleri.
- **Veri güvenliğini engelleyen açık karar var mı?** Tasarımı engelleyen temel bir mimari karar yok; fakat provenance çakışması ve cumulative-only Career verisinin nasıl ele alınacağı çözülmeden importer görünürlük commit'i **açılamaz**. Varsayılan fail-closed'dur.
- **5C.2G.2 kodlamasına geçiş uygun mu?** Evet, yalnız domain/ledger discovery/staging/visibility altyapısının sentetik testlerle uygulanmasına. Bu, production gate'i açma veya gerçek legacy importu çalıştırma izni değildir. 5C.2G.3 tüm ekran facade entegrasyonu ve restart kabulü tamamlanmadan kullanıcı verisi görünürlük akışı etkinleştirilmemelidir.
