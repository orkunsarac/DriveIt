# Benim Dünyam — Phase 4: Ortak Yol Telemetrisi ve Lokal Drive Score

## Amaç ve sınır

Bu faz, bir `CommonRoadMatch` için iki sürüşün yalnızca ortak doğrulanmış yoluna karşılık gelen canonical telemetriyi çıkarır; iki alt kümeyi gerçek Drive Score v1 hattında bellek içinde puanlar ve yüzde bir anlamlı üstünlük kuralını uygular.

Bu faz Dünya indeksi, aktif rekor sahipliği, 100 metrelik yerel tarama, 500 metrelik kazanan parça, Hive'a lokal skor yazılması, neon çizim veya kullanıcı arayüzü oluşturmaz.

## Road offset → canonical telemetry eşleme

`CommonRoadTelemetryExtractor`, `CommonRoadMatch` içindeki metre offset'lerini ham GPS'in toplam mesafesi olarak yorumlamaz. Her canonical örnek, yalnızca ilgili `MatchedRoadSection` geometrisine yerel projeksiyonla eşlenir. Örnek;

* eşleşen section bulunamazsa güvenli `mappingFailed` döner;
* projeksiyon mesafesi 35 m toleransı aşarsa örnek alınmaz;
* örnek heading'i geçerliyse, yol yönünden 60 dereceden fazla ayrılan eşleşme alınmaz;
* ortak offset aralığı dışındaki örnekler alınmaz;
* section'lar arasında taşma yapılmaz;
* rota kendi üstünden geçiyorsa uygun offset aralığı ve heading daha doğru ziyareti seçer.

Seçilen gerçek telemetry örneklerinin özgün zaman sırası korunur ve tekrar eden/geriye giden timestamp güvenli `mappingFailed` sonucuna dönüşür.

### Sınır davranışı

Ortak yol sınırı iki telemetry örneği arasındaysa bu faz yeni veya sahte telemetry üretmez. Sınırın içinde kalan yakındaki gerçek canonical örnekler kullanılır. Bu karar deterministik kalır ve Phase 1'in canonical verisini değiştirmez.

## Lokal Drive Score

`CommonRoadLocalScoreService`, yalnızca `comparisonEligible == true` olan (en az 1 km) eşleşmelerde iki subset için gerçek `DriveScoreCalculator.calculate` çağrısını yapar. Hesaplayıcı local canonical listeyi yeniden analiz eder; tam sürüşten eski phase/event/traffic sonucu kesilip yeniden kullanılmaz.

Algorithm version, `DriveScoreAlgorithmVersion.v1` contract'ı ile açık biçimde taşınır. Her hesap yalnızca bellek içindedir: servis `DriveScorePersistenceCoordinator`, `DriveScoreRecord` ya da `drive_scores` Hive box'ına başvurmaz.

## Karşılaştırma sonucu

`CommonRoadScoreComparison` iki lokal sonucu, imzalı ikinci-eksi-birinci farkını ve düşük sıfır olmayan skora göre göreli farkı taşır. Sonuç generic kalır; üst katman daha sonra hangi tarafın mevcut rekor veya challenger olduğunu belirleyebilir.

Kural merkezî `MyWorldRules.minimumMeaningfulScoreImprovementRatio` değeriyle uygulanır:

`candidate >= other × (1 + 0.01)`

Tam yüzde bir fark kazanç sayılır. Daha küçük farklar ve eşitlik `noMeaningfulDifference` döndürür. Skorlama veya mapping iki taraftan biri için başarısız olursa diğer taraf kazanan ilan edilmez; karşılaştırma geçersiz döner.

Örnek domain akışı:

* Sürüş 1: 30 km toplam; eşleşen doğrulanmış section içi 8.2–10.6 km.
* Sürüş 2: 18 km toplam; eşleşen doğrulanmış section içi 3.1–5.5 km.
* Ortak yol: 2.4 km.
* Lokal sonuçlar: S1 = 842, S2 = 854.
* Göreli iyileşme: yaklaşık %1.43.
* Domain sonucu: `secondWins`; bu fazda hiçbir Dünya rekoru değiştirilmez.

## Hata ve determinism

Boş/yetersiz telemetry `insufficientTelemetry`, section/projeksiyon/zaman sırası sorunları `mappingFailed`, scoring hataları `calculationFailed` olarak döner. `DriveScoreCalculator`'ın mevcut algorithm-version contract'ı desteklenmeyen sürüm değerlerini güvenli biçimde reddeder.

Her adım yalnızca giriş geometri, canonical telemetry, merkezi kurallar ve açık algorithm version kullanır. Saat, rastgelelik veya persistence durumuna bağlı değildir; aynı giriş aynı lokal karşılaştırma sonucunu üretir.

## Test kapsamı

`test/my_world_phase4_local_score_test.dart` şunları kapsar:

* tam ve orta ortak-yol eşleme;
* sınırlar örneklerin arasına düştüğünde gerçek örnek seçimi;
* kısmi/multiple section sınırı;
* boş ve eşlenemeyen telemetry;
* self-intersection/route revisit yön seçimi;
* 1 km eligible eşleşmede gerçek in-memory kalkülatör;
* 999 m eşleşmede hesaplayıcının hiç çağrılmaması;
* yüzde bir eşiği, eşitlik ve iki yöndeki kazanan;
* tek taraf scoring hatasında kazanan ilan edilmemesi;
* v1 local comparison determinismi.

## Bilinçli olarak sonraya bırakılanlar

Bu altyapı henüz birden fazla `CommonRoadMatch` sonucunu birleştirmez. Phase 5, yaklaşık 100 metrelik lokal analiz, 200 metrelik boşluk toleransı ve minimum 500 metrelik yeni rekor parçasını değerlendirebilir. Dünya index'i, atomik sahiplik güncellemesi ve görsel neon izler sonraki fazların kapsamındadır.
