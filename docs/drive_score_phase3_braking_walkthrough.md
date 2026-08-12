# Drive Score Phase 3 — Frenleme & Öngörü Walkthrough

## Kapsam

Bu faz yalnızca Drive Score Anayasası'ndaki 350 puanlık **Frenleme &
Öngörü** kategorisini uygular. Tempo, viraj performansı, dayanıklılık,
akıcılık, hızlanma/gaz, geçiş kontrolü ve nihai 0–1000 Drive Score bu fazda
hesaplanmaz. UI, Hive şeması, DriveSession ve World sistemi değiştirilmemiştir.

## Mimari

`BrakingScoreEngine`, Phase 1'in kalıcı canonical telemetrisi üzerinden
üretilmiş Phase 2 `DrivePhaseAnalysisResult` değerini tüketir. Yeni bir fren
detector'ı oluşturmaz. Ana girdiler:

- `deceleration`, `stop`, `acceleration` ve `corner` event'leri,
- indekslenmiş canonical feature'lar (canonical/smoothed acceleration ve hız),
- trafik context/confidence,
- event owner, context tag ve overlap metadata'sıdır.

Sonuç `BrakingScoreResult` ile yalnızca runtime/offline analiz sonucu olarak
döner. Sonuç deterministiktir ve Hive'a yazılmaz.

## 150 / 100 / 60 / 40 hesabı

### Öngörülü Frenleme — 150

Her geçerli braking-owner `deceleration` event'i için 0–1 kalite üretilir.
Kalite; olayın ilk yarısındaki hız kaybı/erken yavaşlama, smoothed
acceleration düzgünlüğü ve hız kaybının son bölüme yığılmaması üzerinden
oluşur. Olaydan önceki beş saniyede hafif/istikrarlı coasting görülmesi küçük
bir erkenlik katkısı sağlar. Event kaliteleri, anlamlı hız kaybına göre
ağırlıklandırılır.

### Fren Şiddeti — 100

Canonical ve smoothed acceleration içinden event'in en güçlü güvenilir negatif
ivmesi alınır. `0→-1.5`, `-1.5→-2.5`, `-2.5→-3.5`, `-3.5→-5.0` ve `-5.0+`
m/s² bantları parça-parça doğrusal biçimde ceza üretir; eşiklerde cliff yoktur.
Tek event'te ceza, acil durum belirsizliği nedeniyle sınırlıdır. Tekrarlayan
sert event'lerde ise tekrar çarpanı uygulanır.

### Fren–Gaz Kararsızlığı — 60

Phase 2 acceleration event'inden sonra dinamik bir pencerede gelen braking
owner deceleration aranır. Pencere hızla kısalır: düşük hızda 14 sn, orta
hızda 10.5 sn, yüksek hızda 7.5 sn. Yalnızca anlamlı hız kazanımı sonrası geri
alınan hız pattern'i dikkate alınır. Tek cycle çok sınırlı etki taşır;
tekrarlayan cycle'lar daha güçlü etki taşır. Acceleration event'i bu fazda
başka bir kategori gibi ayrıca puanlanmaz.

### Duruş Kalitesi — 40

Sadece anlamlı yaklaşma hızı yaklaşık 15 km/s üstüne çıkan stop event'leri
değerlendirilir. Son iki saniyedeki hız kaybının yığılması ve smoothed
acceleration düzgünlüğü ölçülür. `4→0→3→0` gibi düşük hızlı sürünmeler
değerlendirme dışıdır. Aynı duruşa bağlı event acil/çok sert fren olarak
işaretlendiyse Duruş Kalitesi yeniden ceza üretmez.

## Traffic handling

Phase 2'nin `denseTrafficConfidence` ve `stopAndGoConfidence` değerleri
kademeli kullanılır. Dense/stop-and-go bağlamı fren şiddeti ve öngörüdeki
cezayı yumuşatır; kötü kontrol tamamen yok sayılmaz. Fren–gaz kararsızlığında
traffic suppression daha kuvvetlidir: confidence yükseldikçe yaklaşık %80–100
aralığına kadar ceza bastırılır. Binary trafik kararları kullanılmaz.

## Emergency, ownership ve corner overlap

Tek bir `-5 m/s²` ve altı güçlü event emergency/uncertain sayılır ve tek olay
olarak Fren Şiddeti bölümünü sıfırlayamaz. Aynı event'e bağlı Duruş Kalitesi
analizi dışarıda tutulur.

`DrivingEvent.primaryOwner`, `contextTags` ve `overlappingEventIds` aktif
olarak kullanılır. Corner ile çakışan yavaşlama, geometrik viraj bağlamı
olarak tanınır; fren cezası yumuşatılır. Corner event'i bununla birlikte
viraj kategorisine ait olmayı sürdürür; Phase 3 viraj puanı üretmez.

## N/A normalization

Yeterli deceleration, stop veya brake-throttle pattern'i olmayan sürüşler
ilgili alt kategoriden cezalandırılmaz. İlgili component "not applicable"
olarak diagnostics'te işaretlenir ve kendi maksimum nötr değerini korur.
Böylece stop yapmayan bir otoyol sürüşü yalnızca `Stopping Quality = 0`
olduğu için düşük Frenleme skoru almaz. Sonucun üst sınırı her zaman 350'dir.

## Kalibrasyon

Tüm Phase 3 parametreleri
`lib/features/drive_score/config/braking_score_calibration.dart` içindedir.
Anayasal kategori üst sınırları sabittir: 150 / 100 / 60 / 40. Diğer eşikler,
gerçek cihaz fixture'larıyla ileride merkezî olarak kalibre edilebilecek
başlangıç değerleridir.

## Testler

`test/braking_score_engine_test.dart` şu sentetik davranışları doğrular:

- öngörülü duruşun son anda yığılmaya göre daha iyi olması,
- tek acil fren koruması,
- tekrar eden sert frenlerin daha güçlü etkisi,
- stop-and-go baskılaması,
- açık yoldaki tekrar eden brake-throttle cycle,
- düşük hızlı sürünmenin stop-quality'yi kirletmemesi,
- corner + deceleration overlap,
- fren/duruş olmayan sürüşte N/A normalization,
- determinism ve skor sınırları.

## Bilinen sınırlamalar

- GPS telemetrisi fren pedalını, öndeki tehlikeyi veya gerçek yol koşullarını
  kesin olarak vermez; emergency/traffic/corner yaklaşımı ihtiyatlı context
  kullanır.
- Gerçek cihaz sürüş fixture'larıyla kalibrasyon henüz yapılmamıştır.
- Sonuç Hive'a yazılmaz; final 1000 motoru ve skor versiyonlama sonraki
  fazların işidir.

## Phase 4 hazırlığı

Canonical speed, distance, duration, stop context ve doğrulanmış maksimum
hızın filtrelenmiş kaynağı Tempo & Performans — 150 puan motoru için hazırdır.
Bu motorun Phase 3 sonucu ile birleştirilmesi veya final 1000 score
oluşturulması bu fazda yapılmamıştır.
