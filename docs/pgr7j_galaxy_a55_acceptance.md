# P-GR7J — Galaxy A55 cihaz kabulü

## Sonuçlar

| Kontrol | Sonuç | Kanıt / sınır |
| --- | --- | --- |
| A55 ve eski paket | PASS | Model SM-A556E; `com.example.driveit_project` kurulum öncesinde ve sonrasında kurulu. |
| Yeni APK | PASS | Güncel release build exit 0; package `com.osaracx.driveit`, versionCode 1, versionName 1.0.0, target SDK 36. |
| Callback ve backup | PASS | APK manifestinde `com.osaracx.driveit://auth/callback` ve `allowBackup=false` doğrulandı. |
| Upload imzası | PASS | APK imzası doğrulandı; sertifika SHA-256 `9833ce68f6e38356f2690287ff04962ca55d4dec082c1e3d0100409485325ad3`. APK SHA-256 `b70d698e87fdc0d887d9d8db08d75f6675d91af03b072ffe44830a1f93882ae5`. |
| Kurulum | PASS | Yeni paket önceden kurulu değildi; yalnız yeni paket kuruldu. `adb install` exit 0. |
| Yan yana uygulamalar | PASS | Kullanıcı 0 için eski paket UID 10385, yeni paket UID 10392. Farklı UID uygulama sandbox ayrımının kanıtıdır; içeriklerin test edilmesi değildir. |
| İlk açılış | PASS | Yeni uygulama `Hoş Geldin`, 1/6 onboarding ekranıyla açıldı. |
| Hukuki onboarding | PASS (engel) | Kullanıcı 4/6 Yasal ve Güvenlik ekranına ulaştı. KVKK, gizlilik ve koşullar hukuki inceleme bekliyor; kullanıcı devam düğmesine basamadı. Düğüm tıklanamaz ve kaynak koddaki koruma sürüyor. Hukuki onay atlatılmadı. |
| Yeni geçmiş ve istatistik | NOT TESTED | Hukuki onboarding engeli nedeniyle geçmiş/istatistik ekranlarına erişilmedi. Boş oldukları iddia edilmez. |
| Eski sürüşlerin erişilebilirliği | NOT TESTED (kurulum sonrası) | Eski paket hâlâ kurulu; kullanıcı geçmişin P-GR7F sırasında göründüğünü bildirdi. Bu kurulumdan sonra eski geçmiş tekrar açılıp doğrulanmadı. Eski Hive/SQLite dosyalarına erişilmedi. |
| Eski veri aktarılmaması | KISMEN | Farklı paket/UID ve kapalı Android backup doğrulandı. Yeni uygulama geçmiş ekranına erişilemediğinden tam içerik kabulü yapılmadı. |
| Cloud/Group/deletion | KISMEN | Build komutunda owner activation, account sync, account deletion ve Group Drive kapalı; R1 guard Supabase URL ve anahtarı reddediyor. Hosted PROD/DEV ile uçtan uca işlem yapılmadı. |

## Otomatik testler

- Ortam politikası, Auth callback, GPS sahipliği ve hukuki onboarding: **32 geçti, exit 0**.
- Android backup politika testi: **PASS, exit 0**.
- İlk APK doğrulama komutunda PowerShell pipeline çıkış kodu yanlış okundu; düzeltildikten sonra gerçek APK kimliği, manifest ve imza kontrolü **exit 0** ile geçti.

## Güvenlik ve kalan işler

Kurulumdan önce eski `com.example.driveit_project` paketinin kurulu ve yeni paketin kurulu olmadığı doğrulandı. Eski uygulama kaldırılmadı, güncellenmedi, temizlenmedi; eski sürüş verilerine erişilmedi. Kullanıcı onboarding'i kendisi ilerletti; asistan daha sonra yalnız ekran ve paketleri salt okunur inceledi.

Hukuken onaylı ve sürümlü belgeler hazır olmadıkça onboarding engeli korunmalıdır. Boş geçmiş, sıfır istatistik, veri aktarılmaması ve eski geçmişin kurulum sonrası erişilebilirliği gerçek cihazda henüz kabul edilmedi. Bu APK'da Supabase yapılandırması ve kişisel bulut kapalıdır; PROD Auth allowlist'i önceki HTTP 401 nedeniyle bu görevde doğrulanmadı. Play App Signing dağıtım sertifikası ayrıca doğrulanmadı. AAB/Play Console'a yükleme yapılmadı.
