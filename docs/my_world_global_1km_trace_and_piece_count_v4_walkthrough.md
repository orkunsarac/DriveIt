# My World v4 — Global 1 km Active Trace ve Piece Count

## Kurallar

5/3/2/1 kuralları korunur: source drive için 5.000 m, karşılaştırma için
3.000 m, challenger kazanımı için 2.000 m ve gap merge için 200 m. Yeni v4
invariantı, creation reason ne olursa olsun her bağımsız `ActiveWorldTrace`
parçasının en az 1.000 m olmasını zorunlu kılar.

Bu filtre first-record ve uncovered continuation parçalarına da uygulanır.
1.000 m altı parçalar active snapshot'a yazılmaz; DriveSession,
ValidatedRoad ve canonical telemetry korunur. 2.000 m challenger kuralı ayrı
kalır: 1.500 m parça 1 km'yi geçse bile ownership kazanamaz.

## Merkezi invariant

`WorldIndexMutationPlanner` normalized sonucu commit planından önce merkezi
olarak sanitize eder. `HiveMyWorldIndexRepository` de commit öncesinde aynı
invariantı doğrular; böylece yalnız UI filtrelemek yerine bozuk snapshot
oluşturulamaz. Farklı source parçaları yapay olarak birleştirilmez.

## Sayaç semantiği

World read modelindeki `processedDriveCount` artık
`snapshot.traces.length` değeridir. Aynı DriveSession'dan gelen iki bağımsız
active piece iki ayrı “sürüş” contribution olarak sayılır. Source DriveSession
çoğaltılmaz; `processedDriveSessionIds` navigasyon ve source işlemleri için
unique liste olarak korunur. Toplam mesafe yalnız final active snapshot
parçalarının toplamıdır. Zoom/presentation filtreleri bu sayaçları değiştirmez.

## Full rebuild ve sürüm

`MyWorldRules.worldRulesVersion` 4'e yükseltildi. Startup zinciri version
mismatch gördüğünde `ensureCurrentWorldIndex()` full history replay başlatır;
DriveSession + ValidatedRoad + canonical telemetry kaynak alınır, tarih ve ID
sırasıyla işlenir ve stored valid geometry yeniden Mapbox'a gönderilmez.
Copy-on-write snapshot commit ve idempotent rebuild korunur.

## Tanı logları

`[WORLD_RULES]` global minimumu ve sürüm 4'ü, `[WORLD_REBUILD]` active piece,
unique source ve displayed count değerlerini, `[WORLD_COUNT]` eşdeğer sayaç
bilgisini ve `[WORLD_SHORT_TRACE]` kısa parça auditini raporlar. Persisted
trace provenance alanı olmadığı için creation reason uydurulmaz.

## Doğrulama

- Global minimum ve eski phase testleri güncellendi.
- `flutter test`: 208 test geçiyor.
- `flutter analyze`: yalnızca önceden var olan 5 info-level bulgu.
- `git diff --check`: geçti; yalnız Windows satır sonu uyarıları var.

Gerçek cihaz sonucu için v4 rebuild sonrasında `[WORLD_RULES]`,
`[WORLD_REBUILD]`, `[WORLD_COUNT]` ve `[WORLD_SHORT_TRACE]` logları ile World
ekran görüntüsü ayrıca alınmalıdır.
