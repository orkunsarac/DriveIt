# Drive Score Phase 4 — Tempo & Performans

## Kapsam

Bu faz yalnızca Tempo & Performans kategorisini uygular: Ortalama Seyir Hızı
60, Maksimum Hız 30 ve Mesafe / Süre 60; toplam üst sınır 150 puandır.
Frenleme motoru, diğer kategoriler, UI, Hive/DriveSession şeması ve World
sistemi değiştirilmemiştir.

## Tempo engine

`TempoPerformanceEngine`, Phase 1 canonical telemetrisiyle üretilmiş Phase 2
`DrivePhaseAnalysisResult` değerini tüketir. Mesafe sadece canonical
`distanceFromPreviousMeters` zincirinden gelir; ham GPS için ikinci bir
Haversine toplamı çıkarılmaz. Sonuç `TempoPerformanceScoreResult` olarak
yalnızca runtime/offline analizidir ve Hive'a yazılmaz.

## Ortalama Seyir Hızı — 60

Her örnek aralığı gerçek timestamp farkıyla ağırlıklandırılır. Phase 2
`stopped` interval'leri moving time'dan çıkarılır. Stop debounce içinde iki
ardışık düşük canonical hız, GPS drift'in moving time'ı şişirmemesi için
korumacı fallback'tir.

Ortalama seyir hızı `canonical moving distance / moving duration` ile
hesaplanır; düzensiz timestamp'lerde basit sample average kullanılmaz. Düşük
hızda gerçekten ilerleme confirmed stop değilse moving time'da kalır.
Başlangıç smooth curve: 30 km/h = %25, 60 = %58, 100 = %83, 150 = %100.

## Maksimum Hız — 30

Maksimum canonical hızlardan doğrulanır. Adayın en az bir komşu canonical
örneğiyle 10 m/s içinde tutarlı olması gerekir. Böylece
`100 → 101 → 220 → 101 → 100` spike'ı reddedilir; sürekli
`170 → 178 → 185 → 190 → 188` dizisi kabul edilir. Curve: 80 km/h = %33,
140 = %67, 200 = %100. Phase 1 accuracy/speed filtreleri ilk savunma
katmanıdır; bu motor kısa continuity doğrulaması ekler.

## Mesafe / Süre — 60

Metrik `canonical total distance / total elapsed duration`dır. Elapsed süre,
ilk-son canonical timestamp arasındaki gerçek süredir. Kırmızı ışık, trafik,
stop-and-go ve kısa duruşlar bu süreden çıkarılmaz. Rota-relative karşılaştırma
henüz olmadığı için absolute fallback curve kullanılır: 20 km/h = %25,
50 = %58, 80 = %83, 120 = %100. Gelecekte rota/segment geçmişi hazır olduğunda
bu fallback route-relative normalizasyonla değiştirilebilir.

Average cruising speed hareket anındaki tempoyu; Mesafe/Süre bütün yolculuğun
tamamlanma temposunu ölçer. Bu nedenle aynı verinin iki kopyası değildir.

## Kritik süre doğrulaması

`totalElapsedDuration`, `movingDuration` ve `stoppedDuration` ayrıdır; aynı
aralık iki kez sayılmaz ve elapsed süre moving + stopped sürelerine ayrılır.

**Duruşlar Ortalama Seyir Hızından çıkarılır; Mesafe / Süre Performance toplam
süresinden çıkarılmaz.**

## Yetersiz veri

Güven eşiği en az 6 örnek, 90 saniye moving time ve 1 km canonical mesafedir.
Sağlanmazsa `sampleSufficient=false` döner ve skor alanları 0'dır: bu değer
ceza/final skor anlamı taşımaz ve persist edilmez. Böylece kısa/no-movement
kayıt sahte maksimum ya da kalıcı düşük skor oluşturmaz.

## Kalibrasyon

Tüm eğriler, stop threshold, yeterlilik ve maximum-speed continuity değerleri
`lib/features/drive_score/config/tempo_performance_calibration.dart` içinde
merkezidir. Anayasal üst sınırlar 60 / 30 / 60 olarak sabittir.

## Testler

`test/tempo_performance_engine_test.dart` stabil 90 km/h sürüşü, kırmızı
ışıkta iki dakika duruşu, stop-and-go, GPS drift, izole speed spike, gerçek
yüksek hız, düzensiz timestamp, farklı stop/tamamlanma süreleri, kısa/no
movement veri, determinism ve tüm score bounds senaryolarını kapsar.

## Bilinen sınırlamalar

Yol sınıfı, hız limiti ve route-relative geçmiş kıyası henüz yoktur; bu nedenle
Mesafe/Süre curve'ü geçici absolute fallback'tir. Skorlar final Drive Score
değildir ve UI'da gösterilmez.

## Phase 5 hazırlığı

Canonical heading/hız/mesafe ile Phase 2 corner event, apex ve overlap context
Viraj Performansı — 150 puan motoru için hazırdır. Bu fazda viraj puanı
hesaplayan kod yazılmamıştır.
