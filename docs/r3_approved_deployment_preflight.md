# R3 — onaylı dağıtım önkontrolü

Tarihsel önkontrol kaydıdır. Mapbox tokenı daha sonra kullanıcıdan güvenli alınarak dağıtım tamamlandı; güncel sonuç `r3_deployment_acceptance.md` içindedir.

Kullanıcı ek 25 migration ve güncel 10 Function dağıtımını açıkça onayladı. Signup, Group Drive ve worker/cron aktivasyonu kapsam dışındadır. Hukuki onboarding kapısı korunur.

## Yerel kabul

- İzole P-GR6A gerçek Auth/Database/Storage/Edge hesap silme/Planet worker paketi: **27/27 PASS**, exit 0, 5m59s. Son test sentetik veri temizliğini ve kapalı gate'leri doğruladı.
- Daha önce npm/DNS nedeniyle çalışmayan gerçek Planet entrypoint testleri, validation payload ve deletion replay Deno kontrolleri: **16/16 PASS**, exit 0. Bunlar hosted kullanıcı testi değildir.
- Hazırlık self-test **12/12**, transaction builder **4/4 PASS**. Onaylı package kaynakları ve config hash'leri dry-run araçlarında doğrulandı.
- Temiz yerel PostgreSQL temel+upgrade ve rollback kabulü önceki checkpoint'te PASS (toplam 50 migration).

## PROD önkoşulları

Salt okunur PROD kabulünde proje ACTIVE_HEALTHY, signup kapalı, auth.users=0, migration=25, Group Drive FALSE ve mevcut dokuz Function ACTIVE bulundu. DPAPI PAT ile desteklenen Database Query API'ye yalnız `current_setting('transaction_read_only')` sorgusu `read_only=false` bağlamında gönderildi: HTTP 201, transaction_read_only=off. Bu probe şema/veri değiştirmez; diğer API yazma yetkilerini kanıtlamaz.

Secret varlık metadata'sı: cleanup secret mevcut, `MAPBOX_ACCESS_TOKEN` ve deletion worker token henüz yok. Kullanıcı PROD için Mapbox tokenı hazırlayacağını bildirdi. Token sohbette istenmedi; değerler loglanmadı. DEV'den secret kopyalanmadı.

**Dağıtım henüz uygulanmadı.** Eksik Mapbox yapılandırması nedeniyle hiçbir PROD migration, Function veya secret yazımı yapılmadı. Kullanıcı onayı geçerlidir; eksik PROD tokenının güvenli alınması bekleniyor.

## Uygulama araçları

- `apply_prod_upgrade.ps1`: varsayılan dry-run. Açık `-ApplyApprovedUpgrade` ile yalnız sabit PROD hedefi; mevcut 25 migration'ın tam history SQL hash'leri, kapalı signup/group, sıfır kullanıcı ve gerekli mevcut secret metadata'sı doğrulanır. Yalnız yeniden üretilmiş artifact ile byte olarak eşleşen upgrade tek API işleminde uygulanır. Hata/belirsizlikte otomatik tekrar yoktur; önce history okunur.
- `deploy_prod_functions.ps1`: varsayılan dry-run. Açık `-ApplyApprovedFunctions` ile yalnız doğrulanmış 50-migration PROD ve onaylı Function envanteri; paket hash/config kontrolü. Yeni recovery secret önce repository dışında DPAPI saklanır. Worker invoke/cron kurulmaz. Her Function sonrası ACTIVE/JWT read-back zorunludur. Yetki/hata durumunda sonraki yazımlar durur. Prune/force veya DEV hedefi yoktur.

Bu checkpoint bir PROD dağıtım PASS raporu veya tam kapalı beta kabulü değildir. Mapbox tokenı sonrasında önkontrol tekrarlanacak, onaylı dağıtım yürütülecek ve canlı veri değiştirmeyen kabul sonuçları ayrı kaydedilecektir.
