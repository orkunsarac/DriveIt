# Benim Dünyam — Phase 5: Lokal Rekor Bölgesi Tespiti

## Amaç ve sınır

Bu faz, eligible bir `CommonRoadMatch` boyunca geçici yerel skor pencereleri üretir ve challenger'ın yalnızca anlamlı biçimde üstün olduğu fiziksel yol bölgelerini domain sonucu olarak döndürür.

World index, rekor sahipliği, Hive persistence, neon çizim, kullanıcı arayüzü, backfill ve silme davranışı bu fazın dışında tutulmuştur.

## Geçici 100 m analiz

`LocalWinningRoadRegionService`, ortak yolun `0..commonDistanceMeters` yerel eksenini `MyWorldRules.localScoreAnalysisWindowMeters` ile yaklaşık 100 metrelik pencerelere böler. Son parça daha kısa olabilir; örneğin 1050 m için on adet 100 m ve bir adet 50 m pencere oluşur.

Bu pencereler kalıcı segment veya ownership kaydı değildir. Her pencere, Phase 4'ün aynı `CommonRoadTelemetryExtractor` yol projeksiyonunu `extractRange` üzerinden kullanır. Böylece ham GPS toplam mesafesinden dilimleme yapılmaz ve mevcut section/self-intersection güvenlik kuralları korunur.

Her pencere için iki gerçek `DriveScoreCalculator.calculate` çağrısı yapılır: mevcut rekor adayı first, challenger second tarafıdır. Hesaplama ve sonuçlar yalnızca bellek içindedir; `drive_scores`, `DriveScoreRecord`, Hive veya Dünya persistence'ı kullanılmaz.

## Pencere sonucu ve yüzde bir kuralı

Her geçici `LocalRoadScoreWindow` şu durumların birini taşır:

* `challengerBetter`: challenger, existing skordan en az %1 yüksek;
* `existingBetter`: existing tarafı en az %1 yüksek;
* `noMeaningfulDifference`: eşit veya yüzde bir altı fark;
* `invalid`: telemetry mapping/scoring/version hatası ya da yetersiz canonical veri.

Yüzde bir eşiği Phase 4'teki merkezi `minimumMeaningfulScoreImprovementRatio` üzerinden uygulanır; Phase 5 ayrı bir skor formülü kullanmaz.

## Bölge birleştirme ve minimum mesafe

Ardışık challenger pencereleri aday bölge olur. Aradaki neutral, existingBetter veya invalid fiziksel boşluk toplamı en fazla 200 m ise aday kesilmez; sonraki challenger penceresi onunla birleştirilir. 200 m'yi aşınca aday kapanır. Tolerans, gerçek offset mesafesiyle hesaplanır; pencere sayısıyla hesaplanmaz.

Bir aday yalnızca gerçek `endOffset - startOffset` mesafesi en az 500 m ise `LocalWinningRoadRegion` olur. Bu sonuç hem common-road eksenindeki hem de iki sürüşteki fiziksel offset sınırlarını taşır. Birden fazla ayrı kazanım birleştirilmez.

Örnekler:

* 2.4 km common road: challenger 0–400 m, neutral 400–500 m, challenger 500–1000 m → yaklaşık 0–1000 m tek geçerli region.
* challenger 0–400 m, neutral 400–700 m, challenger 700–1100 m → boşluk 200 m üstünde olduğunda iki küçük region kalır; ikisi de 500 m altındaysa sonuç boştur.
* challenger 300–1700 m → yaklaşık 1.4 km tek geçerli region.

## Güvenlik ve determinism

1 km altındaki match'lerde hiç pencere veya skor çağrısı yapılmaz. Düşük geometry confidence de region üretmeden güvenli sonuç döndürür. Tek taraflı local score hatası hiçbir zaman diğer tarafı kazanan ilan etmez; pencere `invalid` olur. Aynı common match, canonical telemetry, algorithm version ve config aynı pencere/region sınırlarını üretir.

## Performans

10 km overlap yaklaşık 100 pencere ve en fazla 200 in-memory Drive Score çağrısı üretir. Bu faz correctness odaklıdır; kalıcı cache oluşturmaz. Bir pencerenin canonical subset'i yalnızca o pencerenin iki skor hesabı için kullanılır; duplicate extraction/scoring yapılmaz.

## Test kapsamı

`test/my_world_phase5_winning_region_test.dart` şunları doğrular:

* tüm common road challenger olduğunda tek region;
* yüzde bir altı/eşit/existing üstünlüğünde boş sonuç;
* 300 m red, tam 500 m kabul;
* 100 m neutral ve 200 m invalid gap birleştirme;
* 201 m üzeri boşlukta ayrılma;
* çoklu region ve iki sürüşte offset doğruluğu;
* 1050 m son kısa pencere;
* 1 km altı match'te hesaplayıcı çağrılmaması.

## Bilinçli olarak sonraya bırakılanlar

Bu domain bölgeleri henüz aktif Dünya rekorunu değiştirmez. Phase 6, doğru bölünmüş verified-road ownership index'i, atomik commit, silme sonrası geri alma ve sonrasında görünür neon iz katmanlarını ele almalıdır.
