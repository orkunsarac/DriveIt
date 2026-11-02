# P-GR7I 4F2B — Güvenli Planet Yayını Kabulü

## Kapsam

Flutter'ın mevcut tam sürüş yayın akışı, kabul edilmiş schema 2 Planet işleme hattına owner-scoped şekilde bağlandı. Segment outbox'ı yalnız yerel uygun parçaları hazırlar; bu izin tam sürüş kaynağını yüklemeye yetmez. Tam sürüş akışı ayrı onay ister ve onaydan önce yalnız owner hesabındaki mevcut yayın durumu sorgulanır.

## Uygulanan güvenlik sınırları

- Play yayın gateway'leri tek bir `LocalOwnerLease` ve onaylı owner UID/epoch ile oluşturulur. Her PostgREST, Storage, RPC ve Edge isteği `OwnerProfileGateway.run` üzerinden gider; istek başında yakalanan token aynı işlem boyunca değişmez ve yanıt sonrası owner/epoch/token tekrar doğrulanır.
- Yayın girdisi, UI/caller nesnesinden değil, lease'in `requireDrive`, `telemetry` ve `score` okuyucularından alınır. Yeni Play yayın satırı yalnız reliable schema 2 kaynak oluşturucusu başarıyla doğrularsa açılır; 5 km sınırı korunur.
- Tam sürüş onayı yoksa yeni pending kayıt, Storage upload, attach veya processing çağrısı yapılmaz. Diyalog tam rota ve güvenilir telemetri kaynağının özel depoya yükleneceğini, doğrulanmış katkının Planet'te ortaklaşabileceğini ve kişisel bulut onayının ayrı olduğunu açıklar.
- Storage yolu deterministik ve owner-scoped; yükleme immutable (`upsert=false`). 409 sonrası yalnız mevcut nesne kabul edilir ve attach ACK'si yayın, owner, sürüş, path, schema, sürüm ve kaynak sayılarıyla eşleşmelidir.
- Kaybolan insert yanıtı benzersiz owner/sürüş kaydıyla yeniden okunur. Processing yanıtı tek başına başarı değildir: yalnız sunucudan tekrar okunan `published` terminal durumu başarı sayılır. Karışık schema karşılaştırması ve güvenilirlik reddi başarıya çevrilmez.
- A→B, logout veya token değişiminde eski lease işlemi kesilir; eski A isteği B token'ıyla devam etmez ve geç yanıt yeni owner UI'sına uygulanmaz. Yerel sürüş verisi silinmez.
- DEV Supabase adapter'ı ve mevcut segment kuyruğu korunmuştur. Eski schema 1 yayın satırları okunup kurtarma akışında kalır; yeni Play kayıtları legacy-only uygunluk kontrolüne zorlanmaz.

## Test sonuçları

| Kontrol | Sonuç |
|---|---|
| Flutter Planet UI, segment kuyruğu, yayın güvenliği, schema 2 kaynak sözleşmesi, gerçek SDK + `LocalOwnerLifecycle`, upload regresyonu | **53 PASS, exit 0** |
| Gerçek SDK + sentetik HTTP/Storage yayın zinciri: açık onay, pending, schema 2 attach, processing, terminal sunucu okuması | **PASS** |
| A→B upload yarışı, aynı UID token refresh/retry, logout, yanlış DEV projesi, yanlış caller sürüş verisi | **PASS** |
| Kayıp insert/process ACK, Storage 409, tekrar yayın ve duplicate önleme | **PASS** |
| Güvenilmez kaynak reddi ve mevcut schema 1 yayınını koruma | **PASS** |
| Yerel Deno processing/source/score/map/detail regresyonları | **103 PASS, exit 0** |
| npm import gerektiren `edge_boot`, `validation_payload` entrypoint ve Planet detail Auth testleri | **NOT TESTED** — `registry.npmjs.org` DNS çözümlemesi başarısız; aynı paket çağrısında ilgili yerel saf yardımcı testlerinin 5'i geçti. Bu sonuçlar entrypoint kabulü sayılmaz. |
| Hosted PROD/DEV, gerçek Storage/Edge/Planet, fiziksel cihaz | **NOT TESTED** — host/cihaz bağlantısı veya dağıtım yapılmadı. |
| Tam `flutter analyze --no-pub` | **3 warning + 4 info**, önceki baseline ile aynı; exit 1 yalnız bu mevcut baseline nedeniyle. Yeni bulgu yok. |

## Kapalı kalan özellikler

`SupabaseBootstrap.playAuthEnabled` ve genel Auth/cloud/Planet kapıları değiştirilmedi. Bu entegrasyon Play'de kendiliğinden aktif olmaz. Hosted dağıtım, kullanıcı kaydı, A55 veya eski sürüş verileri üzerinde işlem yapılmadı. Signer/release guard ve hukuki onboarding değişmedi.

## Kabul sınırı

**4F2B dar istemci entegrasyonu** sentetik servis testlerinde kabul edilmiştir. Gerçek Play runtime aktivasyonu, gerçek Supabase Storage/Edge sunucusu ve fiziksel cihaz yayını kabul edilmemiştir.
