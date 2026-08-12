# Benim Dünyam Phase 8 — Read-only presentation walkthrough

## Kapsam ve navigasyon

Ana ekrandaki mevcut Dünya kartının görsel yapısı korunup dokunma davranışı
`WorldModeSelectionScreen` ekranına bağlandı. Geri yığını doğal olarak:

`Ana ekran → Dünya seçimi → Benim Dünyam haritası`

şeklindedir. Seçim ekranında **Benim Dünyam** aktiftir. **DriveIt Gezegeni**
kilitlidir, `YAKINDA` etiketi taşır ve yalnız kısa bir bilgi mesajı gösterir;
multiplayer yönlendirmesi yoktur.

## Map provider ve görsel dil

Projede canlı sürüş, sürüş detayı ve replay ekranlarında çalışan Google Maps
altyapısı korundu. Map Matching sağlayıcısının Mapbox olması harita renderer'ını
değiştirmek için gerekçe sayılmadı. Harita `DriveMapVisuals.darkMapStyle`
ayarını tekrar kullanır; böylece mevcut koyu yol/etiket paletiyle aynı görünür.

Aktif izler iki Google Maps polyline katmanıyla çizilir:

- altta kalın, düşük alpha glow;
- üstte ince ve parlak neon core.

Bu yöntem shader/blur veya frame bazlı yeniden hesaplama gerektirmez.

## Read-only veri akışı

`MyWorldReadService` ekran açılışında tek kez aktif `WorldIndexSnapshot` okur.
Yalnız snapshot içindeki `ActiveWorldTrace` kayıtlarını işler. Ham
`DriveSession` rotaları, bütün `ValidatedRoad` geometrileri ve historical loser
izleri çizilmez.

Her trace için ilgili `ValidatedRoad` ekran yüklemesi boyunca bellekte cache
edilir. Servis yalnız repository read metotlarını çağırır; index commit, World
processing, rebuild, Mapbox isteği veya Drive Score hesabı yapmaz.

Seçim kartındaki istatistikler de bu snapshot'tan türetilir:

- **Dünya İzlerin:** aktif trace offset uzunluklarının toplamı;
- **İşlenen Sürüş:** snapshot `processedDriveSessionIds` listesindeki benzersiz
  sürüş sayısı. Aynı sürüşün birden çok aktif trace'i bu sayıyı artırmaz.

## ActiveWorldTrace geometri çözümleme

`WorldTraceGeometryResolver`, trace'in `validatedRoadId` ve
`matchedSectionId` referanslarını çözer. Index offset'leri doğrulanmış yolun
kümülatif section mesafeleri üzerinde tutulduğu için önce hedef section'ın yol
içindeki başlangıç offset'i bulunur. Ardından trace aralığı section-local
offset'e çevrilir.

Section'ın beyan edilen mesafesi ile gerçek polyline uzunluğu arasında küçük
provider farkları olabileceğinden offset oranı gerçek geometri uzunluğuna
ölçeklenir. Başlangıç ve bitiş noktaları segment üzerinde interpolate edilir;
yalnız arada kalan gerçek geometri noktaları eklenir. Böylece 2,4–4,1 km trace
için tüm section değil yalnız o fiziksel parça çizilir. Kopuk section'lar ayrı
trace/polyline kalır ve ters yönlü geometri saklandığı sırayla korunur.

Eksik road/section, sınır dışı offset, tek noktalı veya sıfıra yakın geometri
crash üretmez. Geçerli trace'ler çizilir, bozuk olanlar atlanır; snapshot yalnız
bozuk referanslardan oluşuyorsa güvenli hata durumu gösterilir.

## Deterministik görsel varyasyon

`WorldTraceVisualVariants`, source drive ID için runtime random kullanmayan
sabit bir hash başlangıcı üretir. Aynı source drive bütün trace'lerinde ve ekran
açılışlarında aynı varyasyonu alır. Varyasyonlar yalnız DriveIt'in mavi/cyan
ailesindedir ve skor anlamına gelmez.

Aynı yol sınırında veya birbirine çok yakın bounding alanlarda bulunan farklı
source sürüşler için presentation-only komşuluk grafiği oluşturulur. Sıralı,
deterministik greedy seçim komşu kaynakların mümkün olduğunca farklı palet
varyasyonu almasını sağlar; World verisi değiştirilmez.

