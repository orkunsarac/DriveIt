# P-GR6F yerel destek operatörü runbook'u

## Kapsam

Bu runbook yalnız sentetik test için izole P-GR6A stack'inde çalışır. `tool/run_pgr6f_operator.ps1` her çağrıda stack descriptor/ID, loopback API ve DB, Docker database container'ı, mount alt yolu, PostgreSQL system identifier, Auth health ve loopback Mailpit health kontrollerini yapar. Eşleşme yoksa işlem başlamaz. Runner PROD/DEV URL veya kimlik bilgisi kabul etmez.

Üretim vaka işlemi için kullanılabilir bir servis değildir. DPAPI kaydı, vaka SQLite dosyası, worker anahtarı ve Mailpit bu çalışma alanındaki yerel disposable test stack'ine aittir.

## Yerel komutlar

Önce izole test ortamı ve e-posta bağımlılığını hazırla:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6a.ps1 -PrepareOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/test_email_local.ps1
```

Sonra her işlemde tekrar pin kontrolleri yapan operatör arayüzünü aç:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6f_operator.ps1 -Action open
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6f_operator.ps1 -Action resend -CaseId <vaka-uuid>
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6f_operator.ps1 -Action verify -CaseId <vaka-uuid>
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6f_operator.ps1 -Action consent
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/run_pgr6f_operator.ps1 -Action status
```

Komutlar e-postayı ve kodu terminalden operatörün girmesini ister. Yerel testte iletiler Mailpit'tedir. `open` tek başına silme başlatmaz; önce doğrulama ve sonra ikinci açık onay gerekir. E-posta teslimi hata verirse `resend` aynı vaka ve aynı aşama için yeni, süreli challenge üretir; saatlik rate limit uygulanır. `retry` yalnız `retry_pending`, `processing`, `revocation_pending` veya `queued` durumlarında mevcut iş kuyruğuna gider. `blocked_planet` operatör retry'siyle aşılmaz ve insan incelemesine kalır.

## Veri ve erişim kuralları

- Adresi yalnız doğrulanmış, anonim olmayan Supabase Auth kullanıcısı olarak çözümle; e-posta adresini, tokenı, challenge kodunu veya özel rota verisini log/issue/sohbete kopyalama.
- Genel başvuru yanıtı adresin hesap olup olmadığını açıklamaz.
- Vaka UUID'si ve olay zamanları case store'da tutulur; ham e-posta ve kod tutulmaz. Adres HMAC anahtarı operatör tokenından domain-separated türetilir; operator DPAPI kaydı kaybolursa yerel bekleyen vakalar eski parmak izi anahtarıyla çözümlenemeyebilir. Böyle bir durumda tekrar başvuru açmadan önce vakayı operatörce incele.
- SQLite dosyasını yalnız yetkili Windows hesabının eriştiği, BitLocker korumalı cihazda tut. Bu prototip case store şifrelemesi veya çok operatörlü eşzamanlı çalışma sağlamaz.
- İşin tamamlandı bildirimi için yalnız mevcut worker'ın terminal `completed` durumu kanıttır. HTTP hata, timeout, `pending`, `busy`, retry veya `blocked_planet` tamamlanma değildir.
- `status` çıktısı yalnız vaka UUID'si ve eylem/zaman event'lerini içerir; çıktı da yine vaka verisi sayılır.

## Kamuya açık başvuru sayfası

`.github/workflows/publish-account-deletion-site.yml` yalnız `workflow_dispatch` ve doğru `confirm_publication=true` girdisiyle deploy eder. GitHub workflow dispatch'in çalışabilmesi için dosya varsayılan dalda mevcut olmalıdır. Hazırlıkta yalnız bu workflow dosyasını taşıyan ayrı PR aç; feature dalının geri kalanını default branch'e merge etme. Bu PR'nin merge edilmesi siteyi yayımlama onayı değildir. Kullanıcıdan ayrı açık yayın onayı alınmadan workflow dispatch etme.

## Üretim önkoşulları

Üretime geçmeden önce destek adresi işletimi ve erişim sahipliği, Auth'a doğrulama iletisi gönderme yöntemi, challenge/retry SLA'sı, vaka/audit saklama süresi, hukuki metinler, operatör kimlik doğrulaması ve bağımsız güvenlik değerlendirmesi onaylanmalıdır. Hukuki karar verilmemiş Planet saklama sınırları bu araçta tamamlandı olarak gösterilmez. Auth e-posta SMTP kabulü, manuel destek e-postası kanalından ayrıdır.
