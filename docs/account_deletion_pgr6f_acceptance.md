# P-GR6F — hesap silme destek operatörü kabulü

## Sonuç

Yerel destek operatörü akışı, mevcut P-GR6A hesap silme iş kuyruğunu kullanacak şekilde eklendi. Başvuru kaydı, sahiplik doğrulaması, açık silme onayı ve terminal iş kanıtı birbirinden ayrıdır. PROD/DEV Auth, veritabanı, e-posta veya worker ayarlarına dokunulmadı; gerçek e-posta gönderilmedi ve gerçek hesap silinmedi.

## Uygulanan kontroller

- Operatör komutları sabitlenmiş P-GR6A descriptor'ı, Supabase stack kimliği, loopback API/DB, PostgreSQL fiziksel mount alt yolu ve system identifier eşleşmeden çalışmaz. Mailpit de yalnız loopback adresinde kabul edilir.
- Operatör tokenı Windows kullanıcısına bağlı DPAPI `Export-Clixml` dosyasında test-stack çalışma dizininde tutulur. Destek runner'ı tokenı çıktıya yazmadan belleğe alır ve işlem bitince ortam değişkenlerini geri yükler. Yerel case DB de aynı test-stack dizinindedir; bu sistem üretim için dağıtılmamıştır.
- Vaka başına rastgele UUID kullanılır. SQLite'ta ham e-posta veya challenge saklanmaz; e-posta adresi keyed HMAC ile parmak izine dönüştürülür. Sahip Auth UID'si ancak doğrulanmış e-posta challenge'ından sonra kaydedilir.
- Doğrulama kodu hash'lenmiş, tek kullanımlık, 15 dakika süreli ve 5 deneme ile sınırlıdır. Bilinmeyen/doğrulanmamış hesap için aynı genel kabul yanıtı verilir. Aynı aktif talebin tekrarı ikinci vaka veya ikinci e-posta oluşturmaz.
- Challenge teslimi başarısızsa vaka korunur; operatör `resend` ile aynı aşamada süreli yeni kod gönderebilir. Yeniden gönderim saatlik rate limit'e tabidir.
- Sahiplik kanıtından sonra ayrı challenge ve `DELETE MY DRIVEIT ACCOUNT` açık onayı gerekir. Akış mevcut `account_deletion_request`, oturum iptali ve `delete-account` worker'ını çağırır; yalnız worker'ın `completed` terminal yanıtı vaka tamamlandı sayılır. `blocked_planet` durumunda operatör retry'si işleme devam etmez.
- Worker geçici hata verirse vaka `retry_pending` olur ve mevcut idempotent retry RPC'si kullanılır. Ayrı worker mimarisi, PROD cron'u veya otomatik silme etkinleştirilmedi.

## Test kanıtı

- `tool/run_pgr6a.ps1 -SupportTest` — **exit code 0**, **1 geçti / 0 başarısız**. Gerçek izole Auth, Postgres, Edge ve Mailpit servisleri üzerinde operatör yetkisi, A/B yanlış hesap, doğrulanmış sahiplik, açık onay, bilinmeyen e-posta yanıtı, tekrar talep, Mailpit teslim 503'ü ve güvenli resend, challenge replay/expiry, worker 503 ve retry ile gerçek sentetik A hesabının tamamlanması doğrulandı. B hesabı korundu; sentetik Auth ve yalnız teste ait Mailpit iletileri temizlendi.
- `tool/run_pgr6a.ps1 -Filter "real Storage outage"` — **exit code 0**, **1 geçti / 0 başarısız**. Mevcut P-GR6A Storage hata/retry regresyonu korundu.
- Deno `check tool/account_deletion_support.ts` — **PASS**.
- Değiştirilen PowerShell runner'ları için PowerShell AST parse — **PASS**.
- İlk sandbox çalıştırması Supabase CLI'nin npx önbelleği bulunmadığı için npm registry DNS erişiminde durdu. Onaylı elevated yerel çalıştırma ile mevcut Supabase CLI ve Docker test ortamı kullanıldı; başarılı tam test sonucu exit code 0 olarak alındı.

## Sınırlar ve kalan kabul

Bu araç yalnız yerel operatör/test prototipidir. Üretim destek posta kutusu entegrasyonu, operatör kimlik sağlayıcısı, yetki iptali/audit saklama işletimi, güvenli ekip vaka kasası, gerçek e-posta sağlayıcısı, hukuki saklama ve incident prosedürleri tanımlanıp bağımsız güvenlik incelemesinden geçmeden PROD'da kullanılmamalıdır. Kullanıcı challenge kodlarını operatöre e-posta yanıtıyla iletir; operatör bunu doğrulanmış Auth adresiyle eşleşen kod olarak girer. Kodlar/vaka içerikleri issue, log veya sohbetlerde tutulmamalıdır.

GitHub Pages `workflow_dispatch` workflow'u `.github/workflows/publish-account-deletion-site.yml` içindedir ve ayrıca `confirm_publication=true` ister. GitHub dispatch için workflow dosyası repository'nin varsayılan dalında bulunmalıdır. Bu aşamada workflow çalıştırılmadı veya yayımlanmadı. Özellik dalının tamamını varsayılan dala taşımadan, yalnız bu dosya için varsayılan daldan ayrılan kontrollü bir PR hazırlanmalıdır; PR merge ve ayrı yayın onayı olmadan dispatch yapılmamalıdır.
