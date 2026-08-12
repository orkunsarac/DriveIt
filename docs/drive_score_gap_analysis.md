# DriveIt Drive Score Gap Analysis

## 1. Kapsam ve kaynak

Bu rapor, `docs/drive_score_constitution.md` dosyasını nihai ve bağlayıcı ürün
spesifikasyonu kabul ederek mevcut DriveIt kod tabanı ile anayasa arasındaki
farkları inceler. Bu aşamada kaynak kod, Hive şeması, testler ve kullanıcı
arayüzü değiştirilmemiştir.

Durum sınıfları:

- **READY:** Mevcut yapı anayasanın ilgili ihtiyacını doğrudan karşılıyor.
- **PARTIAL:** Kullanılabilir bir temel var fakat anayasal davranış tamamlanmış
  değil.
- **MISSING:** İlgili davranış veya veri hattı bulunmuyor.
- **CONFLICT:** Mevcut davranış anayasanın kuralıyla çelişiyor veya aynı adla
  farklı bir anlam taşıyor.

## 2. Yönetici özeti

Mevcut repository'de çalışan bir Drive Score motoru yoktur. 0–1000 toplam
puan, yedi anayasal kategori, kategori puan dökümleri, skor sürümü ve skorun
`DriveSession` içine kaydı bulunmaz. Ana ekrandaki “Sürüş Skoru” ile son sürüş
kartındaki “Sürüş Puanı” alanları `-`, `Yok` veya `—` gösteren UI yer
tutucularıdır.

Buna karşılık yeni motor için yararlı bir canlı telemetri temeli vardır:

- yaklaşık 500 ms hedef aralıklı konum örnekleme,
- latitude, longitude, timestamp, GPS speed, heading, altitude ve accuracy,
- doğruluk, hız, koordinat sıçraması ve ivme için ilk filtreler,
- sert fren/hızlanma sayıları,
- basit viraj sayımı,
- duruş sayısı ve duruş süresi,
- klasik ortalama, hareket zamanı çıkarılmış seyir ortalaması, maksimum hız,
  mesafe ve toplam süre.

En kritik mimari açık, zengin `DriveTelemetrySample` dizisinin yalnızca aktif
sürüş sırasında bellekte tutulması ve kayıt öncesinde özet `DriveMetrics`
değerlerine indirgenmesidir. Kalıcı `RoutePoint` yalnızca latitude ve longitude
içerir. Bu nedenle kayıtlı eski sürüşlerde fren olay pencereleri, trafik rejimi,
seyir periyotları, faz geçişleri ve lokal yol skoru yeniden üretilemez.

Hazırlık oranı tek sayı ile yanıltıcı olabilir. Ayrıştırılmış değerlendirme:

- Canlı telemetri toplama temeli: yaklaşık **%65 hazır**.
- Güvenilir ortak olay/rejim analizi: yaklaşık **%20 hazır**.
- Anayasal kategori puanları ve 1000 puan birleştirmesi: **%0 hazır**.
- Geçmiş sürüşleri yeniden puanlayabilme: yaklaşık **%15 hazır**.
- Genel üretim hazırlığı: yaklaşık **%30**.

## 3. Mevcut sistem haritası

### 3.1 Drive Score'un mevcut durumu

| Soru | Bulgular |
| --- | --- |
| Skor nerede hesaplanıyor? | Hesaplanmıyor. Repository'de Drive Score calculator/service/function bulunmuyor. |
| Mevcut 1000 puan dağılımı nedir? | Yok. Anayasadaki 350/150/150/150/100/50/50 dağılımının kod karşılığı bulunmuyor. |
| Skor ne zaman hesaplanıyor? | Hiçbir aşamada hesaplanmıyor. Sürüş bitiminde yalnızca `DriveTelemetryAnalyzer.analyze` çağrılıyor ve `DriveMetrics` üretiliyor. |
| Skor `DriveSession` içine nasıl kaydediliyor? | Kaydedilmiyor; `DriveSession` içinde toplam skor, kategori puanları veya skor sürümü alanı yok. |
| Skoru hangi sistemler kullanıyor? | Hiçbir çalışma zamanı sistemi kullanmıyor. Home UI puan alanları yer tutucu. My World sistemi yalnızca `readyForWorldProcessing` durumuna kadar ilerliyor ve puan kullanmıyor. |

İlgili mevcut dosyalar:

- `lib/services/drive_telemetry_analyzer.dart`: filtrelenmiş örneklerden özet
  sürüş metrikleri üretir; puan üretmez.
- `lib/models/drive_metrics.dart`: sayım ve maksimum/minimum ölçümleri taşır;
  kategori puanı taşımaz.
- `lib/models/drive_session.dart`: sürüş özeti ile bazı analiz metriklerini
  saklar; skor alanı yoktur.
- `lib/widgets/drive_summary_dialog.dart`: mevcut ölçümleri gösterir ve
  kullanıcı kaydederse `DriveSession` oluşturur.
- `lib/screens/home_screen.dart`: skor alanlarını sabit yer tutucu olarak
  gösterir.

### 3.2 Telemetri envanteri

