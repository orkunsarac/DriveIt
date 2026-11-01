# P-GR7I Aşama 2 — Auth yapılandırma güvenliği

## Sonuç ve sınır

Play package/proje ve DEV package/proje doğrulaması `lib/config/supabase_environment_policy.dart` üzerinden fail-closed yürür. Play release guard Supabase define'larını ve cloud feature aktivasyonunu reddetmeye devam eder. Hosted PROD Auth, signup, SMTP, callback allowlist ve gerçek anahtarın proje sahipliği bu aşamada test edilmedi veya etkinleştirilmedi.

## Değişiklik

- `android/app/client_secret_guard.gradle`, Android build'in Dart define girdilerinde `sb_secret_`, service-role adları ve service-role claim'li JWT'leri reddeder. Geçersiz kodlanmış define reddedilir; hata mesajları değerleri yazmaz. Mevcut Gradle yapılandırmasına yalnız script çağrısı eklendi.
- Bu kontrol bilinen biçimleri kapsar; bütün olası secret biçimlerinin veya kaynak dosyalarına önceden yazılmış secret'ların yokluğunu matematiksel olarak garanti etmez. Runtime `SupabasePublicKeyPolicy` JWT imzasını doğrulamaz; public key'in biçimi veya anon claim'i doğru projeye ait olduğunu kanıtlamaz. Gerçek public key yalnız kontrollü PROD proje envanterinden, ayrıca sunucu doğrulamasıyla kullanılmalıdır. Hiçbir service-role/secret anahtar istemciye verilmemelidir.
- `SupabaseBootstrap.authOptions` aynı PKCE S256 yapılandırmasını ve exact URI predicate'ini kullanır. `test/supabase_pkce_configuration_test.dart`, gerçek SDK'yı sentetik HTTP ve bellek içi PKCE depolamasıyla çalıştırıp recovery isteğindeki S256 challenge ve Play callback'i doğrular. Hosted OTP, expiration, replay ve gerçek cihaz link açılışı test edilmedi.

## Gerçek test sonuçları

- Ortam, public/secret key, callback ve sentetik SDK PKCE testleri: **11 geçti / exit 0**.
- `tool/test_client_secret_guard.ps1`: **3/3 PASS / script exit 0**; public synthetic Gradle exit 0, synthetic secret ve service-role için beklenen exit 1; test hata çıktılarında sentetik değerlerin veya kodlanmış girdinin olmadığını kontrol eder.
- Mevcut yerel R1 Play guard testi: synthetic PROD URL ile `DRIVEIT_PLAY_RELEASE=true` altında yapılandırma reddedildi (beklenen Gradle exit 1). Guard gevşetilmedi.
- Önceden üretilmiş `app-release.apk` ve `app-release.aab` ZIP girdileri açılarak ham `sb_secret_`, özel anahtar PEM ve service-role JWT kalıpları için tarandı: **0 eşleşme / exit 0**. Bu tarama yeni kodu içeren build değildir; şifrelenmiş, parçalanmış veya bilinmeyen secret biçimlerini yakalamayabilir. Hiçbir secret değeri raporlanmadı.

## Sonraki aşama önkoşulları

`lib/services/production_owner_runtime_factory.dart:131` ve `:152` hâlâ DEV URL'sine sabitlenmiştir. PROD adapter seçimi, owner lease/epoch, sunucu yetkileri ve Play native runtime marker'ı sonraki aşamada izole olarak ele alınmalıdır; bu aşama sync veya Planet'i açmaz. `pending_legal_review`, signup, Group Drive ve deletion worker kapalı kalır. Gerçek hosted yapılandırma ve çok cihaz kabulü **NOT TESTED**.
