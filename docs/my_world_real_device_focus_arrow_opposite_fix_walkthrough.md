# Benim Dünyam — Gerçek Cihaz Focus / Arrow / Ters Yön Düzeltmesi

## Focus camera root cause and fix

Önceki akışta kamera, detay kartı ekrana gelmeden sabit `300` padding ile
fit ediliyordu. Kartın gerçek yüksekliği ve üst safe-area/map alanı hesaba
katılmadığı için trace ekranın altına veya üstüne kayabiliyordu.

Detay sheet artık ilk layout sonrasında kendi `BuildContext.size` değerini
bildiriyor. Focus padding; ekran yüksekliği, safe-area üst boşluğu ve gerçek
kart yüksekliğinden hesaplanıyor. İlk frame için güvenli bir tahmin kullanılıyor,
sonrasında gerçek yükseklikle bounds fit yeniden çalıştırılıyor. Seçili iz
focus sırasında orijinal centerline üzerinde gösteriliyor; ters yön offset'i
yalnız normal Dünya görünümünde aktif.

## Direction arrow root cause and fix

Oklar daha önce doğru hesaplanmasına rağmen küçük ikon/seyrek spacing ve görünür
olmayan marker zinciri nedeniyle cihazda ayırt edilemiyordu. Marker seti artık
GoogleMap'e doğrudan veriliyor, mevcut DriveIt navigation arrow bitmap'i
yaklaşık `0.82` ölçekle hazırlanıyor, `zIndexInt` ile trace core'un üzerine
yerleştiriliyor ve yakın zoom'da 150–180 m, orta zoom'da 300 m, daha uzak
zoom'da 500–900 m aralık kullanılıyor. Kısa trace'lerde de en az bir marker
üretiliyor. Bearing doğrudan geometry tangent'inden geliyor; raw GPS heading
kullanılmıyor. Asset doğal yönü yukarı olduğu için ek rotation correction
uygulanmıyor.

Debug modunda `[WORLD_ARROW]` logu zoom, spacing, üretilen/render edilen ok
sayısı ve asset hazır durumunu bildiriyor.

## Opposite-direction root cause and fix

Önceki uç nokta/whole-trace bearing yaklaşımı gerçek centerline üzerindeki
kısmi örtüşmeleri yakalayamıyordu ve tespit edilse bile tüm trace'i kaydırıyordu.

Yeni `WorldTracePresentationService` bounds prefilter sonrasında her geometry
noktası için en yakın karşı trace noktasını, yerel tangent farkını ve ardışık
mesafe sürekliliğini inceliyor. Yaklaşık 15 m proximity, 150°–210° ters yön ve
en az 60 m kesintisiz overlap koşulları birlikte aranıyor. Sadece bu local
overlap bölümündeki noktalar birkaç metre eşdeğerinde zoom-aware lateral offset
alıyor; overlap dışı noktalar persisted centerline üzerinde kalıyor. Aynı
yönlü trace'ler, 90° kesişimler ve belirsiz paralel yollar offset almıyor.

Offset yalnızca render geometry'de uygulanır; `ValidatedRoad`,
`ActiveWorldTrace`, World index, ownership ve Drive Score verileri değişmez.
Source-drive renkleri korunur ve offset tarafı deterministiktir.

## Doğrulama

- Ters yönlü yakın trace ve aynı yönlü trace için presentation unit testleri eklendi.
- Focus, visibility, geometry resolver ve mevcut World testleri korundu.
- `flutter analyze`: yeni hata yok; yalnızca mevcut 5 info seviyesi.
- `flutter test`: 203 test geçti.
- `git diff --check`: başarılı; yalnızca LF/CRLF uyarıları.

Gerçek cihazda `[WORLD_FOCUS]`, `[WORLD_ARROW]` ve `[WORLD_OPPOSITE]` logları
ile birlikte normal Dünya, yakın zoom ok görünümü, focus görünümü ve detay kartı
ekran görüntüleri kontrol edilmelidir.
