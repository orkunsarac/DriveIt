# P-GR4A — gerçek deployment önkontrolü

## Gerçek PROD: sadece okuma sonuçları

Hedef `arwnbogcswisfesayosy`, DriveIt-PROD, Frankfurt eu-central-1,
organizasyon planı Free, ACTIVE_HEALTHY: PASS. Ref iki DEV ref'inden farklı.
Auth kullanıcı/public tablo/Storage obje/bucket sayıları 0/0/0/0; migration history
tablosu yok. Beklenmedik uygulama verisi veya kurulum çakışması gözlenmedi.
Yalnız sayaç ve metadata sorgulandı; kullanıcı satırları/anahtarlar loglanmadı.
Auth, storage.objects, realtime.messages, digest, UUID, üç API rolü mevcut;
PostGIS sunucuda kullanılabilir. Yönetilen extension version'ları körlemesine
yerel sürüme zorlanmayacak. PROD'a hiçbir SQL/Edge/config yazma yapılmadı.

Auth: disable_signup=false (henüz kapalı kayıt politikası sağlanmıyor), email
confirmation zorunlu, email provider açık, custom SMTP yok, site_url
http://localhost:3000. Kayıtları kapatmak bu görevin salt-okunur sınırını aşar;
ayrı onaylı config adımı gerekir. SMTP ve gerçek redirect/site URL'leri beta
öncesi zorunlu; kayıtlar kapalı tutulursa boş altyapı hazırlığına engel değildir.
Hesap silme için Auth/profil/Storage/kişisel sürüş/grup/Planet kapsamının birlikte
kabulü gerekir. Mevcut drive-delete tek başına hesap silme kabulü değildir.
Planet retention hukuki karar bekler. Kullanıcıya açık beta onayı yoktur.

## Bulunan dağıtım penceresi ve yerel düzeltme

25 dosya ayrı transaction'larda uygulanırsa 202610160004 M4 RPC/Realtime izinleri
son 202610310001 gate dosyasına kadar erişilebilir olur. Mevcut dosyalar
değiştirilmedi. Yeni offline `tool/build_prod_transaction.ts`, normalize SHA-256
hash'leri ve tam 25 sürüm listesini doğrular; yalnız üst seviyedeki BEGIN/COMMIT
ifadelerini kaldırarak tek BEGIN/COMMIT oluşturur. Fonksiyon/DO dollar-quote
gövdelerini korur. Beklenmedik transaction komutları veya desteklenmeyen SQL
yapıları fail-closed durur. Kaynak değişince yeniden inceleme zorunludur.

Boş Auth/Storage/public/history önkoşulu, 25 migration history kaydı ve final
gate satırı FALSE/tek satır, helper FALSE ve rollout ACL doğrulaması aynı
transaction'dadır. Hata olursa commit yoktur; PostgreSQL bağlantısı koparsa
uncommitted DDL geri alınır. Bu artifact hedefe bağlanmayı/yetkilendirmeyi
yapmaz; uygulayıcı ayrıca gerçek PROD kimliği ve TLS bağlantısını doğrulamalı.
Bu SQL hiçbir PROD bağlantısında bu aşamada çalıştırılmadı.

## Edge/Storage paketi

`supabase/prod/config.toml` dokuz function için JWT politikasını tanımlar.
process-world-publish, planet-trace-detail, phase8-drive-begin/finalize/download/
delete/lease ve phase8-group-publish JWT=true. phase8-drive-cleanup JWT=false
olabilir; kodundaki PHASE8_CLEANUP_TOKEN eşleşmesi zorunludur, token eksikse
çalışmamalı. Bu token tanımlanıp kontrol edilmeden cron açılmayacak.

`tool/prepare_prod_release.ps1` yalnız yeni tmp workdir'ine gözden geçirilmiş
config, manifestte hash'li test dışı function kaynakları ve atomic.sql koyar.
DEV config/.temp linkleri, test dosyaları ve secret'lar kopyalanmaz. Araçta
link/deploy/apply modu yoktur. `tool/prepare_prod.ps1` artık yalnız kayıtlı
gerçek PROD ref'ini kabul eder; 25 benzersiz sıralı sürümü ve son gate'i denetler.
Hedef/manifest/config kaynak kontrolleri dağıtım izni yerine geçmez.

