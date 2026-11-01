# Google Play Data Safety — Teknik Envanter Taslağı

> **[ONAY BEKLİYOR — Play Console formu değildir, gönderilmemelidir.]** Beyan; yayımlanacak tam APK/AAB, compile-time flag'ler ve tüm SDK'ların veri toplama davranışı üzerinden son kez doğrulanmalıdır. Play, uygulama ve SDK verilerini geliştiricinin beyan sorumluluğuna dahil eder.

Kaynak: [Google Play Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en), [Background location policy](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en), [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

| Play kategori adayı | Teknik kanıt / ne zaman | Paylaşım ve şifreleme | Silme durumu / form notu |
|---|---|---|---|
| Location — precise | Android fine/background permissions (`AndroidManifest.xml:4-6`), GPS SQLite/route telemetry; sürüş başlatıldığında ölçüm. | Mapbox road matching çağrısında ham coordinates gönderilir; Planet source upload yalnız yayın eylemi; Supabase cloud yalnız doğrulanmış sync opt-in. HTTPS. | Hesap silme ile yerel/backup GPS silinmesi yok; retention unspecified. Arka plan izni için Play prominent disclosure ve policy declaration gerekir. |
| Personal info — email | Supabase Auth hesaplarında; destek e-postasıyla kullanıcı talep gönderirse. | Supabase/Auth ve Google Mail altyapısı. TLS in transit; sağlayıcı ayrıntıları doğrulanmalı. | Prod signup kapalı; release'te kayıt açılmadan form/flows doğrulanmalı. Silme operasyonu PROD'da aktif değil. |
| Personal info — name / username | Profile metadata ve `profiles`; username/display_name; all authenticated SELECT policy. | Planet profil görünürlüğü nedeniyle authenticated audience; avatar URL durumu değişken. | UI/API silme ve reuse davranışı doğrulanmalı. |
| Photos and videos / user-generated content | Profile photo local bytes (`profile_storage_service.dart`) ve Planet publish payload/road contribution. Profile photo cloud bucket usage not proven by source in this audit. | Planet content may be visible to authenticated users; exact public scope must match backend policies. | Profile photo lifecycle and deletion/backup not verified. Do not select category without build-level validation. |
| App activity / app interactions | Drives, scores, telemetry, sync state, publish status. | Local; cloud only feature-enabled; Planet explicit publication. | Retention/deletion incomplete. |
| Diagnostics | Supabase provider logs and OS/app errors can exist; direct Firebase Analytics/Crashlytics/Sentry dependencies not found in `pubspec.yaml` scan. | Actual SDK transitive data collection/log fields require SDK inventory. | Provider log retention not verified. |
| Device or other IDs | Auth UID and owner IDs are processed; Google/Map SDK may have SDK/device identifiers. | Supabase and map providers. | Exact Play category and SDK collection to be confirmed against generated dependency/SBOM and SDK docs. |

## Önerilen form ön değerlendirmesi

- **Konum** kategorisi kesin adaydır; precise location used and may be shared with Mapbox/Planet/Supabase under specific user actions/configuration. Do not claim data is never shared.
- **Email, name/user ID** categories apply to account build when accounts are enabled. A build with signup disabled still may hold/restore logged-in account state; inspect actual distribution config.
- **Deletion request**: app and out-of-app entry points are not operationally accepted yet. A static unpublished site or Gmail address alone does not prove completed account deletion. Play needs a working out-of-app deletion request method and disclose data retained/why.
- **Encryption in transit**: Supabase/Mapbox calls use HTTPS. Need verify every endpoint and SDK; local app-private SQLite/Hive is not app-level encrypted in code. Play at-rest claim should be evaluated per category/platform protection, not stated as custom encryption.
- **Optional vs required**: permissions, login, Planet publish, Mapbox matching and cloud-sync distinctions must be reflected based on actual UI and release flags.
- **SDK inventory**: review Flutter plugin/transitive Android SDKs and Google Maps SDK Data Safety declarations before filing.
