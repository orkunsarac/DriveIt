# P-GR7I Aşama 1 — PROD Auth ve bulut mimarisi

Durum: **mimari kabul ve dar güvenlik düzeltmesi; PROD aktivasyonu yapılmadı**. İlk yayın kapsamı hesap/profil, kişisel bulut, Benim Dünyam/Planet ve hesap silmedir. Grup Sürüşü kapsam dışıdır. Bu inceleme repository ve yerel test kanıtıdır; hosted PROD durumu veya gerçek cihaz uçtan uca kabulü değildir. R1 Gradle ve imza araçları çalışma ağacında önceden mevcut, commit edilmemiş değişikliklerdir.

## Bağımlılıklar ve riskler

| Bileşen | Kod kanıtı ve bugünkü durum | Eksik / risk / kabul önkoşulu |
| --- | --- | --- |
| Paket ve ortam | `lib/config/supabase_environment_policy.dart:3`, `lib/config/supabase_bootstrap.dart:56`; Play sadece exact PROD HTTPS host, yeni DEV yalnız DEV kabul eder. R1 Play guard (`android/app/build.gradle.kts:60`) Supabase define ve cloud aktivasyonlarını reddeder. | Runtime kontrolü yalnız bu bootstrap üzerinden yapılan bağlantıyı kapsar; tüm bağımsız client çağrıları ve release artefaktı için ayrıca statik ve entegrasyon denetimi gerekir. Başka bir kod yolunun DEV'e erişmesinin imkânsız olduğu genel olarak kanıtlanmadı. |
| Bootstrap / anahtar | `supabase_bootstrap.dart:56` ve `supabase_public_key_policy.dart`: yalnız public key biçimleri/legacy `anon` rol claim'i kabul edilir. | Bu runtime kontrolü JWT imzasını doğrulamaz ve yanlışlıkla binary'ye gömülmüş secret'ı geri alamaz. Gerçek secret'ları build'e vermemek ve release secret taraması ayrıca zorunludur. PROD public key ve hosted ayarları bu turda okunmadı. |
| Auth PKCE/callback | `lib/config/driveit_auth_callback.dart`, `supabase_bootstrap.dart:69`, `lib/services/supabase_account_service.dart:324`, `:354`, `:381`: signup, login ve recovery kodları mevcut. | R1'de Supabase yapılandırılmadığından Auth kapalı; PROD redirect allowlist önceki salt okunur kontrolde HTTP 401 nedeniyle doğrulanamadı. OTP/replay, cihaz ve aynı cihazda PKCE kabulü, SMTP ve kontrollü hosted erişim gerekir. |
| Sahiplik ve oturum | `lib/services/local_owner_lifecycle.dart:68`, `:1763`, `lib/services/supabase_account_service.dart:169`: lease/epoch ve identity change fencing var; `lib/config/local_ownership_gate.dart` varsayılan kapalı. | R1 owner activation guard tarafından kapalı; Play'e özgü gerçek composition ve kayıt esnasında Auth değişimi henüz kabul edilmedi. Eski DEV sandbox verisi otomatik taşınmayacak. |
| Kişisel sync | `lib/services/production_owner_runtime_factory.dart:62`, `:125`, `lib/services/supabase_owner_drive_sync_adapter.dart`: opt-in, owner lease ve backend sözleşmesi mevcut. | Factory şu anda yalnız DEV URL'sini kabul eder; PROD için güvenli biçimde başarısız olur, PROD sync hazır değildir. Upload/download, ACK, cursor, retry, tombstone, iki hesap/iki cihaz ve legacy kayıt sınırları yeniden doğrulanmalı. |
| Benim Dünyam / Planet | `lib/features/world_publish/segments/planet_publication_section.dart:122`, `lib/features/world_publish/services/world_publish_service.dart:83`: yayın altyapısı ve UI mevcut. | R1'de Auth yapılandırması yok. Kamuya yayın ayrı kullanıcı onayı ister. Yayını geri alma, kişisel kaynak, ortak yol katkısı ve isolated-to-PROD sözleşmeleri ayrı doğrulanmalı. |
| Hesap silme | `lib/services/account_deletion_runtime.dart:53`, `lib/services/supabase_account_service.dart:172`, `lib/services/account_deletion_controller.dart:157`: owner guard ve `blocked_planet` ele alınıyor. | R1 gate kapalı; PROD worker/işletim, web başvuru yolu, yedekler, hesap sahipliği kanıtı ve terminal sonuç kabul edilmedi. Ortak Planet saklama politikası hukuki inceleme bekliyor. |
| Hukuki/Group | `assets/legal/legal_documents.json:7` ve `lib/features/onboarding/screens/legal_safety_onboarding_page.dart:73` pending belgelerle devamı engeller. Group Drive ayrı flag ve sunucu gate arkasında. | Onaylı sürümlü belgeler, Google Play beyanları ve hesap silme URL'si bekliyor. Group ilk yayında açılmayacak. |