| Veri | Canlı sürüşte | Kalıcı DriveSession'da | Durum ve not |
| --- | --- | --- | --- |
| latitude | Var | `RoutePoint.latitude` | **READY** koordinat izi için; zengin örnek bağı kayboluyor. |
| longitude | Var | `RoutePoint.longitude` | **READY** koordinat izi için; zengin örnek bağı kayboluyor. |
| timestamp | Var (`Position.timestamp`) | Yok | **PARTIAL** yalnızca aktif sürüş/bellek ve foreground JSON içinde. Kayıttan sonra yeniden analiz edilemez. |
| speed | Var (`Position.speed`, m/s) | Yalnızca özet `averageSpeed` ve `maxSpeed` | **PARTIAL** zaman serisi kaydedilmiyor. |
| heading | Var | Yok | **PARTIAL** canlı viraj analizi mümkün; geçmişte yeniden üretilemez. |
| altitude | Var | Yalnızca max/gain/loss özetleri | **PARTIAL** örnek zaman serisi kaydedilmiyor. |
| accuracy | Var | Yok | **PARTIAL** canlı filtre var; kaydedilmiş rota noktasının güveni bilinmiyor. |
| distanceFromPrevious | Model alanı olarak yok | Yok | **Dolaylı hesaplanabilir**: ardışık koordinatlardan hesaplanabilir. Kalıcı rotada timestamp olmadığı için hız/zaman bağlamı kurulamaz. |
| acceleration | Ham alan olarak yok | Yalnızca max acceleration/braking G | **Dolaylı hesaplanabilir**: filtrelenmiş hız farkı / zaman farkı. Olay serisi kaydedilmiyor. |
| duruş sayısı | Foreground görevinde türetiliyor | `stopCount` | **PARTIAL** özet var; duruş başlangıç/bitiş olayları yok. |
| duruş süresi | Foreground görevinde türetiliyor | `stoppedSeconds` | **PARTIAL** toplam var; tekil duruş süreleri yok. |
| sert fren/hızlanma | Analyzer'da türetiliyor | Sayımlar | **PARTIAL** olay kimliği, zamanı, şiddet eğrisi ve bağlam yok. |
| viraj | Heading deltasından türetiliyor | Sayım, keskin sayım, max viraj hızı | **PARTIAL** viraj sınırları, yarıçap, giriş/çıkış ve stabilite yok. |
| 0–100 / 60–100 | Analyzer'da türetiliyor | Nullable en iyi süreler | **READY** mevcut özeti için; anayasanın hareketli hızlanma pencereleri için genelleştirilmiş değil. |

`DriveTelemetrySample` şu alanları gerçekten içerir: latitude, longitude,
speedMps, accuracyMeters, heading, altitudeMeters ve timestamp. Dosya yorumu bu
örneklerin kalıcı olmadığını ve kayıttan önce `DriveMetrics` değerlerine
indirgendiklerini açıkça belirtir.

### 3.3 Sürüş yaşam döngüsü

Mevcut akış:

1. **Sürüş merkezini açma** — `DriveCenterScreen`, aktif foreground sürüşü
   kontrol ederek `MapScreen(resumeDrive: ...)` açar.
2. **Başlatma** — `MapScreen.startDriving` geri sayımdan sonra
   `_startDrivingSession` çağırır.
3. **Foreground kayıt** — `ForegroundService.start`, `DriveTaskHandler`
   üzerinden konum servisinin ve kalıcı bildirimin çalışmasını başlatır.
4. **GPS örnekleme** — Hem `MapScreen` hem `DriveTaskHandler`, Android'de
   `bestForNavigation`, `distanceFilter: 0`, hedef `500 ms` ayarıyla ayrı konum
   akışları açar.
5. **Canlı telemetri** — `MapScreen._recordTelemetry` UI akışındaki bütün
   örnekleri `_telemetrySamples` listesine ekler. Foreground görevinden gelen
   kayıtlar `_recordBackgroundTelemetry` ile aynı listeye alınır.
6. **Rota ve mesafe** — `RouteService` accuracy >30 m, <3 m drift ve >120 m
   sıçramaları dışarıda bırakıp kabul edilen koordinatlardan rota/mesafe üretir.
7. **Anlık/maksimum hız** — `SpeedService` 10 m hareket kapısı, 3 saniye duruş
   kararı ve beş örnekli median hız penceresi kullanır.
8. **Duruş** — `DriveTaskHandler`, 10 m hareket çapası ve 3 saniye teyitle
   stopCount/stoppedSeconds üretir.
9. **Sürüş bitişi** — `MapScreen.stopDriving` foreground verisini son kez
   birleştirir, toplam süreyi duvar saatinden, klasik ortalamayı rota
   mesafesi/toplam süreden hesaplar.
10. **Analiz** — `DriveTelemetryAnalyzer.analyze(_telemetrySamples)` özet
    `DriveMetrics` üretir.
11. **Özet ve kullanıcı kararı** — `DriveSummaryDialog` ölçümleri gösterir.
12. **Hive kaydı** — Kullanıcı “Sürüşü Kaydet” dediğinde dialog
    `DriveSession` oluşturur ve `DriveStorageService.saveDrive` çağırır.
13. **İkincil Dünya kuyruğu** — Sürüş başarıyla kaydedildikten sonra
    `MyWorldRuntime.enqueueSavedDrive` best-effort çalışır; hata sürüş kaydını
    bozmaz.
14. **UI tüketimi** — `HistoryScreen`, `DriveDetailScreen`, home kartları ve
    replay ekranı kaydedilen özet/rotayı okur.

## 4. Kategori bazında anayasa karşılaştırması

### A. Frenleme & Öngörü — 350

#### A1. Öngörülü Frenleme — 150

- **Durum:** MISSING.
- **Mevcut destek:** Negatif ivme hesaplanabiliyor ve en yüksek fren G değeri
  çıkarılıyor; fakat yalnızca eşik olayı/sayımı var.
- **Telemetri:** Canlı sürüş sırasında hız ve timestamp yeterli bir başlangıç
  sağlar. Kalıcı sürüşte olay zaman serisi yoktur.
- **Gereken:** Fren olayı öncesi 5 saniye + olay + sonrası 3 saniye penceresi,
  hız kaybının başlama zamanı, düzgünlük, son-yığılma ve normal duruş bağlantısı.
- **Trafik rejimi:** Gerekli. GPS tek başına frenin nedenini kesin açıklamaz;
  trafik yalnızca güven/confidence üretmelidir.
- **Olay analizi:** Gerekli. Tek örnek veya yalnızca minimum ivme yeterli değil.
- **Çakışma:** Mevcut `hardBrakeMps2 = -3` yalnızca sert fren sayar;
  anayasanın yaklaşık -0.7 m/s² ve 1–1.5 saniye süreyle başlayan daha geniş
  yavaşlama olayı tanımını karşılamaz.

#### A2. Fren Şiddeti — 100

- **Durum:** PARTIAL.
- **Mevcut destek:** Median hız, ivme sınırı, hard-brake hysteresis,
  `hardBrakeCount` ve `maxBrakingG` var.
- **Telemetri:** Canlı sürüşte yeterli başlangıç verisi vardır.
- **Gereken:** Kesintisiz şiddet eğrisi, olay süresi, tekrarlama ağırlığı,
  confidence ve tek GPS örneğinin ağır cezayı tetiklemesini engelleyen olay
  doğrulaması.