## İlk viewport ve boş Dünya

Başlangıç kamera hesabı bütün noktaların matematiksel ortalamasını kullanmaz.
Trace merkezleri yaklaşık 0,5 derecelik coğrafi hücrelerde aktif mesafe ile
ağırlıklandırılır. En yüksek ağırlıklı hücre ve yakın komşuları dominant cluster
olarak fit edilir. Böylece uzaktaki tek ve kısa sürüş ana ağı ülke/kıta
seviyesine gereksiz uzaklaştırmaz.

Aktif iz yoksa harita güvenli Türkiye fallback'iyle açılır. Konum servisi ve
önceden verilmiş izin uygunsa mevcut konuma gider. İzin yoksa harita yine
çalışır ve engelleyici olmayan boş Dünya mesajı gösterilir. `Konumum` düğmesi
izin akışını ancak kullanıcı dokunduğunda başlatır.

## Harita kontrolleri ve seçim

- pinch zoom, pan, rotate ve tilt açıktır;
- **Konumum** tek seferlik güncel konuma gider, follow modu açmaz;
- **Dünyamı Göster** dominant trace cluster'ına geri döner;
- harita döndürüldüğünde kuzeye sıfırlayan pusula kontrolü görünür;
- henüz gerçek bir World ayar ekranı olmadığı için sahte Ayarlar girişi yoktur;
- riskli/eksik Son Dünya Sürüşü davranışı Phase 9'a bırakıldı.

Core polyline kendi gerçek geometri hitbox'ıyla dokunma alır. Seçilen trace
görsel olarak güçlendirilir ve kaynak ID bellekte tutulur; kullanıcıya ham
DriveSession ID gösterilmez. Tam bilgi kartı Phase 9 kapsamındadır.

## UI state ve cache

Ekran `loading`, `ready`, `empty` ve `error` durumlarını ayırır. Geometry ve
polyline girdileri Future tamamlandıktan sonra ekran ömrü boyunca bellekte
tutulur; her `build()` çağrısında Hive tekrar okunmaz. Ekran yeniden açılırsa
güncel aktif snapshot yeniden yüklenir.

## Test ve statik analiz

- Phase 8 hedefli testler: **11/11 geçti**.
- Tam Flutter test paketi: **183/183 geçti**.
- `flutter analyze`: Phase 8 kaynaklı warning/error yok. Repository'de daha
  önce bulunan beş info-level bulgu devam ediyor (`home_screen.dart` iki,
  `map_screen.dart` iki, `route_preview.dart` bir).
- `git diff --check`: geçti; yalnız Windows satır sonu dönüşümü uyarıları var.

Testler full/partial clipping, disconnected section, reverse order, invalid
geometry, empty snapshot, broken reference, istatistikler, deterministik ve
komşu-kontrast varyasyon, dominant cluster ve seçim ekranı davranışını kapsar.

## Gerçek cihaz manuel kontrolü

1. Ana ekran → **Dünya** kartına dokun.
2. **Benim Dünyam** ve kilitli **DriveIt Gezegeni / YAKINDA** kartlarını doğrula.
3. **Benim Dünyam** kartına gir.
4. Aktif World trace varsa yalnız aktif neon yolların çizildiğini doğrula.
5. Haritada pan, pinch zoom, rotate ve tilt hareketlerini dene.
6. **Konumum** ile tek seferlik güncel konum merkezlemesini dene.
7. **Dünyamı Göster** ile dominant World ağına geri dön.
8. Farklı source trace sınırlarında cyan/mavi ton ayrımını kontrol et.
9. Neon trace'e dokunup seçili core çizginin güçlendiğini doğrula.
10. Boş index durumunda harita ve boş Dünya mesajının güvenli açıldığını doğrula.

## Phase 9'a bilinçli bırakılanlar

3 saniyelik sinir-ağı açılış animasyonu, trace detay kartı, Son Dünya Sürüşü
highlight akışı, World ayarları/animasyonu geç seçeneği, gelişmiş zoom-level
geometry sadeleştirme ve final görsel polish bu fazda yapılmadı.
