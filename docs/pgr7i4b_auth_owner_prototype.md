# P-GR7I 4B — Auth / owner izolasyonu prototipi

**Genel kabul: FAIL / TAMAMLANMADI.** Dar Functions prototipi geçer; uygulamanın bütün veri yollarında “asla” koşulu kanıtlanmadı. Prototip yalnız `test/support` içindedir, uygulamaya bağlanmadı ve PROD Auth kapalıdır.

## Kurulu SDK ve seçilen yön

Supabase Flutter 2.17.2 `FlutterAuthClientOptions.detectSessionInUri=false` seçeneğini sunar (`flutter_go_true_client_options.dart:8,35`). Varsayılan SDK callback dinleyicisi `getSessionFromUrl` çağırır; otomatik işlem kapatıldığında cold/warm link teslimi, PKCE verifier kalıcılığı, recovery ve tekrar deneme uygulama tarafından ele alınmalıdır. Bu prototipte callback işleme değiştirilmedi veya bu akışlar test edilmedi.

Supabase Dart 2.16.1 `SupabaseClient(accessToken: ...)` ile Auth client'ından ayrı data client destekler (`supabase_client.dart:125,171,200`). Bu seçenekle data client'ın `auth` API'si kullanılamaz. Seçilen yön: kontrollü Auth client + onaylı owner/epoch ve sabitlenmiş credential'a bağlı ayrı data client; bütün data çağrıları öncesi/sonrası bağlam doğrulaması. Yalnız event listener ekleme SDK'nın session mutasyonu öncesini korumaz; aynı paylaşılan client ile yalnız ön kontrol yapılması HTTP credential seçimi yarışını kapatmaz.

`test/support/owner_auth_prototype.dart` yalnız örnek Functions çağrısını sarar: context oluşturulurken SDK UID ve token eşleştirilir, token sabitlenir, istek öncesi ve sonrası epoch/UID kontrol edilir. SDK session B olduğunda A context yeni isteği reddeder; önceden başlayan istek B token'ını kullanmaz ve geç yanıt owner değişiminden sonra reddedilir. Bu, yalnız bu prototipin Functions yolu için bir kanıttır. Token imzası/proje ilişkisi, sunucu RLS ve token refresh rotasyonu ayrıca kanıtlanmadı; yanlış yapılandırılmış veya süresi dolmuş token için gerçek sunucu davranışı test edilmedi.

## Test ve kabul matrisi

| Senaryo | Sonuç |
| --- | --- |
| Gerçek SDK A→B ve owner A iken A payload | **PASS, izole Functions yolu:** sentetik HTTP'de yeni A isteği reddi; önceki istek yalnız A token'ı; geç yanıt reddi. |
| Yanlış yakalanmış credential | **PASS:** SDK A iken B credential'ı ile context oluşturulamaz. |
| SDK session event sırası | **PASS:** mevcut gerçek SDK testi session'ın asenkron owner event'inden önce değiştiğini gösterir. |
| Aktif/kurtarılabilir GPS | **KISMEN:** mevcut sentetik owner entegrasyon testleri geçti; prototip callback ile gerçek SDK/GPS yarışı test edilmedi. |
| Cold start/restore, callback warm/cold, PKCE/recovery, replay | **NOT TESTED:** otomatik callback kapatılmadı; teslim ve session exchange koordinatörü henüz yok. |
| Aynı UID gerçek token refresh | **NOT TESTED:** immutable token'ın güvenli rotasyonu ve süresi dolmuş token davranışı çözülmedi. |
| Geç profil, devam eden upload/logout, restart/hatalı geçiş | **KISMEN:** geç Functions yanıtı test edildi; gerçek profile/Storage/upload/logout/restart entegrasyonu test edilmedi. |
| Tüm data yollarında A verisinin B credential ile asla işlenmemesi | **FAIL / KANITLANMADI:** uygulama hâlâ aşağıdaki ortak SDK yollarını kullanıyor; prototip bunlara bağlanmadı. |

`flutter test --no-pub test/owner_auth_prototype_test.dart test/sdk_owner_session_order_test.dart test/local_owner_integration_test.dart`: **19 geçti / exit 0**. Prototip ve SDK sıralama testleri ayrı bir önceki koşuda **3 geçti / exit 0**. Hedefli `dart analyze` **No issues found / exit 0**. İlk denemede SDK `StateError`'ı `FunctionException` içine sardığı için test başarısızdı; assertion gerçek SDK hata tipine göre düzeltildi. Sonraki sürüm, yanıt sonrası guard'ı da test eder.

## Mevcut bypass envanteri

| Kod | Ortak SDK'ya erişim |
| --- | --- |
| `lib/services/supabase_account_service.dart:282` | `Supabase.instance.client`, current session/user, profil ve Auth işlemleri. |
| `lib/services/production_owner_runtime_factory.dart:84` | Ortak client ile owner Auth; `:136` sync adapter, `:153` Group service. |
| `lib/services/supabase_local_owner_auth.dart:14` | Ortak client ve asenkron Auth state. |
| `lib/services/supabase_owner_drive_sync_adapter.dart:32` | SDK currentUser; `:293` Storage, `:449` Edge Functions. |
| `lib/features/planet/services/planet_map_repository.dart:22` ve `planet_trace_detail_repository.dart:37` | SDK session ve Planet sorgusu/Edge. |
| `lib/features/world_publish/services/world_publish_service.dart:62` | Ortak session ve `world_publishes` sorguları. |
| `lib/features/world_publish/services/world_publish_processing_service.dart:56` | Ortak session ve Edge Functions. |
| `lib/features/world_publish/services/world_publish_source_upload_service.dart:27` | Ortak session ve Storage. |
| `lib/services/account_deletion_runtime.dart:48` | Ortak currentUser ve delete-account Edge. |
| `lib/features/group_drive/supabase_group_drive_service.dart:65` | Enjekte client session/user; ilk yayın kapsamı dışında, gate kapalı. |
| `lib/main.dart:402` | SDK Auth event ve recovery ekranı session kontrolü. |

## Tam entegrasyon için sınır

Önce manuel callback teslimi ile cold/warm ve PKCE/recovery kalıcılığı için ayrı gerçek SDK testleri; ardından owner/GPS fence altında Auth state machine ve güvenli token refresh; sonra profil, sync, Storage/Edge, Planet ve silme için ayrı owner-scoped gateway'ler gerekir. Her adımda callback replay, geç yanıt, logout ve restart yarışları kapalı gate altında doğrulanmalıdır. R1 guard, signing, hukuki gate ve PROD/DEV verileri bu prototipte değiştirilmedi. Hosted bağlantı veya cihaz işlemi yapılmadı.