- **Trafik rejimi:** Şiddetin kendisini ortadan kaldırmamalı; olayın zorunlu
  olma ihtimalini ve tekrar paterni yorumlamak için gerekli.
- **Çakışma:** Mevcut tek `-3 m/s²` eşiği anayasanın kademeli
  0/−1.5/−2.5/−3.5/−5 sınıflandırmasını sağlamaz.

#### A3. Fren–Gaz Kararsızlığı — 60

- **Durum:** MISSING.
- **Mevcut destek:** Sert hızlanma ve sert fren yalnız ayrı sayılar olarak var.
- **Telemetri:** Canlı hız/ivme zaman serisi uygundur; kayıttan sonra yoktur.
- **Gereken:** Hız bandına göre 6–15 saniyelik dinamik pencereler, hızlanmanın
  kısa süre sonra geri alınması, tekrar sıklığı/şiddeti ve trafik confidence.
- **Trafik rejimi:** Zorunlu; yüksek trafik güveninde cezanın %80–100
  bastırılabilmesi gerekir.
- **Olay analizi:** Hızlanma ve fren olaylarını aynı sebep zincirine bağlayan
  event kimlikleri gerekir.

#### A4. Duruş Kalitesi — 40

- **Durum:** PARTIAL.
- **Mevcut destek:** Duruş sayısı/toplam süresi ve düşük hızın sıfırlanması var.
- **Telemetri:** Canlı örneklerle son 15 km/s → 0 bölümü incelenebilir; kalıcı
  veride yalnızca toplamlar vardır.
- **Gereken:** Tekil duruş olayları, son iki saniye ivme eğrisi, creep
  (3→0→4→0) bastırma, duruşlar arası tutarlılık.
- **Çifte puan riski:** Acil/sert fren ana olarak Fren Şiddeti'ne aitse aynı
  olay Duruş Kalitesi'nden yeniden ceza almamalıdır.

### B. Tempo & Performans — 150

#### B1. Ortalama Seyir Hızı — 60

- **Durum:** PARTIAL.
- `averageSpeed`, toplam mesafeyi toplam duvar süresine bölen klasik
  ortalamadır; duruşlar dahildir.
- `DriveSession.drivingAverageSpeed`, `durationSeconds - stoppedSeconds`
  kullanarak hareket ortalamasını türetir. Bu anayasal amaca yakındır.
- Fark: Anayasa başlangıçta 5 km/s altındaki örnek zamanlarını çıkarmayı tarif
  eder. Mevcut getter, 10 m/3 s duruş algoritmasının toplamına bağlıdır;
  düşük hızlı sürünme ve kısa duruşlarda aynı sonucu garanti etmez.
- Kalıcı ayrıntılı hız zaman serisi olmadığı için eski sürüşlerde örnek bazlı
  kesin seyir ortalaması yeniden üretilemez.

#### B2. Maksimum Hız — 30

- **Durum:** PARTIAL.
- `SpeedService`, accuracy filtresi, 10 m hareket kapısı, beş örnekli median,
  <3 km/s sıfırlama ve 350 km/s clamp kullanır.
- `DriveTelemetryAnalyzer` ayrıca 252 km/s örnek hızı, koordinattan 288 km/s
  ve ±8 m/s² ivme sınırları uygular; fakat analiz sonucu doğrulanmış maksimum
  hız üretmez ve kaydedilen `maxSpeed` hâlâ `SpeedService` değeridir.
- Gereken: Tek spike yerine süre/komşu örnek teyitli, ortak temiz telemetri
  hattından üretilen doğrulanmış maksimum.

#### B3. Mesafe / Süre Performansı — 60

- **Durum:** PARTIAL.
- Mesafe, `RouteService` tarafından kabul edilen koordinat deltalarından;
  toplam süre başlangıç ve bitiş `DateTime` farkından üretilir. Duruşlar süreye
  dahildir; bu anayasa ile uyumludur.
- Eksik: Aynı yol/benzer segment/geçmiş performans bağlamı yoktur. Salt mesafe
  ve süreye mutlak puan vermek anayasanın bağlamsal kıyas tercihini karşılamaz.
- Risk: Duvar saati değişiklikleri ve background/foreground rota birleşimi
  süre/mesafe tutarlılığını etkileyebilir.

### C. Viraj Performansı — 150

#### C1. Hız Koruma — 60

- **Durum:** MISSING.
- `maxCorneringSpeed` yalnız viraj sırasında görülen en büyük hızı saklar;
  giriş hızına göre momentum korunumu hesaplanmaz.
- Gerekli: Viraj başlangıç/apex/bitiş zamanları, giriş hızı ve geometriye göre
  beklenen hız kaybı.

#### C2. Giriş Kalitesi — 35

- **Durum:** MISSING.
- Basit heading toplamı viraj sayar fakat giriş fazı veya uygun giriş hızı
  üretmez.
- Gerekli: Viraj geometrisi/yaklaşık yarıçap, giriş penceresi ve fren olayıyla
  ortak event bağı. Fren tekniği burada tekrar cezalandırılmamalıdır.

#### C3. Çıkış Kalitesi — 35

- **Durum:** MISSING.
- Viraj sonrası kontrollü hız kazanımı ve seyire yerleşme tespit edilmiyor.
- Gerekli: Viraj bitişi, çıkış hız eğrisi ve sonraki stabil seyir başlangıcı.

#### C4. Viraj İçi Stabilite — 20

- **Durum:** MISSING.
- Viraj içinde hız varyasyonu hesaplanmıyor.
- Heading değişimleri canlı örneklerde vardır; yaklaşık yarıçap koordinat
  geometrisinden, lateral ivme ise `v²/r` ile dolaylı türetilebilir. Ancak
  mevcut analyzer yarıçap veya lateral G üretmez.
- Mevcut sistemle çakışma: “keskin viraj sayısı” ve “maksimum viraj hızı” tek
  başına kalite değildir. Yüksek lateral G veya mutlak viraj hızı doğrudan
  ödüllendirilemez.

### D. Sürüş Dayanıklılığı — 150

- **Durum:** MISSING.
- Toplam mesafe ve süre güvenilir bir başlangıç özeti olarak vardır.
- Uzun sürüş boyunca diğer kategorilerin kalite dağılımı, pencere bazlı
  tutarlılığı veya düşüşü tutulmaz.
