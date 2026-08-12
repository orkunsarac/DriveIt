# Benim Dünyam Phase 7 — Lifecycle, Restore ve Rebuild

## Kapsam

Phase 7, Phase 6 copy-on-write World index'ini kullanarak aktif iz taşıyan
sürüşlerin güvenli silinmesini, geçmiş geçerli adayların geri yüklenmesini ve
açıkça çağrılan deterministik full rebuild işlemini ekler. UI, Mapbox çağrısı,
backfill ve yeni skor formülü bu fazda değiştirilmemiştir.

## Silme yaşam döngüsü

`MyWorldLifecycleService` önce aktif trace sayısı ve mesafesini sorgular.
Aktif iz yoksa normal silme fast-path'i kullanılır. Aktif iz varsa kaynak
DriveSession hâlâ dururken `MyWorldRebuildService` tüm geçerli tarihsel yolları
silinen sürüşü dışlayarak yeniden değerlendirir. Yeni snapshot başarıyla
copy-on-write commit edilmeden kaynak silinmez. Commit başarısızsa eski pointer
korunur; kaynak ve telemetriye dokunulmaz. Kaynak silme başarılı olduktan sonra
ValidatedRoad, processing record ve pending job kayıtları temizlenir.

Bu sıra idempotenttir: silme yeniden denenirse kaynak zaten yoksa normal Hive
silmesi güvenlidir; snapshot aynı dışlama kuralıyla tekrar üretilebilir.

## Restore adayları

Adaylar yalnızca eski World kazananlarından değil, mevcut DriveSession geçmişi
ile `ValidatedRoad` kayıtlarının tamamından alınır. Sıra `DriveSession.date`,
eşitlikte stable drive id ile belirlenir. Aynı Phase 3 overlap ve Phase 5
local-winner servisleri kullanılır; özel restore skoru yoktur. Kısmi kapsama
trace planner tarafından kesilir, alternatif yoksa ilgili bölüm snapshot'tan
kalkar ve aynı kaynak/bitişik parçalar planner tarafından birleştirilir.

## Full rebuild

`MyWorldRebuildService.rebuild(targetVersion: ...)` mevcut active snapshot'ı
kaynak kabul etmez. Boş bir staging snapshot'ında tüm kaynak yolları işler,
invariant'ları planner/repository ile doğrular ve tek yeni generation aktive
eder. ValidatedRoad eksik veya uygun değilse ağ çağrısı başlatılmaz ve kayıt
skipped/missing olarak raporlanır. Eski snapshot yalnızca commit sonrasında
değişir; hata halinde korunur.

Şu anda desteklenen hedef `DriveScoreAlgorithmVersion.v1`'dir. Desteklenmeyen
bir sürüm açıkça reddedilir; sahte v2 oluşturulmaz. `needsRebuild` aktif snapshot
metadata sürümü ile istenen sürümü karşılaştırır. Eksik pointer/snapshot veya
geçersiz trace invariant'ı `worldIndexCorrupt` olarak rebuild ihtiyacı döndürür.

## Metadata ve uyumluluk

`WorldIndexSnapshot.operationReason` yeni Hive field 7 olarak eklendi; eski
snapshotlarda alan yoksa adapter `recordProcessing` varsayımını kullanır.
Mevcut typeId/field numaraları değiştirilmedi. Yeni lifecycle verisi ayrı
modelde tutulur; DriveSession ve canonical telemetry şeması korunur.

## Doğrulama

Phase 1–6 testleriyle birlikte Phase 7 lifecycle/rebuild testleri çalıştırılmalı;
`flutter analyze`, `flutter test` ve `git diff --check` sonuçları teslim
raporuna eklenmelidir.

## Bilinçli olarak yapılmayanlar

World UI, neon animasyon, otomatik rebuild scheduling, Mapbox backfill,
multiplayer ve Drive Score formül değişikliği bu fazın dışındadır.
