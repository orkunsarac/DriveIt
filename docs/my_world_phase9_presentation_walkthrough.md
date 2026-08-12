# Benim Dünyam Phase 9 — Açılış ve etkileşim walkthrough

## Kapsam

Phase 9, Phase 8'in read-only Dünya görünümünü koruyarak üç sunum davranışı
ekler: sabit süreli açılış animasyonu, aktif iz detay kartı ve son başarılı
Dünya sürüşüne odaklanma. World index, rekor motoru, map matching ve Drive Score
hesaplaması bu ekranda değiştirilmez veya yeniden çalıştırılmaz.

## Üç saniyelik açılış

`WorldIntroPolicy` açılış süresini her zaman üç saniye olarak tanımlar. Aktif iz
sayısı süreyi uzatmaz; her izin görünmeye başlama anı animasyonun ilk yüzde
35'ine deterministik olarak dağıtılır ve bütün izler süre bitmeden tamamlanır.
Siyah katman üzerinde neon izler yayılır, kısa bir pulse oluşur ve katman
fade-out ile mevcut koyu Google Maps görünümünü açığa çıkarır.

Animasyon sırasında harita jestleri ve World kontrolleri kapalıdır. Ekran arka
plana giderse yarım animasyon tutulmaz; güvenli biçimde tamamlanmış duruma alınır.
Aktif iz yoksa animasyon hiç başlatılmaz ve Phase 8 boş Dünya davranışı doğrudan
çalışır.

## “Dünya animasyonunu geç” ayarı

Ayar, `my_world_settings` Hive kutusunda `skip_intro_animation` anahtarıyla
saklanır. Varsayılan değer `false` değeridir. World ayarlar panelindeki switch
değişikliği hemen persist edilir; sonraki ekran açılışında intro policy bu değeri
okur. Testler için aynı sözleşmenin bellek içi implementasyonu bulunur.

## Aktif iz seçimi ve detay kartı

Haritadaki yalnızca aktif `WorldTraceMapItem` polyline'ları seçilebilir. Seçilen
izin core/glow katmanı güçlenir, diğer izler geçici olarak soluklaştırılır.
`WorldTraceDetailService` kaynak `driveSessionId` üzerinden mevcut
`DriveSession`, persist edilmiş `DriveScoreRecord` ve index repository'nin aktif
Dünya mesafesini read-only olarak bir araya getirir.

Alt detay kartında şu gerçek veriler gösterilir:

- sürüş tarihi;
- persist edilmiş Drive Score (yoksa “Mevcut değil”);
- toplam süre;
- maksimum ve ortalama hız;
- sürüşün toplam mesafesi;
- sürüşün halen taşıdığı aktif Dünya rekor mesafesi;
- `REKOR` göstergesi.

`Sürüşü Görüntüle` mevcut `DriveDetailScreen` ekranına aynı DriveSession ile
gider. Kart kapatıldığında seçim temizlenir. Eksik sürüş veya skor kaydı sahte
değer üretmez ve ekranı çökertmez.

## Son Sürüş davranışı

“Son Sürüş”, cihazdaki en yeni normal sürüşü değil, snapshot içindeki
`processedDriveSessionIds` arasında tarihi en yeni olan mevcut DriveSession'ı
seçer. Böylece pending, rejected veya henüz işlenmemiş sürüş yanlışlıkla son
Dünya sürüşü sayılmaz.

Seçilen sürüşe ait halen aktif trace'ler varsa kamera bunların sınırlarına gider
ve trace'ler yaklaşık 1,8 saniye daha güçlü neon ile vurgulanır. Sürüş işlenmiş
olsa bile artık aktif rekor izi kalmamışsa veya kayıt bulunamıyorsa güvenli bilgi
mesajı gösterilir; World verisi değiştirilmez.

## Performans ve görsel tutarlılık

Animasyon Flutter `Ticker`/`CustomPainter` ile tek normalize progress üzerinden
çalışır. Süre iz sayısından bağımsızdır; Hive veya repository her frame'de
okunmaz. Harita polyline paleti Phase 8'deki deterministik DriveIt mavi/cyan
varyasyonlarını kullanır. Animasyon tamamlanınca painter katmanı kaldırılır ve
normal Google Maps etkileşimi devam eder.

## Persistence ve güvenlik

Phase 9 yalnızca kullanıcı ayarını persist eder. Trace seçimi, intro progress ve
son sürüş highlight durumu geçici UI state'idir. World index commit/rebuild,
record ownership, Mapbox isteği, Drive Score hesaplama veya DriveSession yazma
yapılmaz.

## Test kapsamı

Phase 9 hedefli testleri şunları doğrular:

- ayarın varsayılan `false` olması ve iki yönde kalıcı değişmesi;
- aktif Dünya için intro, boş Dünya ve skip durumları;
- çok sayıda izde bile normalize progress sınırları ve sabit üç saniye;
- trace detayında gerçek drive/score/aktif mesafe verilerinin yüklenmesi;
- son Dünya sürüşünün yalnızca işlenmiş sürüşlerden seçilmesi;
- detay kartının metrikleri ve doğru DriveDetail navigasyonu;
- eksik Drive Score için güvenli, sahte puan üretmeyen görünüm.

## Bilinen manuel doğrulama noktaları

Gerçek cihazda neon yayılma ritmi, düşük/orta segment Android cihazdaki frame
akıcılığı, Google Maps'in ilk frame zamanlaması, modal kartın farklı ekran
oranlarındaki yüksekliği ve son sürüş kamera kadrajı görsel olarak kontrol
edilmelidir. Bu faz Phase 10 davranışlarına geçmez.