- Mevcut final özetleri ile “mesafe × korunabilen kalite” hesaplanamaz; yalnızca
  kilometre eğrisi üretmek anayasa ile çelişir.
- 5 km–50 km–150+ km doygunlaşan eğri için mesafe yeterlidir, fakat eğrinin
  çarpılacağı pencere/segment kalite serisi eksiktir.
- Uzun kötü sürüşün aynı hatalarını tekrar ceza olarak yazmak yerine
  dayanıklılık pozitif potansiyelini kalite tutarlılığıyla sınırlandırmalıdır.

### E. Sürüş Akıcılığı — 100

- **Durum:** MISSING.
- Mevcut kodda seyir periyodu tespiti yoktur. Eski Flow Analysis alanları
  kaldırılmış ve Hive 8–11 alanları yeniden kullanılmamak üzere ayrılmıştır.
- Hız zaman serisi canlı sürüşte stabil periyotları hesaplamaya yeterlidir;
  fakat fren, belirgin hızlanma, viraj, duruş ve trafik pencerelerini dışarıda
  bırakmak için ortak faz/event modeli yoktur.
- Gereken: Hız bandına bağlı tolerans, minimum süre, bilinçli yeni hıza geçişte
  cezasız periyot kapanışı ve yalnız geçerli cruise sürelerinden skor.
- Akıcılık fren/hızlanma/viraj hatalarını yeniden puanlamamalıdır.

### F. Hızlanma & Gaz Performansı — 50

#### F1. Saf Hızlanma — 25

- **Durum:** PARTIAL.
- Pozitif ivme hız farkı/zaman farkından hesaplanıyor; hard acceleration
  sayısı, maksimum G, 0–100 ve 60–100 süreleri var.
- Eksik: 30→70, 50→100 gibi genelleştirilmiş hareketli pencere olayları,
  confidence ve kendi geçmişine göre karşılaştırma.
- Geçmiş kıyas için yalnız birkaç özet süre vardır; aynı hız bandındaki ham
  performans örnekleri ve araç/sürücü referans dağılımı yoktur.

#### F2. Gaz Uygulama Kalitesi — 15

- **Durum:** MISSING.
- Hızlanma boyunca gaz kesme/yeniden hızlanma kararsızlığı olay olarak
  çıkarılmıyor. Pedal verisi olmadığı için hız/ivme eğrisinden dolaylı ve
  confidence temelli çıkarım gerekir.

#### F3. Hızlanma Sonu Kontrolü — 10

- **Durum:** MISSING.
- Hedef hıza ulaştıktan sonra stabil seyire yerleşme tespit edilmiyor.
- Ortak acceleration→cruise event/state zinciri gereklidir.

### G. Geçiş Kontrolü — 50

#### G1. Seyir → Yavaşlama → Seyir — 20

- **Durum:** MISSING.
- Cruise ve deceleration fazları ortak state olarak temsil edilmiyor.

#### G2. Seyir → Viraj → Seyir — 20

- **Durum:** MISSING.
- Viraj sayımı var; fakat öncesi/sonrası seyir bağlantısı yoktur.

#### G3. Hızlanma → Seyir — 10

- **Durum:** MISSING.
- Hızlanma olayı ile sonraki stabil seyir aynı zincirde tutulmuyor.

Geçiş Kontrolü için ortak sürüş fazı state modeli ve event kimlikleri gerekir.
Bu kategori yalnız başarılı birleşimlere pozitif puan vermeli; başarısız geçişi
ayrı bir ceza olarak yazmamalıdır.

## 5. Trafik rejimi analizi

Repository'de serbest akış, yoğunlaşan trafik veya dur-kalk trafik sınıflayan
bir sistem yoktur. Mevcut `SpeedService` ve `DriveTaskHandler` yalnız
hareket/duruş kararı üretir; trafik nedeni veya confidence üretmez.

Mevcut canlı telemetri ile 30–60 saniyelik kayan pencerede aşağıdaki sinyaller
teknik olarak türetilebilir:

- ortalama ve medyan hareket hızı,
- hız varyasyonu ve düşük hızda geçirilen oran,
- duruş ve yeniden hareket olayları,
- fren/hızlanma olay yoğunluğu,
- kısa aralıklı hızlan→yavaşla döngüleri,
- hareket/duruş süre oranı.

Bunlardan kesin trafik etiketi değil, örneğin 0–1 arası `traffic confidence`
üretmek mümkündür. GPS; kırmızı ışık, öndeki araç, yol çalışması veya acil
durumu doğrudan göremez. Dolayısıyla confidence ceza bastırma/bağlam sinyali
olmalı, tek başına suçlayıcı karar olmamalıdır.

Önerilen rejim çıktıları anayasa ile uyumludur: serbest akış, yoğunlaşan trafik,
dur-kalk trafik, normal seyir ve duruş. Rejim sürüş boyunca değişmelidir; tüm
sürüşe tek etiket verilmemelidir.

Kalıcı geçmiş veride timestamp ve speed trace olmadığı için bu analiz yalnız
yeni sürüşlerde, zengin telemetri saklandıktan sonra güvenilir yapılabilir.

## 6. Çifte puanlama riskleri ve olay sahipliği

| Davranış | Çifte yazılma riski | Ana sahibi | Diğer kategorinin sınırı |
| --- | --- | --- | --- |
| Sert fren | Fren Şiddeti + Duruş Kalitesi + Akıcılık | Frenleme / Fren Şiddeti | Acil fren aynı duruşta tekrar ceza almamalı; Akıcılık olay penceresini hariç tutmalı. |
| Gereksiz hızlanıp kısa süre sonra fren | Gaz Kalitesi + Fren–Gaz Kararsızlığı + Akıcılık | Sebep zinciri doğrulanırsa Fren–Gaz Kararsızlığı | Saf hızlanma gücü ayrı ölçülebilir; aynı geri-alma davranışı tekrar cezalandırılmamalı. |
| Viraj içinde hız kaybı | Viraj + Frenleme + Akıcılık | Viraj Performansı (geometriye göre momentum) | Frenleme yalnız fren tekniğini değerlendirir; Akıcılık virajı dışarıda bırakır. |
| Viraj girişindeki fren | Fren Şiddeti/Öngörü + Giriş Kalitesi | Fren tekniği Frenleme'ye; uygun giriş seçimi Viraj'a | Aynı negatif ivme iki yerde ceza olmamalı; farklı sorular event attribution ile ayrılmalı. |
| Hızlanma sonrası dalgalanma | Gaz Kalitesi + Hızlanma Sonu + Geçiş Kontrolü + Akıcılık | Hızlanma Sonu Kontrolü | Geçiş Kontrolü yalnız başarılı yerleşmeye pozitif puan verir; Akıcılık bu geçişi dışarıda bırakır. |
| Trafik dur-kalk | Fren–Gaz Kararsızlığı + Duruş + Akıcılık | Trafik rejimi bağlamı; tek başına ceza sahibi yok | Yalnız tekniği gerçekten kötü olan olaylar kendi ana kategorisine gider. |
| Uzun sürüşte kötü performans | Temel kategori cezaları + Dayanıklılıkta ikinci ceza | İlgili temel kategori | Dayanıklılık yeni ceza eklemez; korunabilen kalite üzerinden pozitif potansiyeli sınırlar. |

