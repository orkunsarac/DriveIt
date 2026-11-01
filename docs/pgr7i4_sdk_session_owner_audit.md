# P-GR7I Aşama 4 — SDK session / owner güvenliği

**Karar: ENGEL — PROD Auth açılmamalı.** Mevcut SDK ve ortak client kullanımında bütün session mutasyonlarını owner geçişinden önce güvenli biçimde durduracak bir sınır kanıtlanmadı. Bu aşamada runtime güvenlik değişikliği yapılmadı; aşağıdaki test mevcut yarışı gösterir. Play Auth gate kapalı ve release guard korunuyor.

## Kanıtlanan olay sırası

- Kullanılan `gotrue` 2.27.2 SDK'sında `signInWithPassword` önce `_saveSession`, sonra `notifyAllSubscribers` çağırır (`gotrue_client.dart:398`); callback `getSessionFromUrl` ve refresh yollarında da session kaydı event bildiriminden önce gerçekleşir (`:1059`, `:1608`). SDK callback dinleyicisi `supabase_auth.dart:302` doğrudan `getSessionFromUrl` çağırır.
- `SupabaseLocalOwnerAuth` SDK `onAuthStateChange` asenkron akışını dinler (`lib/services/supabase_local_owner_auth.dart:20`). Gerçek SDK + sentetik HTTP testi `test/sdk_owner_session_order_test.dart`, A→B girişinde SDK `currentUser` B iken owner event tüketicisinin hâlâ A gördüğü anı **PASS** ile yeniden üretir. Test yalnız SDK içindeki sync event akışını sıralamayı gözlemek için kullanır; uygulama kodu bu internal API'ye bağlanmaz.
- `LocalOwnerLifecycle` event'i aldıktan sonra lease'i geçersizleştirir (`lib/services/local_owner_lifecycle.dart:1620`); GPS sahibi farklıysa geçişi `blocked` yapar (`:1710`). Bu mevcut koruma event öncesi pencereyi kapatmaz.
- Profil `SupabaseAccountService.currentUser/currentSession` (`lib/services/supabase_account_service.dart:286`), Planet repo ve yayın servisleri (`lib/features/planet/services/planet_map_repository.dart:22`, `lib/features/world_publish/services/world_publish_service.dart:62`) SDK session'ını doğrudan okuyabilir. Owner sync adapter çağrı öncesi/sonrası UID ve lease kontrolü yapar (`lib/services/supabase_owner_drive_sync_adapter.dart:64`, `:449`), ancak kontrol ile SDK'nın HTTP credential seçimi tek atomik işlem olarak kanıtlanmadı. Yeni hesapla eski payload gönderiminin gerçekleştiği gösterilmedi; bunun gerçekleşemeyeceği de bu mimaride kanıtlanmadı.

## Senaryo matrisi

| Senaryo | Sonuç ve sınır |
| --- | --- |
| A Guest→Account, B A→B, C logout | KISMEN: mevcut sentetik lifecycle testleri event sonrası izolasyon gösterir. A→B gerçek SDK sıralama testi event öncesi pencereyi kanıtlar; tam güvenlik FAIL/kanıtlanmadı. |
| D soğuk başlangıç/session restore | NOT TESTED: gerçek SDK restore ile owner açılışının tam entegrasyonu test edilmedi. |
| E aktif GPS, F kurtarılabilir GPS | KISMEN: sentetik lifecycle testleri eski GPS sahibini koruyup engel durumunu gösterir; gerçek SDK callback yarışı boyunca tüm veri/ağ erişimi NOT TESTED. |
| G aynı UID token refresh | KISMEN: mevcut event projection testi aynı UID'yi deduplicate eder; gerçek SDK refresh ve tüm ağ yarışları NOT TESTED. |
| H bozuk/tekrar callback | NOT TESTED: bu turda gerçek SDK callback replay/expiry akışı çalıştırılmadı. |
| I profil yüklenirken hesap değişimi | NOT TESTED: gerçek SDK/HTTP yarışı için owner-coordinated sonuç kanıtı yok. |
| J eski owner adına bekleyen ağ isteği | KISMEN: adapter öncesi/sonrası UID/lease guard testleri var; credential seçiminin atomik bağlandığı kanıtlanmadı. |
| K hata ve yeniden başlatma | KISMEN: mevcut sentetik owner recovery testleri var; gerçek SDK session restore ile uçtan uca NOT TESTED. |

## En dar güvenli alternatif

Play Auth kapalı kalmalı. Sonraki tasarımda SDK'nın otomatik callback/session mutasyonunu ortak uygulama client'ından ayırmak veya devre dışı bırakmak; callback, explicit login/logout ve restore'u GPS fence altında kontrol edilen geçişten geçirmek; session değişimi ile owner yayınını tek onaylanmış bağlam olarak sunmak gerekir. Ağ istemcileri owner/epoch ve o owner'a bağlı immutable credential ile sınırlandırılmalı; token refresh ve iptal/giden HTTP yarışları ayrı kanıtlanmalıdır. Doğrudan SDK session'ı okuyan profil/Planet/sync yolları bu sınırın dışında bırakılmamalıdır. Bu bir mimari öneridir; burada uygulandığı veya yeterli olduğu iddia edilmez.

## Doğrulama

Gerçek SDK sıralama testi ve mevcut owner/lifecycle/sync adapter paketi: **61 geçti / exit 0**. Sıralama testi düzeltme sonrası ayrıca **1 geçti / exit 0** ve hedefli `dart analyze` temiz. Tam `flutter analyze --no-pub` ilk çalışmada test dosyası için iki yeni bulgu üretti; gereksiz import kaldırıldı ve internal gözlem testte açıkça işaretlendi. Tekrarlanan tam analiz **exit 1**, önceki baseline ile aynı **3 warning + 4 info**, yeni bulgu yok. Gerçek hosted veri, e-posta, cihaz, PROD activation veya feature gate işlemi yapılmadı.
