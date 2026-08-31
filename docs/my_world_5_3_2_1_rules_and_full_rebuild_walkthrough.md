# Benim Dünyam — 5/3/2/1 Mesafe Kuralları ve Full Rebuild

## Kurallar

Merkezi `MyWorldRules` artık şu eşikleri kullanır:

- World'e kabul: doğrulanmış yol mesafesi `>= 5000 m`.
- Aynı yol/yön karşılaştırması: ortak doğrulanmış yol `>= 3000 m`.
- Challenger kazanan bölgesi: gap merge sonrasında `>= 2000 m`.
- Existing-owner split remainder görünürlüğü: `>= 1000 m`.
- Challenger gap merge: mevcut `<= 200 m` davranışı korunur.

Ham GPS veya `DriveSession.distance` bu eşikleri belirlemez; `ValidatedRoad`
mesafesi kullanılır. İlk kez örtülmemiş yola kayıt oluşturma davranışında ek bir
2000 m kuralı yoktur; 2000 m yalnızca challenger'ın mevcut owner'dan kazandığı
birleşmiş bölge için geçerlidir.

## Ownership ve remainder

`LocalWinningRoadRegionService` ve `WorldIndexMutationPlanner` yeni merkezi
eşikleri kullanır. Split sonrası 1000 m'den kısa existing remainder active
snapshot'a eklenmez; source `DriveSession`, `ValidatedRoad` ve canonical
telemetry silinmez. Böylece silme/restore ve gelecekteki rebuild geçmişten
yeniden üretilebilir.

## Rules/index version

Hive şeması değiştirilmedi. `MyWorldRules.worldRulesVersion` 3'e yükseltilmişti;
global 1 km active-trace invariant için mevcut sürüm 4'tür. Snapshot'ın
snapshot'ın mevcut `validatedRoadProcessingVersion` alanı index-rules invalidation
işareti olarak kullanılıyor. `needsRebuild` hem Drive Score sürümünü hem de World
rules sürümünü kontrol eder; eski snapshot sessizce kullanılmaz.

## Full rebuild

`MyWorldRebuildService` mevcut copy-on-write lifecycle'ını kullanır. Kaynak gerçek:
stored DriveSession + stored ValidatedRoad + canonical telemetry'dir; ActiveWorld
snapshot yalnızca mevcut base/generation ve atomic commit için kullanılır.
Sürüşler tarih artan, eşit tarihte ID artan sırayla replay edilir. Geçerli stored
road geometry Mapbox'a yeniden gönderilmez. Eksik/invalid validation ayrı pending
pipeline sorumluluğudur.

Rebuild başarısız olursa eski snapshot korunur; başarılı sonuç tek commit ile
aktive edilir. Aynı history iki kez işlendiğinde aynı active trace/range sonucu
üretilir. Debug modunda `[WORLD_RULES]` ve `[WORLD_REBUILD]` özetleri yazılır.

## Eski kayıtlar

5 km altındaki sürüşler DriveSession, Drive Score ve ValidatedRoad olarak korunur;
yalnız My World active ownership'e katkı vermez. Eski 2 km altı challenger
bölgeleri yeni replay'de kazanım oluşturamaz. 1 km altı split remainder'lar aktif
haritada görünmez.

## Doğrulama

Phase 1/2/3/5/6/7 World testleri yeni 5/3/2/1 sınırlarına göre güncellendi ve
geçti. Gerçek cihaz kontrolünde rules-version mismatch, rebuild logları, active
trace/mesafe, kısa remainder'ların kaybolması ve opposite-direction görünümü
Galaxy A55 üzerinde ayrıca doğrulanmalıdır.