Bu ayrımı güvenilir yapmak için her algılanan olay/fazın stabil bir kimliği,
zaman aralığı, confidence değeri, ana kategori sahibi ve analizden dışlama
etiketleri olmalıdır. Kategorilerin birbirinden bağımsız biçimde ham örnekleri
yeniden taraması çifte puan riskini yükseltir.

## 7. GPS ve telemetri güvenilirliği

### 7.1 Örnekleme ve kaynak

- Hem UI hem foreground görevinde hedef örnek aralığı 500 ms'dir. Bu bir
  Android teslim garantisi değildir; güç yönetimi ve sensör koşulları gerçek
  aralığı değiştirebilir.
- Foreground görev bildirimi 1 saniyede güncellenir; bu GPS örnekleme süresi
  değildir.
- UI, foreground kaydını 1 saniyelik timer ile içeri alır.
- Aynı sürüşte UI stream ve foreground stream ayrı Geolocator abonelikleridir.
  Birleştirme sırasında aynı/çok yakın örneklerin iki kez analize girme riski
  vardır. Analyzer sıralar ve `dt < 0.2 s` örneklerini atar, fakat açık bir
  kaynak-bazlı deduplication kimliği yoktur.

### 7.2 Hız ve ivme

- Canlı hız kaynağı `Position.speed` değeridir ve m/s olarak ele alınır.
- `SpeedService` hız gösterimi/maksimum için beş örnekli median kullanır.
- `DriveTelemetryAnalyzer` üç örnekli median hız üzerinden
  `(v2 - v1) / dt` ivmesi hesaplar.
- Accuracy >30 m, hız >70 m/s, koordinattan hız >80 m/s ve |ivme| >8 m/s²
  örnekleri analyzer tarafından reddedilir.
- Bu korumalar yararlıdır; ancak sabit eşiklerle örnek silmek olay sürekliliğini
  bölebilir. Anayasal puan için temizleme sonucunun confidence ve reddedilme
  nedeni ile izlenmesi gerekir.
- Persist edilen maksimum hız `DriveTelemetryAnalyzer` tarafından doğrulanmış
  bir maksimum değil, ayrı `SpeedService` hattının maksimumudur. İki hattın
  farklı sonuç üretme riski vardır.

### 7.3 Heading ve viraj

- Heading canlı olarak vardır; geçersiz heading analyzer'da sıfır dönüş kabul
  edilir.
- Küçük heading jitter'ı 3° altı eşikle bastırılır ve viraj için iki devamlı
  örnek istenir.
- Heading üzerinde hız/accuracy uyarlamalı smoothing, koordinat bearing'i ile
  çapraz doğrulama veya yarıçap tabanlı geometri yoktur.
- Düşük hızda compass/GPS heading kararsızlığı nedeniyle viraj tespiti yanlış
  pozitif/negatif üretebilir; mevcut 15 km/s minimumu riski azaltır ama çözmez.

### 7.4 Duruş ve drift

- `SpeedService`, 10 m hareket ve 3 saniye teyit olmadan hızı sıfır kabul eder.
- `DriveTaskHandler` sürüşe durmuş olarak başlar ve benzer 10 m/3 saniye
  mantığı kullanır.
- Foreground görev `_isStopped` iken rota/telemetri noktası kaydetmez. Uygulama
  kapalıyken duruşun hız eğrisi ve son metreleri kaybolur; yalnız toplam
  stopCount/stoppedSeconds kalır.
- 10 m eşiği sabit drift'i bastırır fakat yavaş trafik, kapalı alan GPS drift'i
  ve yüksek accuracy belirsizliği için adaptif değildir.

### 7.5 Rota ve süreklilik

- `RouteService` <3 m noktayı drift, >120 m noktayı sıçrama sayar.
- Büyük sıçramada trace'i açıkça bölmek yerine nokta reddedilir. Son kabul
  edilen noktaya dönene kadar sonraki gerçek noktaların da >120 m kalıp
  reddedilmesi riski vardır.
- Foreground görev hareket halindeyken yalnız 5–120 m arası noktaları saklar;
  bu recovery rotası UI canlı örneklerinden daha seyrektir.
- Sürüş süresi `DateTime.now()` farkıdır; monoton saat değildir. Sistem saati
  değişikliği teorik olarak süreyi etkiler.

### 7.6 Anayasayı yanlış skorlayabilecek en kritik sonuç

Canlı telemetri tek oturumda yeterli görünse de uygulama kapatılıp foreground
servisine geçildiğinde duruş/yavaşlama ayrıntısı seyrelir. Sürüş kaydedildiğinde
ise zengin zaman serisi tamamen kaybolur. Bu durum fren öngörüsü, trafik,
akıcılık, geçişler, dayanıklılık tutarlılığı ve gelecekte yeniden kalibrasyon
için en büyük doğruluk riskidir.

## 8. Hive ve geriye dönük uyumluluk

### 8.1 Mevcut şema

| Yapı | Type ID / box | Alanlar |
| --- | --- | --- |
| `DriveSession` | typeId 0 / `drives` | HiveField 0–7, 12–25 |
| `RoutePoint` | typeId 1 | 0 latitude, 1 longitude |
| Kariyer toplamları | `career_totals` | dynamic box |
| Sembolik rota | `symbolic_routes` | dynamic box |
| Sürüş adları | `drive_names` | dynamic box |
| My World | typeId 10–18 | ayrı `my_world_*` box'ları |

