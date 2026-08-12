# Benim Dünyam — Phase 6: Gerçek Rekor Motoru ve Kalıcı World Index

## Kapsam

Phase 6, `readyForWorldProcessing` durumundaki doğrulanmış bir sürüşü mevcut
aktif Dünya sahipliğiyle karşılaştırır ve yalnızca sonuçta görünmesi gereken
izleri kalıcı hale getirir. Harita/UI, silme sonrası geri kazanım, otomatik
backfill, yeniden puanlama ve neon çizim bu fazın dışındadır.

## Aktif trace modeli

`ActiveWorldTrace` (Hive typeId `19`) bir geometri kopyası değildir. Kaynak
`DriveSession`, `ValidatedRoad`, `MatchedRoadSection`, yol üzerindeki başlangıç
ve bitiş metre offset'i, yön anahtarı ve coarse bounding-box bilgilerini taşır.
Geometri gelecekte doğrulanmış yoldaki section referansından çıkarılır.

İz kimliği source drive + road + section + fiziksel offsetlerden deterministik
üretilir. Böylece aynı işin tekrar denenmesi ikinci bir trace oluşturmaz.

## Kalıcı index ve atomik commit

`WorldIndexSnapshot` (typeId `20`) tüm aktif trace setinin immutable bir
neslidir. `WorldIndexPointer` (typeId `21`) yalnızca aktif generation'ı tutar.

1. Güncel snapshot okunur.
2. Tüm ownership değişimi bellek içinde `WorldIndexMutationPlan` olarak
   hesaplanır ve invariant'lar doğrulanır.
3. Tam yeni snapshot ayrı Hive kaydına yazılır.
4. Bu yazı başarılı olursa aktif pointer yeni generation'a geçirilir.

Bu copy-on-write yaklaşımında snapshot yazımı yarıda kesilirse eski pointer
değişmediği için eski tam index okunur. Pointer değiştiğinde ise yeni snapshot
zaten bütünüyle yazılmıştır. Crash ile pointer güncellemesi ve processing state
yazımı arasına girilirse snapshot'taki `processedDriveSessionIds` idempotent
kaynak olur; sonraki çağrı index'i yeniden bölmeden yalnızca processing
record'unu `processed` durumuna onarır.

## Rekor mutasyonu

`WorldRecordProcessingService`, yalnızca aynı yön anahtarına sahip aktif
trace'leri aday alır; geometry overlap için Phase 3 `WorldRoadOverlapService`,
geçici local score için Phase 4-5 `LocalWinningRoadRegionService` kullanılır.
Phase 6 %1, 100 m, 200 m veya 500 m kurallarını tekrar hesaplamaz; Phase 5
çıktısı tek doğruluk kaynağıdır.

Her `LocalWinningRoadRegion` mevcut trace'i gerekli yerde keser:

```text
Drive1: 0 ───────────── 10 km
Drive2 winner:       4 ─ 5.5 km

sonuç: Drive1 0─4 | Drive2 4─5.5 | Drive1 5.5─10
```

Başta/sonda kazanım trim üretir; tamamını kazanım eski trace'i kaldırır. Bir
trace içindeki çoklu kazanımlar doğal olarak dönüşümlü dinamik parçalara ayrılır.
Farklı kaynaklar asla merge edilmez; aynı kaynak/road/section/yön için bitişik
parçalar ise gereksiz index parçalanmasını önlemek üzere birleşir. Yalnızca
geometrik epsilon altındaki teknik artıklar temizlenir; gerçek kısa kalan
mevcut trace parçaları korunur.

Challenger'ın aktif index tarafından kapsanmayan section interval'leri ayrıca
çıkarılır ve ilk kayıt trace'i olarak eklenir. Bu nedenle 300 m gibi
karşılaştırmaya uygun olmayan overlap mevcut kayıtta kalırken, sürüşün sonraki
yeni bölümü kaybolmaz. Kapsanan overlap'te ikinci aktif sahiplik yazılmaz.

Örnek: Drive1 0–10 km iken Drive2 aynı yolda 2–8 km ortak sürüyor ve 3–4 km
ile 6–7.2 km kazanıyorsa index mantıksal olarak şu owner sırasını taşır:

```text
0–3 Drive1 | 3–4 Drive2 | 4–6 Drive1 | 6–7.2 Drive2 | 7.2–10 Drive1
```

Drive2 ayrıca mevcut Dünya'nın dışındaki yeni yola çıkarsa yalnızca o
kaplanmamış interval, bağımsız bir ilk-kayıt trace'i olur.

## Processing state ve metadata

Drive yalnızca snapshot commit başarılı olduktan sonra `processed` işaretlenir.
Hata sırasında aktif pointer/index değişmez; `DriveSession` ve `ValidatedRoad`
korunur, processing record `failedRetryable` olur. Snapshot metadata, Drive
Score algorithm sürümünü ve validated-road processing sürümünü birbirinden
ayrı tutar. 100 m local skorlar veya pencere geçmişi kalıcı hale getirilmez.

## Hive uyumluluğu

Mevcut adapter ve alanlar değiştirilmedi. Phase 1–5'in 10–18 typeId aralığına
dokunulmadı; yeni index modelleri 19–21'dir. Index ayrı Hive box'larda tutulur.

## Test kapsamı

`test/my_world_phase6_index_test.dart` şu davranışları sınar:

- boş Dünya'da tek ve disconnected-section ilk kayıtları;
- orta, baş, son ve tüm-trace replacement;
- iki ayrı winner region;
- kısa overlap'te first-record önceliği ve sonraki yeni yol;
- adjacent same-source merge;
- gerçek kısa remainder'ın korunması;
- deterministic operation id ve generation/version metadata.

## Bilinçli sınırlar

Bu faz silme sonrası eski rekor restore'u, score-version rebuild'i, UI sorgu
bağlantıları, otomatik eski sürüş backfill'i veya harita rendering yapmaz.
