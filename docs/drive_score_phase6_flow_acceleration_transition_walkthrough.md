# Drive Score Phase 6 — Akıcılık, Hızlanma ve Geçiş Kontrolü

Phase 6 üç bağımsız, runtime-only offline motor ekler; Hive, UI, World ve nihai
1000 puan değişmemiştir.

## Sürüş Akıcılığı /100

Yalnızca Phase 2 `CruiseEvent` periyotları kullanılır. En az sekiz saniyelik,
30 km/h üzerindeki ve yüksek trafik güveni olmayan cruise periyotları; süre
eğrisi ve canonical hız varyasyonuna göre değerlendirilir. Trafik cruise'ları
hariç tutulur. Uygun cruise yoksa sonuç N/A'dır.

## Hızlanma & Gaz /50

Phase 2 `AccelerationEvent` girdileriyle 25 puanlık normalize hız kazanımı,
15 puanlık event içi smoothed-acceleration kararlılığı ve 10 puanlık kısa
event-sonrası yerleşme hesaplanır. Gaz kalitesi yalnızca acceleration event
içinde incelenir; sonraki uzun stabil sürüş Akıcılık motoruna bırakılır.
Yüksek trafik güvenli/düşük hızlı stop-go hızlanmaları hariç tutulur.

## Geçiş Kontrolü /50

Event dizisinden cruise→deceleration→cruise (/20),
cruise→corner→cruise (/20) ve acceleration→cruise (/10) zincirleri çıkarılır.
Sadece hedef cruise'a yerleşmenin stabilitesi değerlendirilir; fren şiddeti,
viraj kalitesi ve acceleration gücü tekrar puanlanmaz. Bu pozitif-only
kategoridir; geçiş yoksa N/A'dır.

## Ortak ilkeler

Üç motor Phase 2 event ownership, trafik context ve canonical telemetry
kullanır. Yeni detector oluşturmaz, sonuçları persist etmez ve aynı inputta
deterministik çalışır. Sample sufficiency her sonuçta ayrı diagnostic olarak
taşınır.

## Sınırlar

Kalibrasyonlar ilgili üç ayrı config dosyasındadır. Geçiş çıkarımı mevcut event
sıralamasına dayanır; daha karmaşık aralıklı event graph'ları gelecekte Phase 7
gereksinimi olursa ayrı ele alınmalıdır.
