# Drive Score Phase 2 Walkthrough

## Kapsam

Bu faz, Phase 1 canonical telemetrisini puan üretmeden sürüş fazlarına, trafik
bağlamına ve ortak event'lere dönüştürür. Drive Score kategori ağırlıkları,
cezalar, ödüller, final 0–1000 skor, UI ve World davranışları değiştirilmemiştir.

## Oluşturulan phase/state modeli

Longitudinal ana fazlar şunlardır:

- `unknown`
- `stopped`
- `accelerating`
- `cruising`
- `decelerating`

`cornering`, longitudinal fazın yanında bulunabilen ortogonal bağlamdır. Bu
sebeple normal `phaseTimeline` longitudinal olarak tek değerlidir;
`corneringTimeline` ise aynı zaman aralığında viraj bilgisini ayrıca taşır.
Örneğin bir örnek hem `decelerating` ana fazında hem `cornering` bağlamında
olabilir. `stopped` ve `cruising`, ayrıca `accelerating` ve `decelerating` aynı
anda ana faz olamaz.

Fazlar tek örnekle açılmaz. Candidate aralığı minimum süre ve anlamlı hız
kazanımı/kaybı şartlarını sağladığında başlangıç noktasına geri dönük olarak
onaylanır. Enter/exit eşikleri ile bir saniyelik çıkış toleransı eşik çevresi
flicker'ını engeller.

## Feature extraction

`DriveFeatureExtractor`, detector'ların canonical örnekleri ayrı ayrı yeniden
yorumlamasını önleyen ortak türetilmiş özellikleri üretir:

- rolling mean speed ve speed variance,
- canonical acceleration üzerinden EMA ile smoothed acceleration,
- shortest-angle heading delta ve heading change rate,
- rolling low-speed ratio,
- kesintisiz stationary ve moving duration.

Feature çıkarımı tek geçişlidir. Rastgelelik, duvar saati veya platforma bağlı
durum kullanılmaz.

## Detection calibration

Tüm detection eşikleri `DriveDetectionCalibration` içinde merkezidir:

- stop adayı: en fazla 5 km/s, en az 3 saniye ve en fazla 8 metre drift,
- acceleration giriş/çıkış: +0.35 / +0.15 m/s², en az 1.5 saniye ve 2 m/s hız
  kazanımı,
- deceleration giriş/çıkış: -0.35 / -0.15 m/s², en az 1.5 saniye ve 2 m/s hız
  kaybı,
- cruise: en az 5 m/s, |acceleration| en fazla 0.3 m/s², hız varyansı en fazla
  1.5 ve en az 5 saniye,
- corner: en az 4 m/s, giriş/çıkış heading rate 4/2 derece/saniye, en az 15
  derece toplam dönüş, 15 metre ve 2 saniye,
- traffic window: 45 saniye; minimum anlamlı gözlem 8 saniye.

Bu değerler score eşikleri veya kategori ağırlıkları değildir. Gerçek sürüş
fixture'larıyla sonraki kalibrasyonlarda merkezi olarak ayarlanabilir.

## Traffic regime yaklaşımı

Her canonical örnek için son 45 saniyeye kadar olan pencere değerlendirilir.
Pencereden şu sinyaller çıkarılır:

- ortalama hız ve hız varyansı,
- düşük hız oranı,
- duruş oranı,
- duruş/hareket geçiş yoğunluğu,
- acceleration/deceleration yön değişim yoğunluğu.

Sonuç kesin bir trafik iddiası değildir. `denseTrafficConfidence` ve
`stopAndGoConfidence` 0–1 aralığında saklanır. Yeterli gözlem yoksa `unknown`,
stop/go confidence yüksekse `stopAndGo`, düşük hız yoğunluğu baskınsa
`denseTraffic`, aksi durumda `freeFlow` üretilir. Bu confidence değerleri bu
fazda hiçbir cezayı azaltmaz veya puan üretmez.

## Event modeli

Tek `DrivingEvent` modeli şu tipleri destekler:

- `stop`
- `acceleration`
- `deceleration`
- `corner`
- `cruise`

Her event deterministik id, DriveSession id, başlangıç/bitiş zamanı ve indeksi,
süre, başlangıç/bitiş/minimum/maksimum hız, mesafe, confidence, traffic context,
ownership ve overlap metadata taşır. Corner event ayrıca toplam heading değişimi
ve apex indeksini metadata olarak içerir.

