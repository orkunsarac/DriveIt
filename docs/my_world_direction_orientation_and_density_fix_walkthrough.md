# Benim Dünyam — Yön Oryantasyonu ve Yoğunluk Düzeltmesi

## Kök neden ve audit

Travel direction resolver canonical telemetry offset ilerlemesini kullanır;
resolver tersine çevrilmedi. Presentation geometry gerçek traversal sırasına
çevrildikten sonra flow bitmap'in doğal chevron ucu görüntü koordinatlarında
aşağı baktığı için Google Maps rotation 0° (kuzey) ile 180° taban farkı oluşuyordu.
Bu nedenle düzeltme yalnızca marker presentation katmanında yapıldı. Audit log'u
`[WORLD_DIRECTION_AUDIT]` her trace/yön için bir kez; örnek sayısı, ilk/son offset,
signed progression, tangent, 180° taban düzeltmesi ve final bearing bilgileriyle
üretir.

## Final rotation

`actual-travel-oriented geometry → local tangent bearing → (bearing + 180) % 360`.
Resolver, Mapbox geometrisi, ActiveWorldTrace offsetleri ve persistence değişmedi;
double reverse uygulanmıyor.

## Flow visibility ve yoğunluk

- Zoom `< 14`: tick yok.
- Zoom `14–15.49`: normal 800 m, focus 575 m.
- Zoom `>= 15.5`: normal 575 m, focus 425 m.
- Normal trace başına en fazla 5, focus trace başına en fazla 7 tick.
- İlk ve son 50 m hariç tutulur; kısa trace için yalnızca focus modunda tek fallback
  tick mümkündür.
- `unknown` yönde tahmini heading veya tick üretilmez.

Mevcut küçük, trace renkli flow tick bitmap'i korunmuştur; yeni görsel dil
oluşturulmadı. Opposite-direction lateral separation, focus viewport, World index,
Mapbox pipeline, Drive Score ve Hive verileri bu düzeltmede değiştirilmedi.

## Doğrulama

Direction resolver forward/reverse/unknown testleri ve opposite presentation testleri
çalıştırıldı. Gerçek cihaz doğrulaması için Galaxy A55 üzerinde şu loglar ve ekranlar
kontrol edilmelidir: Hürriyet Cd. karşı yönler, yakın zoom tick'leri, orta/uzak zoom'da
tick yokluğu. Production loglarında token veya ham GPS noktaları yazdırılmaz.
