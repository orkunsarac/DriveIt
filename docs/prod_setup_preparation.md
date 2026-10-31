# P-GR2B — kanonik şema ve boş PROD bootstrap

## Kapsam ve kaynak

DEV yalnız salt okunur şema metadata sorgularıyla incelendi. Kullanıcı, sürüş,
rota satırları veya Storage dosyaları okunmadı/taşınmadı. `data.sql` açılmadı.
Kanonik arşiv: `tmp/diagnostic_acceptance/planet-m2-fix-20261015/schema.sql`.
SHA-256: BDBDCAC292E9CE2116DB82E33325FDFD2E343BC158896FDE8C69C48E538AB687.
Kaynak DEV ref'i `viqngnjfgknpxtoapzcg`; process token yalnız bellekte kullanıldı.
`supabase/prod/schema_metadata.sql` sadece pg_catalog/pg_policies okur.
Bucket için yalnız id/public/limit/MIME konfigürasyonu ayrıca okundu.

Arşivden izin listeli DDL çıkaran `tool/extract_prod_bootstrap.ts`, arşiv hash'ini
sabitler, dört fonksiyon gövdesini canlı metadata ile karşılaştırır. Yeniden
çıkarma tarihsel arşivi gerektirir; normal kurulum arşive ihtiyaç duymaz, sürümlü
bootstrap SQL'i kullanır. Kanonik provenans ve dokuz metadata kategori hash'i
`supabase/prod/canonical_provenance.json` dosyasındadır.

## Kurtarılan nesneler

Dört tablo: profiles, world_publishes, world_validated_roads,
world_validated_road_sections. Fonksiyonlar: attach_world_publish_source,
is_username_available, handle_new_user, set_updated_at. Auth trigger'ı:
on_auth_user_created; üç updated_at trigger'ı. Tabloların CHECK/PK/UNIQUE/FK,
indeks, RLS ve tablo/kolon grant'leri kaynakla doğrulandı. world-drive-sources
private bucket metadata'sı ve owner-path INSERT politikası kurtarıldı.
PostGIS extensions şemasında; tip şeması karşılaştırması geometry metnindeki
search_path kaynaklı önek farkını ayrı type_schema alanıyla doğrular.

Supabase varsayılan fonksiyon yetkileri arşiv GRANT'lerinden fazla EXECUTE
verebiliyor. Bu gerçek fark için uygulanmış dosyayı değiştirmeden ikinci
bootstrap migration'ı eklendi; canonical EXECUTE ACL'lerini yeniden kurar.
Dokuz kategori (kolon, constraint, indeks, tablo/kolon ACL, trigger, policy,
fonksiyon gövdesi/SECURITY DEFINER/search_path ve fonksiyon ACL) canlı kaynakla
birebir eşleşti. Canlı DEV'e DDL uygulanmadı.

## Uygulama sırası

1. Yeni Supabase'in yönetilen Auth/Storage/Realtime şemaları ve rolleri hazır olmalı.
2. `supabase/prod/bootstrap/202609220001_canonical_planet_base.sql`.
3. `supabase/prod/bootstrap/202609220002_canonical_function_acl.sql`.
4. Root `supabase/migrations` içindeki 13 dosya tarih sırasıyla.
5. `supabase/phase8-dev/supabase/migrations` içindeki 10 dosya tarih sırasıyla;
   en son P-GR1 gate migration'ı. Hiçbir eski dosya değiştirilmedi.
6. Storage API ile boş private bucket'lar: world-drive-sources (kanonik metadata)
   ve phase8-drive-staging (M1 10 MiB sözleşmesi). Dosya taşınmaz.

Toplam 25 benzersiz migration sürümü; Phase 8 geçmişiyle çakışmaz. Test
veritabanına başarıyla uygulanan dosyalar resmi CLI migration repair --status
applied ile yalnız açık localhost DB_URL üzerinde geçmişe kaydedilir. Bu komut
PROD hazırlık aracında otomatik çalıştırılmaz. Yerel proxy TLS sunmadığı için
sslmode=disable yalnız doğrulanmış 127.0.0.1 bağlantısında kullanılabilir;
PROD bağlantısına kopyalanamaz.

## İzolasyon ve test yöntemi

Önceki ortak-volume teşhisi yanlıştı: HostConfig.Mounts.VolumeOptions.Subpath
farklı fiziksel dizinleri gösteriyor. P-GR1 sistem kimliği 7702818118349594665,
P-GR2 7702830126571995177. Salt-okunur kontrol kanıtları: ayrı gerçek dizinler,
inode'lar ve pg_control kimlikleri. Eski stack'ler korunuyor.

