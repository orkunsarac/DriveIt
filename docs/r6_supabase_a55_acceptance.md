# R6 gerçek Supabase + Samsung A55 kabulü

Tarih: 2 Kasım 2026

Hedef proje: onaylı Planet DEV (`viqngnjfgknpxtoapzcg`)

Cihaz: Samsung SM-A556E (`R5CX42V8GSJ`)

Test paketi: `com.example.driveit_project.isolated_test`

## Kapsam ve güvenlik

- DEV Auth, PostgREST, Storage ve Edge Function istekleri gerçek HTTP üzerinden yapıldı. Test hesapları geçici `@example.invalid` adresleriydi; Auth Admin API ile doğrulanmış olarak oluşturuldular. E-posta veya SMTP kullanılmadı.
- İzole test uygulaması gerçek DriveIt owner runtime, Supabase Flutter SDK ve Android `flutter_secure_storage` kasasını kullandı. GPS sürüşü cihaz sensöründen değil, testte SQLite/GPS journal içine yazılan sentetik 301 noktadan üretildi.
- Test derlemesi `.isolated_test` paket kimliğini doğruladı. Play Auth ana kapısının bu pakette kapalı olduğu ayrıca doğrulandı. Group Drive kapalı kaldı.
- `com.osaracx.driveit` ve `com.example.driveit_project` A55 paketleri kurulu kaldı. Test APK'sı testten sonra kaldırıldı. Eşleşen geçici DEV hesapları ve yalnız bunların tamamlanmamış staging nesneleri/intentleri, snapshot ve sequence satırları temizlendi; son Auth envanterinde bu test adlandırmasına uyan hesap sayısı **0**.
- PROD projesine istek gönderilmedi; PROD ayarları, signup, SMTP, cron ve Play kapıları değiştirilmedi.

## Gerçek A55 test sonuçları

| Senaryo | Bağımlılık | Beklenen | Gerçek sonuç | Durum |
|---|---|---|---|---|
| İzole paket / Play Auth kapısı | Android paket bilgisi | Test paketi ayrık, Play Auth kapalı | Doğru `.isolated_test` kimliği; gate kapalı | PASS |
| Guest → Hesap A, profil okuma | Gerçek DEV Auth + PostgREST | Doğru owner açılır | Yanlış parola Guest'te kaldı; A girişi ve profil sorgusu başarılı | PASS |
| Sürüş ve Drive Score | Gerçek DriveIt owner/GPS kodu; sentetik GPS noktaları | Yerel kayıt owner altında saklanır | 301 nokta journal'dan kaydedildi; skor A altında üretildi | PASS |
| Buluta upload / aynı hesapla indirme | Gerçek DEV Storage + `phase8-drive-begin/finalize` | Kayıt tamamlanır ve yeniden indirilir | Begin ve Storage staging sonrası finalize `422 staged_envelope_rejected` döndürdü; aynı hesap indirmesi çalıştırılamadı | BLOCKED |
| A → B yerel ve bulut görünürlüğü | Gerçek DEV Auth ve uygulama owner runtime | A verisi B'ye açılmaz | B owner oldu; A'nın yerel sürüşü/skoru görünmedi; B'nin değişiklik sayfası boş döndü | PASS, fakat finalize başarısız olduğundan sunucuda tamamlanmış A kaydı için negatif erişim testi yok |
| A staging nesnesini B ile okuma | Gerçek DEV Storage | Erişim reddedilir | B'nin gerçek istekle indirme denemesi `StorageException` ile reddedildi | PASS |
| Android kasası restore'u | A55 Keystore kasası + gerçek DEV `getUser` doğrulaması | Owner, doğrulamadan sonra açılır | Aynı Android kasası ve izole SQLite köküyle yeni Supabase SDK/runtime kuruldu; sunucu doğrulamasından sonra A owner açıldı | PASS |
| Token yenileme ve süreklilik | Gerçek DEV refresh endpoint'i | Aynı owner, yeni tokenlar kasaya yazılır | Access/refresh token döndü; kimlik A kaldı ve yenilenen oturum kasada doğrulandı | PASS |
| Logout ve yeniden giriş | Gerçek DEV Auth | Guest'e kapanır; tekrar giriş doğru owner'ı açar | Vault temizlendi; A yeniden giriş yaptı ve yerel sürüşünü gördü | PASS |
| Aktif/kurtarılabilir GPS sırasında hesap değiştirme | Gerçek DriveIt GPS journal + Auth servis çağrısı | Owner değişimi engellenir, journal korunur | Her iki durumda da A↔B geçişi reddedildi; journal satırı ve sonlandırılmış sürüş korundu | PASS |
| Şifre doğrulamalı hesap silme / receipt | Gerçek DEV Edge Function | Yalnız geçici A silinir ve receipt tamamlanır | `delete-account` DEV Function envanterinde yok; gerçek istemci çağrısı HTTP 404 verdi, oturum açık kaldı | BLOCKED |
| Planet / Dünya okuma ve yayın | Onaylı DEV Planet | Owner kapsamı gerçek sunucuda doğrulanır | İzole paket Play Auth kapısını açmadığı için Planet istemcisi oluşturulmadı; yayın/okuma isteği yapılmadı | BLOCKED, güvenlik kapısı kasıtlı kapalı |
| Ağ kesintisi ve hesap değişimi yarışı | A55 gerçek ağ | Bulut kapalı kalır, yerel kayıt korunur | Ayrı ağ kesintisi uygulanmadı; yanlış parola ve aktif/kurtarılabilir GPS owner yarışları test edildi | NOT RUN |

## Sunucu engelleri

1. DEV `phase8-drive-finalize` gerçek isteğe genel `staged_envelope_rejected` 422 yanıtı verdi. İstemcinin yerel zarf şekli kontrolü geçti; Edge yanıtı alt doğrulama nedenini dışarı vermedi. DEV Function logları ve deployed validator/sözleşme karşılaştırması gerekiyor. Sunucu veya istemci sözleşmesi uyumlandırılmadan upload ve aynı-hesap download PASS sayılamaz.
2. DEV Function envanterinde `delete-account` yok ve endpoint 404 dönüyor. Güvenli silme/receipt kabulü için DEV'de onaylı şema ve Function dağıtımı gerekli. Test başarısızlıkları sonrasında geçici Auth hesaplarının silinmesi ayrıca scoped Admin API cleanup ile yapıldı; bu, uygulama silme akışının kabulü değildir.
3. Planet okuma/yayın kabulü için Play/Auth ve yayın kapıları açılmadı. Bu görevde güvenlik gate'lerini gevşetmek veya canlı aktivasyon yapmak kapsam dışıdır.

## Çalıştırılan kontroller

- `dart format integration_test/r6_real_supabase_a55_acceptance_test.dart`: PASS.
- `flutter analyze integration_test/r6_real_supabase_a55_acceptance_test.dart`: PASS, issue yok.
- `tool/run_android_integration_test.ps1` ile A55 üzerinde gerçek Flutter/Gradle derlemesi, izole kurulum ve hedefli entegrasyon: **1 test PASS**. Çıktıdaki aşamalar Auth, gerçek runtime restore, refresh, A/B Storage ayrımı, GPS owner fence ve silme Function yokluğunu içerdi.
- Testte runtime/SDK yeniden oluşturuldu; Android uygulama süreci ADB ile force-stop edilip yeniden başlatılmadı. Gerçek OS process-death kabulü ayrı test olarak kalır.
- Tam R6 regresyonu yapılmadı.
