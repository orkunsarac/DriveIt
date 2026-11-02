# R6-B — DEV hesap silme uygulanabilirlik değerlendirmesi

Tarih: 3 Kasım 2026
Kapsam: yalnız DEV `viqngnjfgknpxtoapzcg` şema/Function kataloğu ve git içindeki kabul edilmiş silme zinciri. Bu incelemede uzak migration, Function deploy veya Auth hesabı silme yapılmadı.

## Kesin DEV durumu

- Supabase CLI ile okunan uzak migration geçmişinde 22 uygulanmış sürüm var: 13 `supabase/migrations` taban dosyası ile `202610120001`–`202610170002` arasındaki dokuz Phase8 dosyası. `202610310001_phase8_m4_server_gate.sql` yerelde bulunuyor ancak DEV geçmişinde yok.
- Kabul edilmiş PROD tabanı 25 artifact olarak tanımlı: yukarıdaki 23 migration, ayrıca `supabase/prod/bootstrap/202609220001_canonical_planet_base.sql` ve `202609220002_canonical_function_acl.sql`. İki bootstrap dosyasının beklenen Planet tabloları (`world_publishes`, `profiles`, `world_validated_roads`, `world_validated_road_sections`), `attach_world_publish_source(...)` ve PostGIS DEV kataloğunda mevcut. Dolayısıyla eksiklik veri şeması değil; kabul edilen tabanla migration geçmişi/artefakt uyumu.
- Hesap silme tabloları (`account_deletion_%`) ve SQL RPC'leri DEV kataloğunda yok. `delete-account` Edge Function da dağıtılmış Function listesinde yok; R6-A isteği 404 dönmüştü.
- Phase8 kişisel bulut tabloları, Group Drive tabloları ve RPC'leri; Planet aktif generation/trace/state nesneleri ve Planet okuma fonksiyonları mevcut.
- Group Drive Realtime yetki fonksiyonu ve iki politika mevcut. Ancak `phase8_group_rollout` singleton tablosu DEV'de yok. Yerel `202610310001_phase8_m4_server_gate.sql` bu tabloyu `enabled=false` ile kuruyor; DEV'de henüz bu sunucu kapısının varlığı doğrulanamaz. Bu kapı kurulup `false` olduğu ayrıca teyit edilmeden silme zincirine geçilmemeli.

## Gereken değişiklikler

Önce DEV tabanı kabul edilen 25-artifact referansıyla salt okunur hash/katalog karşılaştırmasından geçirilmelidir. İki bootstrap SQL'i dolu DEV'e tekrar çalıştırılmamalı: ilgili şema zaten var ve `CREATE IF NOT EXISTS` tek başına hash/ACL parity kanıtı değildir. Bootstrap geçmişinin nasıl uzlaştırılacağı kontrollü migration ledger düzeltmesi olarak önceden gözden geçirilmelidir.

Group Drive kapısını kurup kapalı tutmak için `supabase/phase8-dev/supabase/migrations/202610310001_phase8_m4_server_gate.sql` gereken DEV önkoşuludur. Uygulama sonrasında singleton satırının `enabled=false` olduğu, signup'ın kapalı kaldığı ve grup publish/create isteğinin reddedildiği doğrulanmalıdır.

Sonra yalnız aşağıdaki **27 sıralı forward migration** gerekir:

- `supabase/account-deletion/migrations/202611010001`–`202611010025` (`account_deletion.sql`, audit, owner fencing, receipt recovery, Planet serialization/rebuild/checkpoints, Group üye iptali, worker queue, scope ve retention audit dosyaları).
- `supabase/account-deletion/migrations/202611020001_account_deletion_road_version.sql` ve `202611020002_account_deletion_generation_version.sql` — PROD'da kabul edilen iki düzeltme.

Ardından yalnız `supabase/functions/delete-account` Function'ı dağıtılmalıdır. Kaynak bundle `index.ts`, `planet_rebuild.ts` ve içe aktarılan mevcut `process-world-publish` modüllerini içerir. `verify_jwt=false` gateway ayarı kasıtlıdır; Function'ın kendisi request için JWT'yi, aynı UID'ye ait mevcut parola doğrulamasını, beklenen owner'ı ve açık silme onayını zorunlu kılar. `ACCOUNT_DELETION_WORKER_TOKEN` güvenli Function secret olarak sağlanmalıdır. Cron/scheduler, signup, Group Drive ve uygulama silme UI gate'i açılmaz.

## Account A için güvenli temizlik

DEV'deki R6-A Account A sentetik `example.invalid` hesabıdır; R6-A raporuna göre parola rastgele yenilenmiş ve saklanmamıştır, finalized sürüşler kalmıştır. `ON DELETE RESTRICT` beklenen korumadır. Admin `deleteUser`, doğrudan SQL silme, trigger/RLS/FK gevşetme veya finalized satırları elle silme kullanılmamalıdır.

Resmi akış hazır olduktan sonra:

1. Önce Auth Admin ile yalnız bilinen sentetik Account A'nın exact kimliğini ve R6 test rolünü doğrula; e-posta `.invalid` olduğundan e-posta reseti kullanılamaz. Geçici ve rastgele yeni bir parola yalnız bu sentetik UID'ye Auth Admin üzerinden atanır; parola loga/journala yazılmaz.
2. Ayrı/izole istemciyle bu parola kullanılarak giriş yapılır. Böylece resmi request endpoint'i güncel JWT ile aynı UID/parola yeniden doğrulamasını yapar; body'deki `expectedOwner` yalnız oturum değişimi precondition'ıdır.
3. İstemci yeni rastgele request ID ve 256-bit receipt üretip güvenli depoda tutar, `DELETE_MY_ACCOUNT` açık onayıyla resmi `request` çağrısını gönderir. Sonra yalnız aynı receipt ile `run`/resume akışı çalıştırılır. Receipt kaybolursa onaylı private worker recovery kullanılır; yeni hesap veya farklı owner seçilmez.
4. Storage nesneleri önce silinir. Planet katkısı ortak ve güvenle yeniden kurulabilir değilse iş `blocked_planet` durumunda kalır ve ilgili yayınlar fail-closed olur; operatör incelemesi/replay sonrası aynı iş resume edilir. Owner'a bağlı finalized Phase8 kayıtları resmi `account_deletion_purge` içinde transaction-scoped, job-owner-bound mekanizmayla kaldırılır. Auth hesabı ancak DB, Storage ve Planet adımları tamamlanınca en son silinir.
5. Test sonunda Auth/Profile, owner'a ait Phase8 tabloları, Storage prefix'i, source/Planet bağlantıları ve deletion owner bağlantısı yalnız bu UID için sıfır; diğer hesap sentinel verileri değişmeden kalmış olmalıdır. Receipt tamamlandıktan sonra istemcide temizlenir.

Bu görevde Account A'ya parola atanmadı, request/receipt üretilmedi ve sunucu hesabına işlem yapılmadı. Dağıtım onayı olmadan yukarıdaki akış başlatılamaz.

## Yerel doğrulama ve hata stratejisi

Pinlenmiş `pgr6a-749a37ae1b` local Supabase yığını, aynı PostgreSQL cluster kimliği/PGDATA korunarak yeniden başlatıldı. İlk tam suite başarısız oldu çünkü CLI, secret TOML `env(...)` değerini local Functions container'ına literal olarak aktarmıştı (`recovery_not_configured`). Yalnız git-dışı local test konfigürasyonu düzeltildikten sonra hedefli JWT/password/owner testi **1/1 PASS**, tam gerçek local Supabase Auth/Storage/Edge Function + Planet/receipt suite **27/27 PASS (8m53s)** oldu. Son fixture testi sentetik veri kümesinin temiz, feature gate'lerin kapalı kaldığını doğruladı. Bu yerel sonuç gerçek DEV deploy veya Account A silme kabulü değildir.

Migration'lar ileri yönlüdür; uygulanmış bir dosyayı geri SQL ile tersine çevirme planı yoktur. Onaylı uygulamada önce snapshot/backup ve exact preflight/hash kontrolü yapılmalı, her sürüm sırayla çalıştırılmalı; herhangi SQL hata/uyumsuzluğu olursa sırayı durdurmalı ve Function dağıtılmamalıdır. Migration'lar tamamlanıp katalog/RLS/grant/trigger kontrolü geçmeden Function deploy edilmez. Function deploy başarısızsa şema yerinde ama endpoint kapalı kalır; worker token, cron ve UI gate açılmaz. Her adımda DEV proje ref'i doğrulanır; PROD hedefi kabul edilmez.

Onay sonrası tek kapsamlı sıra: **DEV 25-artifact taban parity ve Group gate false doğrulaması → 27 deletion migration hash/sıra preflight ve uygulama → yalnız `delete-account` deploy → signup/gate/worker kapalı kontrolleri → iki geçici sentetik kullanıcıyla A silme/receipt resume ve B izolasyon testi → ilgili UID/veri temizliği doğrulaması.**

## Referanslar

- `docs/hosted_acceptance_result.md` — PROD'da 52 migration ve hosted silme/receipt kabul kaydı.
- `supabase/prod/upgrade_manifest.json` ve `supabase/prod/correction_manifest.json` — gerekli base/candidate artifact ve hash envanteri.
- `supabase/account-deletion/README.md` — request/receipt/worker güvenlik sözleşmesi.
- `docs/r6_supabase_a55_acceptance.md` — Account A'nın sentetik/temizlenmemiş olduğu ve `ON DELETE RESTRICT` engeli kaydı.

## R6-B2 önkoşul sonucu (3 Kasım 2026)

DEV `viqngnjfgknpxtoapzcg` için `supabase backups list` salt okunur sonucu `backups=[]`, `pitr_enabled=false` oldu. Geri yüklenebilir uzak backup/snapshot kanıtı olmadığından bu checkpoint'te dağıtım **BLOCKED**. Şema/migration/Function/secret/hesap üzerinde bu görev kapsamında hiçbir uzak yazma yapılmadı. Dağıtım değerlendirmesine dönmeden önce DEV için doğrulanabilir ve geri yükleme yolu kabul edilmiş backup/snapshot sağlanmalıdır.