`DriveSession` alanları 8–11 kaldırılmış Flow Analysis verileri için kalıcı
olarak rezerve edilmiştir ve yeniden kullanılmamalıdır. Adapter, eski kayıtlarda
12+ alanlar yoksa güvenli varsayılanlar kullanır. Mevcut adapter testi eski
kaydı açıp analiz alanlarını sıfır/null ile doğrular.

### 8.2 Yeni sistemde persistence ihtiyacı

Yalnız sürüş sonunda yeni toplam skoru hesaplamak için canlı
`DriveTelemetrySample` yeterli olabilir. Ancak aşağıdaki bağlayıcı ihtiyaçlar
nedeniyle yalnız toplam skor saklamak yeterli değildir:

- anayasadaki eşikleri gerçek verilerle yeniden kalibre etmek,
- skor algoritması değiştiğinde geçmiş sürüşleri yeniden hesaplamak,
- kategori/event açıklanabilirliği,
- My World ortak yol bölümünde aynı gerçek Drive Score motorunu tekrar
  çalıştırmak,
- geçmiş sürüşlerde çifte puan hatalarını denetlemek.

Bu nedenle ileriki implementasyonda versioned zengin telemetri veya normalize
edilmiş temiz zaman çizgisinin ayrı bir Hive box/modelinde saklanması daha
güvenlidir. `RoutePoint` veya `DriveSession` içine çok sayıda yeni alan eklemek
yerine DriveSession ID ile bağlı ayrı kayıt, eski kullanıcı verisini daha az
riskle korur.

Önerilen kalıcı kavramlar (bu aşamada oluşturulmamıştır):

- versioned telemetri timeline,
- versioned Drive Score sonucu ve kategori dökümü,
- skor üretim zamanı/algoritma sürümü,
- veri yeterliliği/confidence durumu.

Eski sürüşlerde eksik telemetri sahte verilerle tamamlanmamalıdır. Mevcut özet
alanlarından hesaplanabilen alt metrikler açıkça “kısmi veri” kabul edilmeli;
tam anayasal skor güvenilir değilse skor üretilemez/uygun değil durumu
gösterilmelidir.

## 9. World / segment sistemleriyle etkileşim

Mevcut My World Phase 1/2 altyapısı:

- sürüşü Mapbox Map Matching için kuyruğa alır,
- doğrulanmış yol geometrisini ayrı saklar,
- geçerli mesafeyi hesaplar,
- 3000 m ve üzerini `readyForWorldProcessing` yapar,
- rekor, sahiplik, World index veya Drive Score hesaplamaz.

Dolayısıyla bugün Drive Score değişikliğinden etkilenen aktif bir World
sahiplik sistemi yoktur. Bu güvenli bir durumdur; World işlemi anayasal motor
hazır olana kadar `readyForWorldProcessing` sonrasında durmaktadır.

Gelecekte iki ayrı kullanım açıkça ayrılmalıdır:

1. **Global Drive Score:** Bütün DriveSession için 0–1000 sonuç.
2. **Lokal yol skoru:** Yalnız ortak doğrulanmış yol zaman/telemetri dilimine
   aynı anayasal motorun uygulanmış sonucu.

Lokal skor yeni, farklı veya sadeleştirilmiş “World Score” olmamalıdır. Aynı
motor bir telemetri dilimi üzerinde çalışabilmelidir. Bunun için map-matched
geometri ile orijinal zamanlı telemetri arasında güvenilir eşleme gerekir;
mevcut kalıcı `RoutePoint` bunu tek başına sağlayamaz.

Diğer etkiler:

- **Career:** Şu an mesafe/süre toplamları kullanılır, score bağı yoktur.
- **Drive summary/detail/history:** Yeni toplam ve kategori sonuçlarını
  gösterecek gelecekteki entegrasyon noktalarıdır; şu an puan tüketmez.
- **Replay:** RoutePoint zamanları olmadığı için tahmini timeline kullanabilir;
  score event overlay için güvenilir olay zamanları yoktur.
- **Best record/road segments:** Mevcut runtime'da uygulanmamıştır. Gerçek
  motor ve lokal dilimleme olmadan bağlanmamalıdır.

## 10. Ana gap analysis tablosu

