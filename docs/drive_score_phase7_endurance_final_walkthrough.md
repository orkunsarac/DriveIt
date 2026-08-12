# Drive Score Phase 7

## Dayanıklılık /150
Dayanıklılık, doygun mesafe potansiyelini uygulanabilir ve yeterli kategori
sonuçlarından elde edilen kalite korunumu ile çarpar. 5 km düşük potansiyel,
50 km yüksek potansiyel, 150 km ise doygunluğa yakın potansiyel açar. Uzun fakat
düşük kaliteli sürüş mesafeden ücretsiz puan alamaz. Zaman pencereli kalite
profili mevcut sonuçlarda güvenilir olmadığı için sahte son-bölüm hassasiyeti
üretilmemiştir.

## Final /1000
Gerçek ve yeterli kategori doğrudan gerçek skoruyla katkı verir. N/A veya
sample-insufficient kategori kendi maksimumunun %75'i kadar **nötr internal
katkı** verir; bu gerçek kategori skoru değildir. Final yedi contribution'ın
doğrudan toplamıdır. Örneğin 315/350, 120/150, corner N/A, 120/150, 85/100,
40/50, 42/50 için `315 + 120 + 112.5 + 120 + 85 + 40 + 42 = 834.5`, display
rounding ile `835` olur. Gerçek uygulanabilir 0 ise 0 olarak kalır.

Overall confidence gerçek/yeterli kategori oranıdır ve puanı değiştirmez.
Algorithm version runtime `1`dir; canonical telemetry `dataVersion` ile aynı
kavram değildir. Hive, UI ve World değiştirilmemiştir.
