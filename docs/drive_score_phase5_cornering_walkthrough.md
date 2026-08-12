# Drive Score Phase 5 — Viraj Performansı

## Kapsam

Phase 5 yalnızca Viraj Performansı için 150 puanlık, yeniden üretilebilir bir
offline analiz motoru ekler. Nihai 0–1000 Drive Score, diğer kategori motorları,
arayüz, Hive şeması ve World sistemi bu fazda değiştirilmemiştir.

## Girdiler ve mimari

`CorneringScoreEngine`, yeni bir viraj algılayıcısı oluşturmaz. Phase 2
`DrivePhaseAnalyzer` tarafından üretilen `corner` event'lerini, bunların
cornering ownership bilgisini, event indekslerini, canonical telemetry
özelliklerini, geometri mesafesini, heading değişimini ve trafik bağlamını
kullanır. Aynı canonical telemetry ve Phase 2 analizi her çalıştırmada aynı
sonucu verir.

## 150 puan dağılımı

| Bileşen | Maksimum | Yaklaşım |
| --- | ---: | --- |
| Hız Koruma | 60 | Entry–apex hız kaybını, heading değişimi ve yaklaşık yarıçaptan türetilen keskinlik bağlamında değerlendirir. |
| Giriş Kalitesi | 35 | Entry bölümündeki hız profilinin kararlılığını ölçer; fren şiddetini tekrar puanlamaz. |
| Çıkış Kalitesi | 35 | Apex sonrası entry hızına kontrollü toparlanmayı ölçer; entry üstü hızlanma için ek bonus vermez. |
| Viraj İçi Stabilite | 20 | Viraj boyunca canonical hız varyasyonunu ölçer. |

Her bileşen kendi üst sınırına clamp edilir; toplam her zaman 0–150 arasındadır.

## Geometri ve keskinlik

`CornerEvent` içindeki korunmuş heading sırası ile toplam yön değişimi ve event
mesafesi kullanılarak yaklaşık yarıçap hesaplanır. Bu yarıçap ve heading
değişimi birlikte keskinlik oluşturur. Böylece geniş bir virajdaki büyük hız
kaybı ile dar virajdaki makul hız kaybı aynı biçimde yorumlanmaz. Gidiş yönü,
Phase 2 event geometrisinin sırasından korunur.

## Trafik ve overlap

Yüksek dense-traffic veya stop-and-go confidence ile düşük entry hızı bir
performans virajı olarak değerlendirilmez. Trafik bağlamında kalan uygun
virajlarda hız koruma kısmı kademeli olarak yumuşatılır; trafik binary bir
muafiyet değildir.

Corner ve deceleration event'leri çakışabilir. Skor motoru yalnızca primary
owner'ı `cornering` olan corner event'lerini kullanır; overlap kimliklerini
diagnostic contribution üzerinde korur. Entry profilinde fren şiddeti veya
braking quality yeniden puanlanmaz; böylece Phase 3 Frenleme & Öngörü motoruyla
çifte ceza oluşturulmaz.

## N/A ve örnek yeterliliği

Anlamlı, yeterli güvenliğe sahip bir performance corner yoksa sonuç `applicable
= false` olur ve 0/150 kullanıcının cezası anlamına gelmez. Tek uygun corner
analiz edilir ancak `sampleSufficient = false` diagnostic'i taşır; iki veya daha
fazla uygun corner daha yeterli örnek kabul edilir.

## Lateral G

Bu faz lateral G üretmez veya puan vermez. Yüksek lateral G hiçbir zaman bonus
değildir. İleride güvenilir telemetri mevcutsa lateral G yalnızca viraj bağlamı
ve zorluk yorumunda kullanılabilir.

## Kalibrasyon

Detection eşiklerinden ayrı `CorneringScoreCalibration` altında minimum
confidence, minimum entry speed/distance/heading, geniş-dar yarıçap referansları,
expected speed loss, profil varyans toleransları, exit penceresi ve trafik
yumuşatma parametreleri tutulur. 60/35/35/20 anayasal ağırlıkları sabittir.

## Persistence

Corner score sonuçları Hive'a yazılmaz. Canonical telemetry ve Phase 2
event'leri üzerinden offline olarak yeniden üretilebildikleri için bu fazda yeni
typeId, HiveField veya migration gerekmemiştir.

## Test kapsamı

Sentetik testler; geniş/dar viraj bağlamını, temiz ve aşırı hız kaybını, giriş
yığılmasını, çıkış toparlanmasını, stabilite farkını, düşük hızlı trafik
hariç tutmayı, viraj+yavaşlama overlap'ını, N/A davranışını, çoklu viraj
toplamını ve determinismi doğrular.

## Bilinen sınırlar ve sonraki faz

Yaklaşık yarıçap GPS/heading geometrisinden türetilir; yolun fiziksel eğriliği
veya aracın gerçek lateral G ölçümü değildir. Sürüş koşulları için harici yol
verisi kullanılmaz. Phase 6, bu sonuçlara dokunmadan yalnızca Sürüş Akıcılığı,
Hızlanma & Gaz Performansı ve Geçiş Kontrolü için ortak event altyapısını
kullanabilir.