| Özellik | Mevcut Durum | Veri Hazır mı? | Gerekli Değişiklik | Risk |
| --- | --- | --- | --- | --- |
| 0–1000 Drive Score | MISSING | Hayır | Versioned kategori motoru ve aggregator | Sahte/erken skor kullanıcı güvenini bozar. |
| Skor persistence | MISSING | Hayır | Ayrı, versioned sonuç kaydı; eski sürüş desteği | Hive alan çakışması/migration riski. |
| Zengin telemetri toplama | PARTIAL | Canlıda evet | Tek canonical stream, deduplication, recovery eşitliği | UI/foreground çift örnekleri. |
| Zengin telemetri persistence | MISSING | Hayır | DriveSession ID bağlı ayrı timeline | Eski sürüşler yeniden puanlanamaz. |
| GPS accuracy filtresi | PARTIAL | Evet | Ortak filtre sonucu/confidence | Farklı servisler farklı filtre uyguluyor. |
| Speed spike filtresi | PARTIAL | Evet | Tek doğrulanmış hız hattı, süre teyidi | Persist edilen max ile analyzer ayrışıyor. |
| İvme hesabı | PARTIAL | Canlıda evet | Event-safe smoothing ve confidence | GPS speed farkı kısa dt'de gürültülü. |
| Duruş tespiti | PARTIAL | Özet var | Tekil stop event'leri, düşük hız/creep ayrımı | 10 m/3 s yavaş trafikte yanılabilir. |
| Trafik confidence | MISSING | Canlıda türetilebilir | 30–60 s kayan rejim detector | GPS trafik nedenini kesin bilemez. |
| Fren olayı | PARTIAL | Canlıda türetilebilir | -0.7 başlangıç, süre ve pre/post pencere | Mevcut -3 yalnız sert fren sayar. |
| Öngörülü fren | MISSING | Canlıda türetilebilir | Erkenlik/düzgünlük/yığılma analizi | Pedal/çevre sensörü yok; confidence gerekir. |
| Fren şiddeti eğrisi | PARTIAL | Evet | Kademeli severity ve tekrar paterni | Tek örnek ağır ceza riski. |
| Fren–gaz kararsızlığı | MISSING | Canlıda türetilebilir | Bağlı accel/decel event dizisi | Trafikte yanlış ceza riski. |
| Duruş kalitesi | PARTIAL | Canlıda türetilebilir | Son 15→0 ve son 2 s analizi | Background stationary örnekleri kayıp. |
| Ortalama seyir hızı | PARTIAL | Özetle yaklaşık | <5 km/s örnek zamanını dışlayan canonical hesap | Mevcut stop toplamıyla küçük farklar. |
| Maksimum hız | PARTIAL | Evet | Analyzer doğrulamalı persisted max | İki farklı filtre hattı. |
| Mesafe / gerçek süre | PARTIAL | Evet | Bağlamsal kıyas ve saat güvenliği | Salt mutlak değer adaletsiz olabilir. |
| Viraj tespiti | PARTIAL | Canlıda evet | Geometri, sınır, radius ve confidence | Heading noise. |
| Viraj hız koruma | MISSING | Canlıda türetilebilir | Entry/apex/exit momentum analizi | Keskinlik bağlamı olmadan yanlış ceza. |
| Viraj giriş/çıkış | MISSING | Canlıda türetilebilir | Faz sınırları ve event bağları | Fren/accel ile çifte puan. |
| Lateral G | MISSING | Dolaylı | Radius + hızdan bağlam metriği | Doğrudan ödül verilmemeli. |
| Dayanıklılık | MISSING | Mesafe var, kalite serisi yok | Doygun mesafe × korunabilen kalite | Kilometreye bedava puan riski. |
| Seyir periyotları / akıcılık | MISSING | Canlıda türetilebilir | Cruise detector ve exclusion maskeleri | Diğer hataları yeniden puanlama. |
| Saf hızlanma | PARTIAL | Evet | Genel hız bandı olayları ve geçmiş bağlam | Araç gücü skoru domine edebilir. |
| Gaz uygulama kalitesi | MISSING | Dolaylı | Accel event içi kesinti analizi | Pedal verisi yok. |
| Hızlanma sonu kontrolü | MISSING | Canlıda türetilebilir | Accel→cruise settlement | Geçiş ile çifte puan. |
| Geçiş kontrolü | MISSING | Canlıda türetilebilir | Ortak phase/event state machine | Ceza kategorisine dönüşme riski. |
| Event sahipliği | MISSING | N/A | Stable event ID + primary owner + exclusion | Aynı hata birkaç kez puan düşürür. |
| Score versioning | MISSING | N/A | Algorithm/data version ve recalculation contract | Eski/yeni skorlar kıyaslanamaz. |
| World lokal skor | MISSING | Zamanlı persistence yok | Aynı motoru ortak yol telemetri dilimine uygulama | Global skorun yanlışlıkla kullanılması. |
| Eski sürüşlerin tam rescoring'i | CONFLICT | Hayır | Yeni sürüşler için timeline persistence; eskiye dürüst yetersizlik | Özetlerden sahte tam skor üretme. |

## 11. Güvenli implementasyon fazları

### Phase 1 — Canonical telemetri ve kalıcı veri temeli

- **Amaç:** UI/foreground kaynaklarını tek, deduplicate edilmiş, versioned ve
  güvenilir zaman çizgisine dönüştürmek; yeni sürüşlerde yeniden puanlamaya
  yetecek telemetriyi ayrı persistence katmanında saklamak.
- **Muhtemel mevcut dosyalar:** `map_screen.dart`, `task_handler.dart`,
  `foreground_service.dart`, `drive_telemetry_sample.dart`,
  `drive_telemetry_analyzer.dart`, `drive_storage_service.dart`, `main.dart`.
  Yeni score feature klasörü ve ayrı Hive adapter/box gerekebilir.
- **Bağımlılıklar:** Mevcut Geolocator/foreground lifecycle; typeId envanteri.
- **Test:** Kaynak deduplication, out-of-order timestamp, app kill/resume,
  stationary recovery, legacy DriveSession açılışı, round-trip persistence.
- **Rollback riski:** Orta-yüksek; sürüş kaydı yoluna dokunur. Score kapalıyken
  mevcut özetlerin aynen üretildiği shadow doğrulama gerekir.

### Phase 2 — Rejim, faz ve ortak event detection

- **Amaç:** Traffic confidence, stop, cruise, acceleration, deceleration ve
  corner fazlarını tek timeline üzerinde üretmek; event sahipliği/exclusion
  modelini kurmak.
- **Muhtemel dosyalar:** Yeni `features/drive_score` detector/rules modelleri;
  mevcut analyzer yalnız ortak filtreyi paylaşacak şekilde küçük entegrasyon.
- **Bağımlılıklar:** Phase 1 canonical samples.
- **Test:** Sentetik serbest akış/dur-kalk/creep; tek örneğin olay olmaması;
  event overlap ve primary-owner invariants.
- **Rollback riski:** Düşük-orta; henüz kullanıcı skoruna bağlanmadan shadow
  rapor üretilebilir.

### Phase 3 — Frenleme & Öngörü (350)

- **Amaç:** Dört fren alt kategorisini olay pencereleri ve trafik confidence
  ile uygulamak.
- **Muhtemel dosyalar:** Drive Score braking detector/scorer/rules ve test
  fixtures; mevcut UI/persistence henüz değiştirilmez.
- **Bağımlılıklar:** Phase 2 deceleration, stop, traffic ve ownership events.
- **Test:** Erken yumuşama, geç sert fren, acil tek olay, tekrar paterni,
  traffic suppression, stop-quality double-count engeli.
- **Rollback riski:** Orta; 350 puan nedeniyle kalibrasyon hatası toplamı ağır
  etkiler. Golden scenario set gerekir.

### Phase 4 — Tempo & Performans (150)

- **Amaç:** Örnek bazlı seyir ortalaması, doğrulanmış maksimum ve gerçek
  mesafe/süre performansı.
- **Muhtemel dosyalar:** Tempo scorer; ortak speed/distance helpers;
  `DriveSession.drivingAverageSpeed` uyumluluk katmanı.
