# R3 — onaylı PROD upgrade ve Function dağıtımı

Tarih: 2 Kasım 2026. Hedef yalnız `arwnbogcswisfesayosy`.

**Dar dağıtım ve veri değiştirmeyen güvenlik kabulü: PASS.** Bu, tam kapalı beta/gerçek kullanıcı kabulü değildir.

## Uygulanan onaylı işlemler

- PROD'a özel Mapbox tokenı maskeli yerel istemle alındı; repository dışında DPAPI kaydedildi. Önceki dosya varsa şifreli yedeklendi. Değer loglanmadı; DEV'den kopyalanmadı.
- Mevcut 25 migration sürümü ve kayıtlı SQL hash'leri kaynak manifestiyle doğrulandı. Ek hesap silme 25 migration'ı tek transaction içinde uygulandı. Mevcut temel kurulum tekrar çalıştırılmadı.
- Güncel hash kontrollü 10 Function dağıtıldı; her biri ACTIVE ve beklenen JWT ayarıyla yeniden okundu. Cleanup/delete-account gateway JWT=false; kalan sekizi true.
- Recovery worker tokenı üretildi, önce DPAPI saklandı ve yalnız PROD server secret'ı olarak tanımlandı. Worker çağrılmadı, cron kurulmadı. Supabase service role veya secret key istemciye eklenmedi.

## Son sunucu kanıtları

- ACTIVE_HEALTHY; migration **50/50**; tüm 50 kayıtlı SQL hash'i iki kaynak manifestiyle eşleşiyor.
- Auth kullanıcı **0**, disable_signup=true, anonymous signup=false, email confirmation required=true. SMTP yapılandırması mevcut; bu kontrol gerçek teslimat kanıtı değildir.
- Group Drive gate **FALSE**, aktif deletion schedule **0**.
- `phase8-drive-staging` ve `world-drive-sources` bucket'ları private.
- `audit_prod_upgrade.ps1`: izole 50-migration referansına karşı **22 tablo, 16 policy, 74 fonksiyon** birebir eşleşiyor. RLS, rol GRANT, policy roller/komut/USING/WITH CHECK, fonksiyon imzası/gövdesi/SECURITY DEFINER/search_path ve anon/authenticated/service_role/PUBLIC EXECUTE karşılaştırıldı. Ayrıntılı nesne listesi `r3_prod_catalog_acceptance.md` içindedir.
- `test_prod_unauthenticated.ps1`: **12/12 PASS**, exit 0. Dokuz mevcut Function credentialsız erişimi reddetti; delete-account request JWT'siz, worker_status worker token'sız ve run bozuk receipt ile reddedildi. Gerçek kullanıcı veya job oluşturulmadı.

## Yerel test kabulü

- Gerçek yerel Auth/DB/Storage/Edge hesap silme ve Planet worker paketi **27/27 PASS**, exit 0, 5m59s; sonunda sentetik temizlik ve gate kontrolleri PASS.
- Gerçek entrypoint/validation payload/deletion replay Deno kontrolleri **16/16 PASS**, exit 0. Önceki npm/DNS engeli bu çalıştırmada yoktu.
- Hazırlık **12/12**, temel/upgrade builder **4/4 PASS**. Temiz izole PostgreSQL upgrade rollback ve commit testleri PASS.
- Bu deployment sırasında Flutter/Android/signing, A55 verileri, hukuki onboarding ve istemci feature gate'leri değiştirilmedi. Önceki 33/33 SDK/lifecycle testleri bu dosyalar değişmediği için tekrarlanmadı.

## Ayrı kabul bekleyenler

- Gerçek hosted authenticated upload/download/delete/Planet/account-deletion ve iki cihaz kullanıcı testleri yapılmadı; PROD'da hesap oluşturulmadı.
- Mapbox tokenı tanımlandı; gerçek Mapbox rota eşleştirme/teslimat ve kota kabulü yapılmadı. SMTP gerçek teslimat/callback testi ayrıca kontrollü onay gerektirir.
- Worker schedule/operasyon aktivasyonu, signup açılması ve Play Auth/cloud gate'lerinin açılması ayrıca onay ve gerçek servis kabulü gerektirir.
- Hukuki onay henüz yoktur; pending_legal_review korunur. Yeni tam özellikli imzalı beta AAB ve gerçek cihaz kabulü henüz yapılmadı.
- Deployment PAT'i veya şifreli yedekleri iptal edilmedi/silinmedi. İhtiyaç bitince yetki daraltma/iptal ayrıca kullanıcıyla yürütülmelidir.

DEV projelerine yazılmadı, kullanıcı verisi taşınmadı/silinmedi, ücretli plan/hizmet satın alınmadı. Genel `deploymentReady=false` hazırlık kilidi korunur; onaylı uygulama araçları ayrı açık Apply anahtarı gerektirir.