Bu aşama için yeni workdir: tmp/pgr2b-canonical; project_id:
driveit-prod-bootstrap-pgr2b; stack: pgr2b-canonical-20261031. Otomatik migration
başlangıçta kapatıldı. Migration öncesi Auth kullanıcı ve public tablo sayıları
0/0; system identifier 7702837359395967017; ayrı fiziksel subpath:
instance-6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe-f4223b3e-8b1a-4c2a-bc16-707753a33aca/data.
API yalnız http://127.0.0.1:27773; DB endpoint'i loopback. Eski iki sistem
kimliğinden farklılık migration öncesi doğrulandı. Yeni ortam eager çalıştırıldı.

`tool/test_prod_bootstrap.ps1` yalnız bu stack, API, subpath ve sistem kimliğini
kabul eder. -ApplyBootstrap ayrıca gerçekten boş public/Auth durumu ister.
Varsayılanı mevcut test şemasında rollback'li SQL ve sentetik entegrasyon testidir.
Testin temizliği yalnız oluşturduğu grup/publish/Storage objesi ve hesaplarla
sınırlıdır; sonunda gate FALSE bırakır. `tool/test_postgres_isolation.ps1`
-SelfTest ile 8 mount kararı sınar; iki açık container adıyla canlı modda yalnız
mount metadata ve pg_control_system okur. Aynı volume/farklı subpath geçerlidir.

## PROD hazırlık aracı ve gerçek kullanıcı işlemleri

`tool/prepare_prod.ps1` varsayılan dry-run'dır; deployment/write modu yoktur.
ProjectRef ve ExpectedProjectRef eşleşmeli; tam HTTPS URL ref ile eşleşmelidir.
Bilinen Planet/Phase8 DEV ref'leri, belirsiz hedef, yanlış URL ve kaynak hash
farkı reddedilir. Sentetik hedef testleri 8/8. Bilinmeyen bir ref'in doğru biçimi
uzak projenin PROD olduğunu kanıtlamaz: remoteIdentityVerified=false kalır.
`preparation_manifest.json` hash'leri ve migration sırasını içerir.

Gerçek yeni Free projenin oluşturulması ve herhangi bir deployment ayrıca
kullanıcı onayı gerektirir. Organizasyon/bölge, Free proje kontenjanı, boş proje
kimliği ve Auth/SMTP/redirect ayarları doğrulanmalı. DEV kimlikleri/verileri
aktarılmaz. Admin/service-role/cleanup secret yalnız sunucu secret yönetiminde;
Flutter'a veya Git'e yazılmaz. PHASE8_CLEANUP_TOKEN ayrı zorunlu bakım secret'ıdır.

Functions: process-world-publish, planet-trace-detail, phase8-drive-begin,
phase8-drive-finalize, phase8-drive-download, phase8-drive-delete,
phase8-drive-lease, phase8-drive-cleanup, phase8-group-publish. Cleanup dışındaki
istemci uçları JWT doğrular; cleanup kendi token kontrolünü zorunlu tutar.
Mevcut DEV config/.temp linkleri PROD'a retarget edilmez. Group gate FALSE ve
özel Realtime SELECT/doğrudan INSERT engeli sunucuda doğrulanmadan aktivasyon yok.

R1/R1.1 Play release değişiklikleri korunur; otomatik sync/delete/group
bayrakları değiştirilmedi. Yerel bootstrap PASS beta/PROD kabulü değildir:
hesap silme orkestrasyonu, Planet saklama politikası ve iki cihazlı bütün ürün
kabulü tamamlanmadan beta açılmaz. Planet retention hukuki inceleme olmadan
kesinleştirilmez. Açık kanalı anında koparma veya yoldaki mesajı geri alma
kanıtlanmış değildir; gate kapatma sonrası yeni publish'i engeller.

## P-GR2B son kabul kanıtı

- Boş Auth/public başlangıcı ve yeni fiziksel cluster kimliği migration öncesi doğrulandı.
- 25 benzersiz migration uygulandı ve yalnız yeni test DB'sinin geçmişine kaydedildi.
- Canlı DEV ile 9 metadata kategorisi eşleşti (salt okunur).
- SQL: 185 geçti, 0 başarısız. Hazırlık/yanlış hedef: 8 geçti; mount izolasyonu: 8 geçti.
- Auth/Storage/RPC/Edge/Realtime: 1 entegrasyon geçti. Teste eklenen attach
  doğrulamasında ilk TypeScript daraltma hataları düzeltildi; tip kontrolü ve son
  tam koşu başarılı. Profil Auth trigger'ı, owner UPDATE izolasyonu, private kaynak
  upload, hesaplar arası upload/read/attach reddi, geçerli attach ve M4 akışları sınandı.
- Son durumda Auth/profiles/world_publishes/groups/storage.objects sayıları 0/0/0/0/0;
  iki bucket private; gate FALSE. P-GR1 salt-okunur kontrolde 10 migration/FALSE.
- Deno check ve git diff --check başarılı. Eski migration dosyaları değiştirilmedi.
- Gerçek PROD projesi/deployment oluşturulmadı; yerel bootstrap PASS, ürün betası
  veya PROD işletim kabulü olarak sunulmaz.