- **Bağımlılıklar:** Phase 1 temiz timeline ve Phase 2 stop/movement state.
- **Test:** Duruşlu/duruşsuz eş sürüş, 5 km/s sınırı, spike max, wall-time ve
  bağlamsal referans yokluğu fallback'i.
- **Rollback riski:** Düşük-orta; mevcut UI değerleriyle farklı sonuçların adı
  açık tutulmalı.

### Phase 5 — Viraj Performansı (150)

- **Amaç:** Viraj geometrisi, giriş/apex/çıkış, momentum ve stabiliteyi
  hesaplamak; lateral G'yi yalnız bağlam yapmak.
- **Muhtemel dosyalar:** Corner geometry/detector/scorer; mevcut analyzer'ın
  basit sayımlarıyla uyumluluk adaptörü.
- **Bağımlılıklar:** Phase 1 koordinat/heading güveni, Phase 2 corner events.
- **Test:** Düz yol heading jitter, farklı yarıçaplı aynı hız, kontrollü giriş,
  gerekli hız kaybı, çıkış yerleşmesi, düşük hız noise.
- **Rollback riski:** Orta-yüksek; telefon heading kalitesi ve yol geometrisi
  cihazlar arasında değişir.

### Phase 6 — Akıcılık, Hızlanma ve Geçiş Kontrolü (200)

- **Amaç:** Yalnız geçerli cruise periyotlarından akıcılık; hızlanmanın üç alt
  bileşeni; pozitif phase-transition başarıları.
- **Muhtemel dosyalar:** Cruise detector/scorer, acceleration scorer,
  transition scorer ve shared exclusion masks.
- **Bağımlılıklar:** Phase 2 event graph; Phase 3/5 ana sahiplik kararları.
- **Test:** Yeni hedef hıza cezasız geçiş, traffic/corner/brake exclusion,
  30→70/50→100, clean settlement, transition yalnız pozitif puan.
- **Rollback riski:** Orta; çifte puanlama en büyük risktir.

### Phase 7 — Dayanıklılık ve nihai 1000 puan aggregation

- **Amaç:** Mesafe doygunluk eğrisini korunabilen kategori kalitesiyle
  birleştirmek; bütün kategori sınırlarını ve toplam 1000 tavanını uygulamak;
  score/data versioning eklemek.
- **Muhtemel dosyalar:** Endurance scorer, aggregator, score result modelleri
  ve ayrı persistence repository.
- **Bağımlılıklar:** Phase 3–6 kategori çıktıları ve Phase 1 timeline.
- **Test:** 5/50/150+ km eğrisi, uzun kötü sürüş, kategori max clamp, toplam
  max 1000, determinism, aynı event tek sahip, version round-trip.
- **Rollback riski:** Orta; tüm kategorileri etkiler. Önce shadow score olarak
  kaydedilmeli, kullanıcıya açılmadan dağılım gözlenmelidir.

### Phase 8 — UI, summary, geçmiş uyumluluk ve kontrollü geçiş

- **Amaç:** Sürüş özeti/detay/home alanlarını gerçek skora bağlamak; veri
  yetersiz eski sürüşleri dürüstçe göstermek; yeni motoru gözlemlenebilir ve
  geri alınabilir şekilde etkinleştirmek.
- **Muhtemel dosyalar:** `drive_summary_dialog.dart`,
  `drive_detail_screen.dart`, `home_screen.dart`, history kartları ve score
  result repository.
- **Bağımlılıklar:** Phase 7 kararlı/versioned sonuçlar.
- **Test:** Yeni sürüş UI, legacy/no-score UI, app restart, Hive migration,
  score version değişimi, golden/widget tests.
- **Rollback riski:** Düşük-orta; hesap motoru ayrı tutulursa UI eski yer
  tutucuya geri dönebilir. Eski sürüşlere skor uydurulmamalıdır.

### Phase 9 — World lokal skor entegrasyonu (ayrı kapsam)

- **Amaç:** Yalnız gerçek global motor üretimde doğrulandıktan sonra ortak
  doğrulanmış yol telemetri dilimine aynı motoru uygulamak.
- **Muhtemel dosyalar:** My World processing/index katmanı ve Drive Score slice
  contract; global score kodu değiştirilmez.
- **Bağımlılıklar:** Phase 1 zamanlı telemetri + Mapbox geometry eşlemesi +
  Phase 7 versioned engine.
- **Test:** Global/lokal ayrımı, yön, zaman-geometri eşleme, aynı slice aynı
  skor, idempotency.
- **Rollback riski:** Yüksek; World rekor sahipliği etkilenir. Drive Score
  rollout'undan ayrı tutulmalıdır.

## 12. En kritik beş eksik/risk

1. **Zengin telemetri kalıcı değil:** Geçmiş sürüşler anayasanın tamamına göre
   yeniden puanlanamaz ve World lokal skoru çıkarılamaz.
2. **Ortak rejim/event/state modeli yok:** Trafik, cruise, fren, viraj,
   hızlanma ve geçişler bağlamsız kalır.
3. **Çifte puanlama koruması yok:** Aynı davranışın birden fazla kategoriye
   yazılmasını engelleyen event sahipliği bulunmaz.
4. **GPS hatları parçalı ve farklı:** UI, foreground, RouteService,
   SpeedService ve analyzer farklı filtre/örnek setleri kullanır; maksimum hız
   ve olay metrikleri tutarsızlaşabilir.
5. **Mevcut score motoru/persistence/versioning yok:** 1000 puan, kategori
   sınırları, kalibrasyon sürümü ve yeniden hesaplama sözleşmesi sıfırdan ama
   aşamalı kurulmalıdır.

## 13. Sonuç

Mevcut DriveIt, anayasal Drive Score için yararlı canlı sensör/konum temeline
ve bazı özet metriklere sahiptir; ancak bunlar bir puan motoru değildir.
Güvenli ilk implementasyon adımı kategori formülleri yazmak değil, tek ve
kalıcı canonical telemetri zaman çizgisi ile ortak event/rejim modelini
kurmaktır. Bu temel olmadan fren öngörüsü, trafik bastırması, akıcılık,
dayanıklılık ve lokal World skoru güvenilir veya yeniden üretilebilir olmaz.

Bu rapor yalnız gap analysis içerir. Drive Score implementasyonu, kaynak kod
değişikliği, Hive migration, UI değişikliği veya test değişikliği yapılmamıştır.