## DEV sabit referanslarının etkisi

`production_owner_runtime_factory.dart:131` sync adapter kurulumunu DEV URL'sine kısıtlar; `:152` Group servisini DEV URL'sine kısıtlar. Bunlar PROD endpoint'ini DEV'e dönüştürmez: bootstrap Play için DEV URL'sini reddeder; mevcut R1 guard da Play Supabase yapılandırmasını engeller. Ancak aynı sabitler PROD sync'i **engeller**. Bu dosyada PROD'u kabul edecek değişiklik yapılmadı; bağımsız istemcilerin ve bütün derleme varyantlarının hiçbir şekilde DEV'e yönlenemeyeceği henüz uçtan uca kanıtlanmadı.

## Bağımsız aşamalar ve durdurma noktaları

| Aşama | Küçük iş / kabul kriteri | Test ve durdurma |
| --- | --- | --- |
| A1 Auth konfigürasyonu | Paket-proje-public key eşlemesi ve build secret guard'ı; PROD etkinleşmeden doğrulanabilir | Sentetik Play/DEV/yanlış host/key, callback, PKCE/replay. Secret veya belirsiz hedefte dur. |
| A2 Auth runtime | Play için açıkça tasarlanmış, gate kapalı composition | Yerel Auth/SMTP, signup/login/recovery, logout/session. Hosted signup için ayrı izin ve hukuk onayı olmadan dur. |
| B1 sahiplik | Play package için guest/account owner root ve kimlik switch fencing | Boş yeni sandbox, A→B/logout, aktif GPS/recovery; eski DEV verisi yok. Kayıp veya belirsiz owner'da dur. |
| C1 upload | PROD adapter seçimi ve mevcut bounded worker | Yerel sentetik offline/retry/idempotency/ACK ve lease; yanlış UID/PROD belirsizliğinde dur. |
| C2 download | Mevcut cursor worker'ın PROD sözleşmesi | Sayfalama, çakışma, tombstone, crash, farklı owner; veri bütünlüğü belirsizse dur. |
| D1 Planet | Kullanıcı onaylı yayın ve geri alma | Private/public ayrımı, Storage/RLS, kaynak ve diğer kullanıcı verisi; hukuki saklama veya silme belirsizse dur. |
| E1 silme | Sahiplik kanıtı, worker/retry ve `blocked_planet` | İzole Auth/Storage/Planet, audit ve failure/restart; terminal kanıt yoksa tamamlandı deme. |
| F1 cihaz kabulü | Ayrı Play paketinde gerçek ilk açılış ve iki hesap/cihaz | Açık kurulum/hosted test yetkisi ve onaylı belgeler; cihazdaki eski uygulama/verilere dokunma. |

## Bu aşamadaki değişiklik ve test

`SupabasePublicKeyPolicy` istemci başlatılmadan önce `sb_secret_`, legacy service-role claim'i ve bozuk key biçimlerini reddeder; `sb_publishable_` ve legacy `anon` biçimi kabul edilir. Bu, gerçek secret'ları istemciye koyma izni değildir ve build taramasının yerine geçmez.

Sentetik key, ortam, callback, GPS sahipliği ve hukuki onboarding testleri **33 geçti / exit 0**. Değişen Dart dosyaları `dart analyze` **No issues found / exit 0**. PROD/DEV servislerine bağlantı, signup, gerçek e-posta, migration, Play yükleme veya cihaz verisi değişikliği yapılmadı.

## Teknik ve hukuki engeller

Play R1'in local owner, Supabase ve feature guard'ları; PROD adapter composition; hosted Auth/SMTP/callback; backup ve hesap silme işletimi; Planet ortak katkıları; onaylı hukuki katalog ve Play Data Safety/konum beyanları. Bunlar ayrı aşamalar ve gerektiğinde ayrı kullanıcı onayı gerektirir. Bu rapor PROD'u yayına hazır ilan etmez.
