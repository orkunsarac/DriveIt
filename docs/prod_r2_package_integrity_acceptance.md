# P-GR7I R2 — PROD paket bütünlüğü ve hesap silme sözleşmesi

Başlangıç checkpoint'i: `1cc0bcd014ff415754d842482c36c20027b5fade`

Sonuç: **Yerel hazırlık paketi PASS; canlı deployment yapılmadı.**

## Planet bundle ve kaynak hash incelemesi

Eski hazırlık manifestindeki 11 hash farkı, bu checkpoint'te zaten bulunan Planet/schema-2 kaynak güncellemeleriyle eşleşti:

- `planet-trace-detail/detail.ts`: reliable schema-2 kaynak ölçümü ve yanıt sözleşmesi güncellemesi.
- `planet-trace-detail/score.generated.js` ve `score.manifest.json`: `tool/build_planet_detail_score.ps1` üretimi. Generator Dart transitive dependency hash'lerini ve JS artifact hash'ini yeniden oluşturdu.
- `process-world-publish/active_world_empty_planner.ts`, `index.ts`, `source_contract.ts`, `world_scoring_stage.ts`, `world_scoring.ts`, `world_validation.ts`: Planet reliable source/schema-2 processing ve publication kabul zincirindeki mevcut kaynak revizyonları.
- `process-world-publish/world_scoring.generated.js` ve `world_scoring.manifest.json`: `tool/build_world_scoring.ps1` üretimi. Dart kaynak hash'leri, generated scoring artifact ve boundary artifact üretici manifestiyle eşleşti.

Her iki bundle da mevcut Dart 3.12.2 üreticisiyle derlendi. Kaynak ve bundle tutarlılığı Deno testleriyle doğrulandı; skor algoritması veya migration değiştirilmedi. Eski manifest hash'leri körlemesine geçirilmedi: yalnız yukarıdaki tam 11 dosya drift'i ve yeni Function yapılandırmasının hash'i yenilendi. Manifestin `hashMode=utf8-lf`, 25 migration listesi, migration sırası ve son gate migration'ı korundu.

## Hesap silme Function sözleşmesi

`delete-account` hazırlık Function listesine eklendi. `index.ts`, `planet_rebuild.ts` ve replay'in kullandığı process-world-publish kaynaklarının tamamı offline release envanterinde bulunuyor. `prepare_prod.ps1` bu gerekli dosyaları, Function entrypoint'lerini ve beklenen on Function/JWT politikasını kontrol eder.

`supabase/prod/config.toml` içindeki `delete-account.verify_jwt=false`, yalnız Supabase Edge Gateway'in JWT ön kontrolünü kapatır. Function'ın `request` yolu ayrıca Bearer JWT'yi `auth.getUser` ile doğrular, beklenen UID'yi karşılaştırır ve aynı UID için `signInWithPassword` ile mevcut parola doğrulaması ister. `run` yolu sunucudaki receipt hash/claim/lease kontrollerini kullanır. Worker eylemleri `ACCOUNT_DELETION_WORKER_TOKEN` denetimini korur. Bu ayar, istemciye silme yetkisi vermez ve receipt/worker denetimini kaldırmaz.

`prepare_prod_release.ps1`, hem cleanup hem receipt-resume kullanan delete Function'ı için `verify_jwt=false` sözleşmesini denetler; release hazırlığı offline kopya üretir. Paket üreticisi deployment komutu çalıştırmaz.

## Gerçekleştirilen doğrulama

- `tool/prepare_prod.ps1 -SelfTest`: **12/12 PASS**; yalnız sentetik hedefler, ağ erişimi yok.
- `tool/build_prod_transaction_test.ts`: **3/3 PASS**.
- `tool/prepare_prod_release.ps1` yeni `tmp/` hedefiyle: PASS; offline paket üretildi. İçinde **25** migration, bir dış `BEGIN` ve `COMMIT`, final Group Drive `FALSE` assertion'ı, `delete-account` entrypoint/replay kaynakları ve `verify_jwt=false` tanımı doğrulandı. `deploymentReady=false` kaldı.
- Planet, World processing, score parity, schema-2 ve deletion replay Deno testleri: **165 PASS / 0 FAIL** (Deno `--no-check`; kaynak test seti).
- Üç Deno test dosyasındaki gerçek Edge entrypoint alt testleri npm registry DNS nedeniyle çalışmadı: `planet-trace-detail/auth.test.ts`, `process-world-publish/edge_boot.test.ts` ve `validation_payload.test.ts` içindeki gerçek entrypoint testi. Bunlar **NOT TESTED**; geçilmiş sayılmadı. Yerel Supabase Edge servis entegrasyonu ve hosted kabul de **NOT TESTED**.
- Hesap silme, Planet yayın/okuma, owner lifecycle ve gateway Flutter regresyonları: **103/103 PASS**.
- `flutter analyze --no-pub`: önceki baseline ile aynı **3 warning + 4 info**, yeni bulgu yok. Analyzer bu baseline nedeniyle exit code 1 verdi.
- Secret taraması: değişen kaynak/manifest/config dosyalarında secret eklenmedi; `git diff --check` PASS.

## Güvenlik ve yayın durumu

- `deploymentReady=false`, `groupDriveDefault=FALSE` ve mevcut blocker listesi korunuyor.
- `prepare_prod.ps1` normal çalışma yolu dry-run olarak kalır; bu R2 sırasında PROD veya DEV bağlantısı, migration, Function deployment, Auth ayarı ya da kullanıcı verisi işlemi yapılmadı.
- SMTP, Auth signup, deletion worker, cron ve feature gate'ler etkinleştirilmedi.
- Tam hosted hesap silme kabulü, yerel Supabase Edge runtime doğrulaması ve gerçek PROD deployment ayrı onay/test aşamalarıdır.
