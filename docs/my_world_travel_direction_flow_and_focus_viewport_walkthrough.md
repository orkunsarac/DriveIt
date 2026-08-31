# Benim Dünyam — Travel Direction, Flow Tick ve Focus Viewport

## 1. Yön kök nedeni

Map-matched `ValidatedRoad` geometrisinin sırası, kaynağın o yolu hangi yönde
geçtiğini garanti etmez. Bu nedenle yalnızca geometry tangent bearing kullanmak
ters yön gösterebiliyordu.

## 2. Direction çözümü

`WorldTraceTravelDirectionResolver`, kaynak sürüşün timestamp sıralı canonical
telemetrilerini ilgili matched section üzerine projekte eder. Trace aralığındaki
offset farklarının çoğunluğu artıyorsa `forward`, azalıyorsa `reverse` seçilir.
En az üç örnek, anlamlı net ilerleme ve %65 çoğunluk güveni aranır; aksi halde
`unknown` döner ve yön işaretleri çizilmez.

## 3. Presentation geometry ve başlangıç/bitiş

Reverse traversal tespit edildiğinde yalnızca `ResolvedWorldTrace.geometry`
ters çevrilir. Hive'daki ValidatedRoad, ActiveWorldTrace offsetleri ve World
index değişmez. Böylece `geometry.first` gerçek iz girişini, `geometry.last`
gerçek çıkışı temsil eder; detay kartındaki başlangıç/bitiş de traversal
sırasını izler.

## 4. Flow tick görsel dili

Eski büyük navigasyon oku/chevron yerine trace rengiyle üretilen küçük, şeffaf
iki kanatlı flow tick bitmap'i kullanılır. Yakın zoom spacing yaklaşık 300 m,
orta 500 m, düşük yakınlık 800 m'dir; zoom < 11'de tamamen gizlenir. Focus
modunda 225/400/600 m spacing kullanılır. İlk ve son 50 m hariç tutulur ve
kısa trace'lerde normal görünümde tick gösterilmez. Tick bearing, artık travel
oriented presentation geometry tangent'inden gelir.

## 5. Opposite-direction davranışı

Lokal proximity/tangent/continuity tespiti ve presentation-only 1.2–5 m offset
normal World görünümünde korunur. Focus modunda yalnız selected trace kaldığı
için offset kapalıdır; persisted geometri ve ownership etkilenmez.

## 6. Focus viewport

Focus seçimi artık bottom sheet overlay kullanmaz. Ekran gerçek bir `Column`
olarak iki fiziksel bölüme ayrılır: üstte bounded GoogleMap, altta Dünya İzi
detay kartı. `LayoutBuilder` gerçek map widget yüksekliğini ölçer; layout
stabil olduktan sonra selected trace bounds yalnız bu viewport'a `newLatLngBounds`
ile fit edilir. Varsayımsal full-screen dikey compensation kaldırılmıştır.

## 7. Cache ve performans

Yön çözümü World read projection sırasında bir kez yapılır; her frame'de veya
camera rebuild'de tekrar projection yapılmaz. Flow tick bitmap'leri trace renk
varyantına göre cache edilir. Opposite partner eşleşmeleri snapshot generation
başına bir kez hesaplanır.

## 8. Doğrulama

- Forward/reverse/unknown resolver testleri eklendi.
- Flow tick spacing ve endpoint exclusion mevcut marker üretiminde uygulanıyor.
- Focus map widget bottom edge ile detail card top edge fiziksel olarak aynıdır.
- Segment score, DriveScoreCalculator, Mapbox, World ownership ve Hive
  persistence davranışları değiştirilmedi.

Gerçek cihaz checklist: Hürriyet Cd. karşı yönlü izlerde iki farklı yön,
yakın/uzak zoom'da seyrek flow tick, selected trace'in bounded üst viewport'ta
ortalanması ve detay kartı overflow kontrol edilmelidir.
