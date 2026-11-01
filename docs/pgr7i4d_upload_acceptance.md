# P-GR7I 4D — dar upload kabulü

Sonuç: PASS (yerel SDK/owner/HTTP kabulü). PROD aktivasyonu yapılmadı.

`SupabaseOwnerDriveSyncAdapter` Play kompozisyonunda `OwnerProfileGateway` kullanır. Capability/begin, private staging Storage ve finalize istekleri owner UID, sabit lease/epoch ve işlem başında yakalanmış credential ile ayrı data client üzerinden çalışır. SDK ortak istemcisi veri isteğinde kullanılmaz. Gateway işlem öncesi/sonrası ve adapter yanıt kontrolü korunur. Yeni SDK hesabının token'ı eski isteğe taşınmaz; geç yanıt reddedilir. Bir HTTP isteği sunucuya ulaştıktan sonra owner değişmesi sunucu işlemini geri almaz; retry aynı idempotency sözleşmesini kullanır.

Factory artık Play için yalnız PROD HTTPS hedefini, DEV için DEV hedefini kabul eder. Play Auth bootstrap ve accountSyncEnabled gate değişmedi. Gateway kullanılan adapter download ve M2 silme işlemlerini reddeder. DEV adapter'ı mevcut ortak istemci yolunu kullanır. Owner outbox, uygunluk, fingerprint, ACK, staging duplicate ve idempotency kodları değiştirilmedi.

| Kanıt | Sonuç |
| --- | --- |
| Gerçek SDK + gerçek lifecycle/lease, A begin/Storage/finalize | PASS |
| Gerçek SDK A→B sırasında bekleyen finalize, token kimliği ve eski lease reddi | PASS |
| Aynı UID refresh sonrasında yeni isteğin yeni token kullanması, logout/guest reddi | PASS |
| Yanlış Play proje URL'si ve Play download reddi | PASS |
| Sentetik 503 sonrası retry; yerel scoped kayıt korunması | PASS |
| Kayıp ACK, duplicate Storage, idempotency ve tek remote kayıt | PASS: mevcut adapter/client regresyonları; hosted DB testi değildir |
| Guest, legacy, telemetrisiz ve uygunluk işareti olmayan sürüşler | PASS: mevcut scheduler/client regresyonları |
| Fiziksel cihaz ve hosted PROD/DEV | NOT TESTED; bağlantı kurulmadı |

Komut: `flutter test --no-pub test/owner_upload_real_lifecycle_test.dart test/supabase_owner_drive_sync_adapter_test.dart test/owner_drive_sync_client_test.dart test/owner_profile_real_lifecycle_test.dart` — 73 PASS, exit 0. Tam `flutter analyze --no-pub`: mevcut 3 warning + 4 info, yeni bulgu yok, exit 1. İlk analizde eklenen üç biçim bulgusu düzeltildi. `git diff --check` doğrulanır.

Sınır: yeni SDK/owner testi üretim adapter'ını doğrudan çalıştırır; scheduler/outbox kayıt ve tekrar deneme kanıtları ayrı mevcut testlerden gelir. Test sunucusu sentetik HTTP/Storage yanıtları üretir, gerçek Supabase sunucu/RLS kabulü sayılmaz. Play bulutunun uçtan uca aktivasyonu ve henüz taşınmamış veri yolları bu kabulün kapsamı dışındadır.
