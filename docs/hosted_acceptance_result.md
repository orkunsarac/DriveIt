# Kontrollü PROD servis kabulü

Tarih: 2 Kasım 2026. Hedef: yalnız `arwnbogcswisfesayosy`.

**Dar hosted servis kabulü PASS**, Deno exit code **0**, son tam akış 34 saniye. Fiziksel cihaz/Flutter üretim kabulü veya genel beta yayını değildir.

## Önce uygulanan ayrı onaylı düzeltme

Kullanıcı onayıyla `202611020001` ve `202611020002` tek transaction'da uygulandı; yalnız `delete-account` güncellendi. PROD **52 migration** oldu. Tüm52 SQL hash'i ve **22 tablo / 16 politika / 74 fonksiyon** yerel52 referansla birebir eşleşti. Mevcut migration dosyaları ve sürüş skorları değiştirilmedi.

## Gerçek servis senaryoları

| Senaryo | Sonuç |
|---|---|
| Admin API ile iki sentetik hesap, gerçek parola girişi, profil trigger'ı | PASS |
| B'nin A profilini değiştirememesi | PASS |
| Private Storage ve B'nin A kaynağını okuyamaması | PASS |
| Cloud begin → upload → finalize → kesin ACK | PASS |
| Kayıp ACK benzeri tekrar, aynı fingerprint ACK ve farklı hash conflict | PASS |
| A'nın bağımsız ikinci SDK istemcisinden aynı canonical mutation'ı indirmesi | PASS |
| B'nin A bulut kayıtlarını görmemesi | PASS |
| Bulut kaydı silme, tombstone download, duplicate retry ve B yetki reddi | PASS |
| Group Drive create sunucu gate reddi | PASS; gate hiç açılmadı |
| Gerçek Mapbox, iki schema2 yayın, aynı rota üzerinde karşılaştırma | PASS |
| Yetkili Planet viewport/detail ve özel GPS alanlarının projeksiyondan dışlanması | PASS |
| A hesabının parola doğrulamalı silinmesi, JWT taşımayan receipt resume | PASS |
| A silinirken B'nin profili ve yayımlanmış katkısının korunması/replay | PASS |
| İki hesabın ve yalnız kendi kaynaklarının temizlenmesi | PASS |

Bu, tek Deno uçtan uca test içinde ardışık senaryolardır; ayrı test sayısı olarak sayılmaz. İkinci SDK istemcisi ikinci fiziksel telefon değildir. Mapbox için yalnız önceden belirlenmiş kamuya açık Berlin noktalarından sentetik rota üretildi; cihaz veya kullanıcı GPS dosyası kullanılmadı. Telemetri açıkça sentetiktir. Profil okuma görünürlüğünün mevcut authenticated tasarımı değiştirilmedi; hukuki kararı hâlâ bekler.

## Başarısız ilk koşu ve güvenli kurtarma

İlk koşu Planet insert aşamasında çalıştırıcının yayın ID'sini kendisinin yazmaya çalışması nedeniyle başarısız oldu. Gerçek uygulama sözleşmesi sunucunun ID üretmesidir; tablo yetkisi gevşetilmeden harness düzeltildi. Aynı koşuda hesaplar gerçekte silindiği halde özel bulut tablolarına doğrudan service-role SELECT ile temizlik kontrolü istenmesi yanlış pending üretti. Terminal receipt ACK'leri şifreli journal'dan uzlaştırıldı; Management API readonly sayımları bağımsız temizlik kanıtını sağladı. Bu ilk koşu tam kabul sayılmadı.

İlk iki hesap tamamen temizlendikten sonra ikinci iki-hesap koşusu yapıldı: toplam dört geçici sentetik hesap, aynı anda en fazla iki; sonuçta sıfır. İki koşunun journal UUID'leriyle ayrı ayrı salt okunur doğrulama yapıldı. Auth, profiles, publishes, roads, sekiz özel bulut tablosu, Storage owner/path prefix'leri, deletion job owner bağlantıları, trace ve generation source bağlantıları **0**. Yalnız sistemin tasarlanan minimize audit/terminal receipt kayıtları ve kimliksiz generation sayaçları kalabilir; tüm veritabanı boşaldı iddiası yoktur.

Parolalar ve receipt'ler yalnız repository dışındaki Windows DPAPI journal'ında; anahtarlar yalnız sunucu test sürecinde tutuldu. Sohbete/loga/GitHub'a yazılmadı. Şifreli kayıtlar izinsiz silinmedi. Zorunlu silme korumaları veya RLS aşılmadı; cleanup için geniş SQL DELETE kullanılmadı.

## Son durum ve kalan kabul

- ACTIVE_HEALTHY; kullanıcı **0**, migration **52**, signup kapalı, anonim signup kapalı, Group Drive FALSE, deletion cron **0**, bucket'lar private.
- Play callback exact allowlist girdisi mevcut. Ancak **Site URL hâlâ localhost**. Onaylanmış gerçek public Site URL ve kontrollü gerçek Auth e-posta/callback kabulü olmadan bu alan üretime hazır sayılmaz. Ayar değiştirilmedi.
- SMTP yapılandırması var; bu koşuda gerçek e-posta gönderilmedi. Admin create + email_confirm gerçek e-posta doğrulaması/signup testi değildir.
- Play Auth/cloud gate'leri, worker/cron ve pending_legal_review açılmadı. Hukuki nihai metin onayı bulunmuyor.
- İki gerçek cihaz, Flutter release runtime, GPS fiziksel sürüşü, yeni imzalı AAB ve nihai R6 toplu kabul ayrı bekleyen işlerdir.

Araçlar: `run_hosted_acceptance.ps1` varsayılan dry-run; açık onay anahtarı ve sabit PROD önkoşulları gerekir. `ResumeCleanup` yeni hesap açmadan yalnız mevcut encrypted run receipt'lerini işler. `verify_hosted_cleanup.ps1` yalnız o journal'ın UUID'lerini readonly sayar. Çalıştırıcı kayıtlı test hesabı dışındaki hesaba işlem uygulamaz.
