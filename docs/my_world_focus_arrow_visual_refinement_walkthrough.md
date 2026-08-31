# Benim Dünyam — Focus / Arrow Görsel İyileştirmesi

## Arrow redesign

Eski world marker'ları canlı navigasyon üçgenini yeniden kullandığı için trace
üzerinde araç oku gibi görünüyordu. Bunun yerine `DriveMapVisuals` içine
presentation-only, ince çizgili iki kanatlı chevron bitmap'i eklendi. Her
variant kendi trace rengiyle oluşturuluyor; marker yalnızca çizgi üzerinde
duruyor ve `zIndexInt` ile core'un üstünde kalıyor. Geometry tangent bearing
doğrudan marker rotation olarak kullanılıyor; ikon yukarı yönlü olduğu için
rotation correction sıfırdır.

Yakın zoom spacing yaklaşık 150 m, orta zoom 300 m, uzak zoom 500–900 m'dir.
Focus modunda 150–220 m kullanılır. Marker id trace id ve örnek sırasından
üretilir; endpoint yakınında ekstra marker üretilmez. Debug logu
`[WORLD_ARROW]` prefix'iyle generated/rendered sayısını ve chevron asset
durumunu bildirir.

## Opposite-direction refinement

Önceki global uç-bearing yaklaşımına ek olarak local proximity + tangent +
continuity kontrolü korunmuştur. Yaklaşık 15 m yakınlık, 150–210 derece yön
farkı ve en az 60 m kesintisiz overlap aranır. Offset yakın zoomda 5 m,
medium zoomda 4 m, daha uzakta 2.8/1.2 m eşdeğerindedir. İki partner trace
lexicographic id sırasına göre zıt taraflara yerleştirilir; bu nedenle renkler
ve taraflar uygulama açılışlarında değişmez. Yalnız overlap noktaları offset
alır; aynı yönlü, 90 derece kesişen veya belirsiz paralel yollar untouched kalır.

`oppositePartnerMap` snapshot generation değiştiğinde bir kez hesaplanır;
kamera hareketlerinde tekrar O(n²) pair taraması yapılmaz. Offset yalnızca
render geometry'dir ve persisted `ValidatedRoad` / `ActiveWorldTrace`
verilerini değiştirmez.

## Focus camera and style

Focus seçimi önce trace bounds'ını düşük padding ile fit eder, ardından gerçek
ekran yüksekliği, safe-area/header reserve ve detay kartının ölçülen yüksekliği
ile upper-map viewport merkezini hesaplar. İkinci camera update geographic
target'ı dikey olarak telafi eder; zoom 8–16.5 arasında tutulur. Kart ölçümü
değişirse fit yeniden çalışır. Focus modunda glow katmanı kaldırılır, tek temiz
trace stroke'u ve mevcut start/end marker'lar kalır. Normal World görünümünde
neon/glow ve ters yön ayrımı aynen devam eder.

## Doğrulama

- `flutter analyze`: yeni error/warning yok; yalnızca eski info seviyeleri.
- `flutter test`: 203 test geçti.
- `git diff --check`: başarılı.

Galaxy A55 kontrolünde normal görünümde renkli gidiş/dönüş ayrımı, yakın zoom
chevron görünürlüğü, focus üst viewport kadrajı ve detay kartı ayrıca doğrulanmalıdır.
