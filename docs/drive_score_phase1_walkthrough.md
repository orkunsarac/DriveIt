# Drive Score Phase 1 Walkthrough

## Kapsam

Bu faz yalnızca Drive Score v1.0 için canonical telemetri ve kalıcı veri temelini
hazırlar. Yeni skor formülü, kategori puanları, trafik rejimi, fren/hızlanma/viraj
olayları, cruise/geçiş tespiti ve World skor davranışları eklenmemiştir.

## Önceki telemetri mimarisi

- `MapScreen` ile foreground `DriveTaskHandler` ayrı konum akışları tüketiyordu.
- Canlı hız `SpeedService`, rota/mesafe `RouteService`, sürüş sonu metrikleri ise
  `DriveTelemetryAnalyzer` tarafından farklı filtrelerle hesaplanıyordu.
- Foreground görev latitude, longitude, timestamp, speed, heading, altitude ve
  accuracy değerlerini geçici JSON verisi olarak tutuyordu.
- Kalıcı `RoutePoint` yalnızca latitude ve longitude içeriyordu. Zengin telemetri
  sürüş kaydedildikten sonra yeniden analiz edilemiyordu.

## Tespit edilen temel problemler

- Aynı ham GPS örneği hız, rota ve analiz katmanlarında farklı doğrulama
  kararları alabiliyordu.
- Tek örneklik hız/konum sıçramaları maksimum hız, ivme ve mesafeyi farklı
  biçimlerde etkileyebiliyordu.
- Düşük hızdaki GPS drift'i rota ve mesafeyi şişirebiliyordu.
- Timestamp, speed, heading, altitude, accuracy, mesafe deltası ve acceleration
  zaman serisi kalıcı değildi.
- Gelecekte geçmiş sürüşleri aynı algoritmayla yeniden analiz edecek sürümlü bir
  telemetri kaydı yoktu.

## Yapılan değişiklikler

- `CanonicalTelemetryPipeline` tek sürüşe ait ham konumları sıralı biçimde
  doğrulayan merkezi hat olarak eklendi.
- Foreground görev, rota için kaydedilen örnekleri bu hattan geçirir. UI'ın ayrı
  konum akışı yalnızca canlı marker/kamera gösterimi içindir; mesafe, hız, rota ve
  analiz için foreground'dan gelen canonical örnekler kullanılır.
- `RouteService.addCanonicalPoint` canonical mesafe deltasını tek mesafe kaynağı
  olarak kullanır ve duruş drift'ini rota geometrisine eklemez.
- `CanonicalTelemetryPoint` ve sürümlü `DriveTelemetryRecord` eklendi.
- Canonical zaman serisi sürüş kaydedilirken ayrı Hive kutusuna yazılır; sürüş
  silindiğinde ilişkili telemetri kaydı da silinir.
- Telemetri yazımı başarısız olursa normal sürüş kaydı yarım bırakılmaz; sürüş
  kaydı başarısız olursa o denemede yazılan telemetri temizlenir.

## Canonical pipeline akışı

`Position` ham girdisi aşağıdaki sırayla işlenir:

1. Koordinat, timestamp ve accuracy doğrulaması.
2. Timestamp sırası ve en küçük örnek aralığı kontrolü.
3. Ardışık koordinatlardan geometrik hız ve imkânsız konum sıçraması kontrolü.
4. Native GPS speed'in birim ve fiziksel sınır doğrulaması; gerektiğinde
   geometrik hız fallback'i.
5. Beş örnekli median pencereyle tek örneklik speed spike bastırma.
6. Canonical hız farkı ve gerçek timestamp farkıyla acceleration türetme.
7. Hareket anchor'ına göre tek canonical distance delta üretme ve duruş drift'ini
   bastırma.
8. Düşük hızda son güvenilir heading'i koruma; gerektiğinde koordinatlardan
   bearing fallback'i ve shortest-angle yumuşatma.

Kalibrasyon değerleri `CanonicalTelemetryRules` içinde merkezidir. Bunlar veri
kalitesi kurallarıdır; Drive Score eşiği veya kategori puanı değildir.

## Güvenilir ve kalıcı telemetri

Her kabul edilen canonical örnekte SI birimleriyle şu alanlar saklanır:

- latitude / longitude
- timestamp
- speed (m/s)
- heading (derece)
- altitude (metre)
- accuracy (metre)
- distance from previous accepted movement anchor (metre)
- acceleration (m/s²)

`DriveTelemetryRecord.dataVersion` başlangıçta `1` olarak tutulur. Bu sürüm
canonical veri sözleşmesini ayırır; henüz hesaplanmayan Drive Score için sahte bir
`scoreAlgorithmVersion` veya skor alanı eklenmemiştir.

## Hive geriye dönük uyumluluk

- Mevcut `DriveSession` typeId `0`, `RoutePoint` typeId `1`, alan numaraları ve
  `drives` kutusu değiştirilmedi.
- Eski Flow alanları için ayrılmış DriveSession field numaraları yeniden
  kullanılmadı.
- My World typeId aralığı `10–18` korunmuştur.
- Yeni canonical point typeId `2`, telemetry record typeId `3` ve ayrı
  `drive_telemetry` kutusu kullanır.
- Yeni adapter'lar eksik yeni alanlar için güvenli varsayılanlar sağlar.
- Eski sürüşler zengin telemetri kaydı olmadan önceki biçimleriyle okunmaya devam
  eder; geriye dönük olarak uydurma telemetri oluşturulmaz.

## Doğrulama sonuçları

- Canonical pipeline testleri: missing/invalid timestamp, kötü accuracy, speed
  spike, duruş drift'i, gerçek dt ile acceleration, düşük hız heading kararlılığı
  ve deterministik çıktı doğrulandı.
- Hive testleri: yeni telemetry round-trip'i, eski RoutePoint round-trip'i ve
  typeId çakışmazlığı doğrulandı.
- Legacy DriveSession adapter testi dahil tüm test paketi: **58 test geçti**.
- `flutter analyze`: **0 error, 0 warning**. Bu fazdan önce de bulunan beş adet
  `info` seviyesi bulgu devam ediyor (`home_screen.dart` iki stil bilgisi,
  `map_screen.dart` bir deprecated `WillPopScope` ve bir stil bilgisi,
  `route_preview.dart` bir deprecated `withOpacity`). Phase 1 yeni analyze
  bulgusu eklemedi.
- `git diff --check`: geçti.

## Phase 2 için kalanlar

Canonical zaman serisi artık rejim ve olay analizinin ihtiyaç duyacağı temel
alanlarla kalıcıdır. Buna rağmen aşağıdakiler bilinçli olarak yapılmamıştır:

- trafik confidence ve sürüş rejimleri,
- frenleme, hızlanma, viraj, cruise, duruş ve geçiş event/state detector'ları,
- event ownership ve çift ceza önleme,
- anayasal kategori puanları ve 0–1000 final score,
- score algorithm version persistence,
- World lokal skor veya sahiplik değişiklikleri.

Phase 2 bu canonical veriyi tüketebilir; ham GPS için ikinci bir bağımsız
doğrulama hattı oluşturmamalıdır.