## Ownership ve overlap

Event'ler zaman açısından çakışabilir; çakışma silinmez. Her event'in:

- tek `primaryOwner` alanı,
- ileride değerlendirebilecek domain'leri gösteren `ownershipEligibility`,
- context tag'leri,
- deterministik `overlappingEventIds` referansları

vardır. Örneğin viraj içi yavaşlamada corner event'in ana sahibi `cornering`,
deceleration event'in ana sahibi `braking` olarak ayrı kalır. Her iki event
birbirini overlap/context olarak bilir. Böylece Phase 3 ve sonraki motorlar aynı
negatif ivmeyi otomatik olarak iki ayrı hata kabul etmek yerine ortak bağlamı
görebilir. Bu faz herhangi bir ceza kararı vermemektedir.

## Live ve offline kullanım

`DrivePhaseAnalyzer.analyze`, kalıcı canonical telemetry listesini O(n)'e yakın
tek geçişli feature/detection hattında analiz eder. Trafik penceresi süre olarak
sınırlıdır; tüm geçmiş tekrar tekrar taranmaz.

`DrivePhaseAnalysisSession`, canlı canonical noktaları toplar ve oturum
tamamlandığında aynı analyzer'ı çağırır. Canlı ve offline kullanım için ayrı
eşik veya detector kodu yoktur; aynı input aynı sonucu üretir. Phase 2 henüz
analiz sonucunu canlı UI'a bağlamaz.

## Persistence kararı

Event ve faz timeline'ları Hive'a yazılmamıştır. Bunlar Phase 1'de sürümlü ve
kalıcı tutulan canonical telemetriden deterministik olarak yeniden üretilebilir.
Bu tercih:

- yeni typeId/box ve migration riskini önler,
- detector kalibrasyonu değiştiğinde yeniden analiz sağlar,
- eski DriveSession/RoutePoint/My World şemalarını değiştirmez.

## Test sonuçları

Phase 2 sentetik testleri aşağıdaki davranışları doğrular:

- stabil yüksek hızlı cruise ve free flow,
- temiz acceleration ve kontrollü deceleration,
- deceleration ardından doğrulanmış stop,
- duruşta GPS drift'inin sahte hareket üretmemesi,
- stop-and-go ve dense traffic confidence,
- düzenli heading değişiminde corner ve tek spike'ta corner oluşmaması,
- corner + deceleration overlap ve ayrı primary owner,
- eşik flicker'ının event split üretmemesi,
- determinism,
- live collector ile offline analyzer eşdeğerliği.

Phase 2 testleri: **13/13 geçti**.

Tüm repository testleri: **71/71 geçti**.

`flutter analyze`: Phase 2 kaynaklı error veya warning yoktur. Repository'de
önceden bulunan 5 info devam etmektedir: `home_screen.dart` içinde iki stil
bilgisi, `map_screen.dart` içinde deprecated `WillPopScope` ve bir stil bilgisi,
`route_preview.dart` içinde deprecated `withOpacity`.

`git diff --check`: geçti.

## Bilinen sınırlamalar

- GPS tek başına trafik nedenini kesin bilemez; rejimler confidence bağlamıdır.
- Pedal, IMU ve yol geometrisi olmadığı için acceleration/deceleration niyeti
  veya viraj kalitesi bu fazda yorumlanmaz.
- Corner radius ve lateral G hesaplanmaz; heading + zaman + mesafe sürekliliği
  kullanılır.
- Live session ara sonuç yayınlamaz; aynı motorla final snapshot üretir.
- Event confidence başlangıç kalibrasyonudur ve gerçek cihaz fixture'larıyla
  doğrulanmalıdır.

## Phase 3 hazırlığı

Phase 3 Frenleme & Öngörü motoru için aşağıdaki veriler hazırdır:

- zaman sınırları belli deceleration ve stop event'leri,
- event öncesi/sonrası canonical timeline'a indeks erişimi,
- smoothed acceleration ve hız feature'ları,
- traffic regime/confidence bağlamı,
- corner overlap bilgisi,
- primary ownership metadata,
- tek örneklik kararları engelleyen hysteresis/minimum süre altyapısı.

Phase 3 bu event'leri tüketmeli; ham canonical telemetriyi bağımsız eşiklerle
yeniden tarayan ikinci bir fren detector oluşturmamalıdır.