Bucket'lar Storage API üzerinden private world-drive-sources ve
phase8-drive-staging olarak kurulmalı. Canonical owner-path INSERT politikaları
ve M1 staging RLS migration'larda bulunur. Public/list/final obje erişimi
genişletilmeyecek. DEV objesi veya hesabı taşınmayacak.

## Yerel test kanıtı

Yeni tmp/pgr4a-atomic workdir'inde otomatik migration kapalı disposable stack
kuruldu. Fiziksel subpath:
instance-0527455996a5a2c0295e371a39519b3e5e54b6d2e65ce98628e97e84db16793f-83de82a7-3c4a-4cda-8bac-c80ba124bbc0/data.
Sistem kimliği 7702852553093967913; önceki üç test cluster'ından farklı.
Auth/public başlangıç sayıları 0/0. Eski test/DEV veri dizinleri kullanılmadı.

Parser/manifest/tek transaction unit testleri: 3 geçti. Gerçek PostgreSQL testi:
1 geçti. Test transaction'ı M4 kurulduktan sonra ve gate eklenmeden önce
duraklatıldı; ikinci bağlantı M4 RPC'sini göremedi. Son gate/history/ACL
assert'leri geçti. Test yalnız yerel ortamda ROLLBACK ile bitti; public/history
tabloları kalmadı. Hedef korumaları 10, fiziksel izolasyon self-test'leri 8 geçti.
Offline release paketi oluşturuldu; SQL/Edge PROD deployment yapılmadı.

## Onaydan sonra uygulanacak kesin sıra

1. Yeni HEAD/manifest/hash/25 sürüm ve gerçek PROD ref/Free/region/empty durumunu
   yeniden doğrula. Uzak state değişmişse dur. Eski DEV linkleri kullanılmaz.
2. Ayrı açık config onayıyla signup'ı kapat; tekrar oku ve doğrula. Yeni kullanıcı
   veya veri varsa otomatik deployment yerine çakışmayı değerlendir.
3. Kullanıcıdan 25 migration + dokuz Edge + iki private bucket + gerekli server
   secret kurulumu kapsamını açıkça onaylat. SQL write/Edge/Storage yetkileri
   yalnız PROD kapsamında olmalı. Mevcut read-only kontroller bunları kanıtlamaz.
4. Doğrulanan TLS bağlantısında atomic.sql'i tek bağlantı/tek transaction olarak
   uygula. Ayrı ayrı db push dosya commit'leriyle M4 penceresi açma. History de
   aynı transaction'da kayıtlıdır; sonradan körlemesine repair yapma.
5. Commit sonrası salt-okunur olarak 25 version, gate satırı FALSE, API rol
   yetkileri ve Realtime politikalarını doğrula. Sonuç belirsizse tekrar apply
   yapma; önce history/şema karşılaştır. Gate açma adımı yoktur.
6. Yeni PROD sunucu secret'larını güvenli tanımla; private bucket'ları Storage
   API ile oluştur ve doğrula. Üretim anahtarları testlere veya Git'e verilmez.
7. Yeni offline workdir ve açık --project-ref ile yalnız dokuz function'ı deploy
   et. Group publish ancak kurulu ve doğrulanmış kapalı gate sonrasında deploy
   edilir. Cleanup token/cron doğrulanmadan bakım tetiklenmez.
8. Auth/Storage/RLS/Edge/Realtime kabulünü onaylı sentetik QA senaryolarıyla
   gerçekleştir; temizliği yalnız o QA kayıtlarıyla sınırla. Mevcut kullanıcı
   veya veriyi temizleme, reset/prune/destroy kullanma.
9. Flutter/Android, Group Drive aktivasyonu ve Play/beta yayını ayrı kalır.

## Genel karar

Yerel dağıtım koruması PASS; gerçek PROD'a deployment için onay verilmedi.
Signup kapatma config onayı/uygulaması bekleniyor. SMTP/site/redirect,
hesap silme/retention ve iki cihazlı ürün kabulü tamamlanmadan beta açılmaz.
Gate henüz PROD'da kurulu değildir; FALSE bir mevcut PROD değeri olarak
sunulamaz. Aktif WebSocket'i anında koparma/yoldaki mesajı geri alma sınırı sürer.
