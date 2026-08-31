# Benim Dünyam — Focus, Direction ve Ters Yön Sunumu

## Focus mode

Bir `ActiveWorldTrace` seçildiğinde `_selectedTraceId` tutulur. Harita normal
Google Maps dark style ile çalışmaya devam eder; polyline, endpoint marker ve
yön marker üretimi yalnızca seçilen trace için yapılır. Mevcut Dünya İzi detay
kartı alt sheet olarak açılır ve mevcut tam sürüş CTA'sı korunur. Sheet
kapatılınca seçim temizlenir ve normal izler geri gelir.

Seçim sonrası kamera, trace geometrisinin tamamını kapsayan bounds'a `300`
padding ile animasyonla sığdırılır. Bu padding alt kartın haritanın altındaki
görünür alanı kapatmasını azaltır; çok kısa geometriler için mevcut bounds
minimum aralığı korunur.

## Direction arrows

Yön okları `DriveMapVisuals.createNavigationArrow` ile mevcut DriveIt yön
varlığı kullanılarak oluşturulur. Ok konumları polyline noktalarına değil,
gerçek geometri mesafesine göre seçilir: normal görünümde zoom'a göre yaklaşık
220/420/850 metre, focus görünümünde 180 metre. Her okun dönüşü komşu geometry
noktalarının bearing değerinden alınır. Uzak zoom'da visibility policy okları
gizler; kısa izlerde en az bir okun gösterilmesi denenir.

## Opposite-direction separation

`WorldTracePresentationService` yalnızca bounds'ları kesişen, uçları yaklaşık
45 metre içinde olan ve uçtan uca tangent bearing farkı 150–210 derece olan
trace çiftlerini ters yönlü yakın çift kabul eder. Bu sınıflandırma yalnızca
render sırasında kullanılır. Geometri birkaç piksel hissi verecek kadar küçük,
zoom-aware lateral bir coğrafi ofsetle çizilir; ActiveWorldTrace, ValidatedRoad,
ownership index ve Drive Score verileri değiştirilmez. Aynı yönlü izlerde veya
90 derece kesişen/paralel belirsiz geometrilerde ofset uygulanmaz.

Ofset tarafı trace kimliğinin parity'siyle deterministiktir; uygulama yeniden
açıldığında değişmez. Kaynak sürüş renkleri aynen korunur.

## Test ve cihaz kontrol listesi

Unit testler ters yönlü yakın izlerin yalnızca sunum geometrisini ayırdığını ve
aynı yönlü izleri değiştirmediğini doğrular. Gerçek cihazda ayrıca focus seçimi,
tam trace fit'i, ok yönü/seyrekliği, ters gidiş-dönüş ayrımı ve detay CTA'sı
kontrol edilmelidir.
