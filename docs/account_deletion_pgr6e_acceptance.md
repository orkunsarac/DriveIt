# P-GR6E — ücretsiz hesap silme başvuru hazırlığı

## Kapsam sonucu

- Statik sayfa `site/account-deletion/` altında genişletildi: DriveIt adı, başvuru yolu, silinecek veri kategorileri, cihazdaki yerel arşiv farkı, Planet `blocked_planet`, belirsiz saklama sınırları, destek adresi ve e-posta oluşturma/adres kopyalama seçenekleri bulunur.
- Pages paketi `site/` dizinidir; tracking, backend form, dış varlık, kullanıcı verisi gönderimi ve build bağımlılığı yoktur. Özel alan adı gerekmez. GitHub Free Pages için public repository gerekir. Workflow yalnız `workflow_dispatch` ile çalışır ve `confirm_publication=true` değilse deploy etmez. Workflow bu görevde çalıştırılmadı; site yayımlanmadı.
- Elle e-posta talebi doğrulama, vaka numarası ve durum takibi, yanlış hesaba uygulama engeli, `blocked_planet`, retry, completion kanıtı ve saklama kararları prosedür belgesinde tanımlandı.
- Auth e-posta akışları önceki P-GR6D yerel Mailpit testinden bağımsızdır. PROD SMTP hâlâ ayrıca kabul edilmelidir. Signup/worker/otomatik silme PROD'da açılmadı.

## Doğrulama

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/test_email_local.ps1` gerçek exit code **0** ile tamamlandı: **4 PASS / 0 FAIL**. 1 Auth+Mailpit entegrasyon testi (confirmation, recovery, password notice, double-confirm email change) ve 3 statik paket/gizlilik/yayın-gate testi geçti. Deno `check` de geçti. İlk birleşik çalıştırma, yeni workflow dosyasını okuyacak Deno izni eksikliğiyle başarısız oldu; yalnız gerekli `.github/workflows` okuma yolu test runner'a eklendi ve birleşik komut tekrar PASS oldu. Yerel statik testler adres butonunun ve kopyalama kodunun varlığını/yalnız tıklamayla çalışmasını doğrular; gerçek tarayıcı clipboard kabulü ayrıca manuel yapılmalıdır.

Gerçek GitHub Pages deployment'ı ve Android/Play Console URL kabulü kapsam dışıdır ve yapılmış gibi raporlanmaz. Google Play dış web kaynağının işlevsel, DriveIt'le ilişkili ve talep yolunun kolayca bulunur olmasını ister; gerçek URL ancak yayın sonrası dışarıdan doğrulanabilir.

## Açık yayın önkoşulları

1. Repository Pages için Free plan koşulunu (public repository) ve dosyaların kamuya açıklanabilir olduğunu doğrula.
2. Manuel challenge gönderimi ve vaka kaydını uygulayacak operatör sürecini kurup dene; mevcut statik sayfa kendi başına doğrulama/silme yapmaz.
3. Hukuk/veri sorumlusu saklama ve Planet açıklamalarını onaylasın.
4. Ayrı açık yayın onayından sonra Pages kaynağını GitHub Actions seçip workflow dispatch onay kutusunu işaretle; URL'yi dış ağdan test et.
5. Son URL'yi Google Play Console'daki hesap silme web kaynağı alanına ekle.
6. Auth doğrulama/kurtarma e-postaları için ayrı PROD SMTP kabulini tamamla.
