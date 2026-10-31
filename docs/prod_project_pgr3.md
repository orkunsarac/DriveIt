# P-GR3 — yeni Free PROD projesi

Kullanıcı onayından sonra Management API ile DriveIt-PROD oluşturuldu.
Ref: `arwnbogcswisfesayosy`; organizasyon: `kadjorpqgeccngwxxpwg` (DriveIt DEV);
bölge: Frankfurt `eu-central-1`; organizasyon planı oluşturma öncesi ve sonrası
`free`; proje durumu `ACTIVE_HEALTHY`. İsim/ref/bölge API'den yeniden doğrulandı.
Organizasyon ortak olsa da proje ref'i ve proje kaynakları bağımsızdır.

Planet DEV `viqngnjfgknpxtoapzcg` ACTIVE_HEALTHY; Phase 8 DEV
`jidyfemjzztlwjmijndx` INACTIVE kaldı. Son erişilebilir envanter iki aktif,
bir duraklatılmış proje gösteriyor. Görünen Free kontenjanı artık 2/2.
Bir sonraki aktif Free proje için yer varmış gibi davranılmamalı; ücretli
yükseltme, DEV silme veya DEV durumunu değiştirme onayı verilmedi.

Yeni proje için veri aktarımı yapılmadı. Auth kullanıcı/sürüş/rota/Storage
içeriği kopyalanmadı. Boş provision edilmiş proje oluşturuldu; kullanıcı tabloları
satır sayısı SQL ile ayrıca sorgulanmadı. Bir ref farkı veya ACTIVE_HEALTHY durumu
tek başına RLS/işlevsel izolasyon kabul testi değildir.

## Gizli bilgiler

Scoped PAT yalnız kullanıcının Windows DPAPI-şifreli dosyasından belleğe alındı.
Yeni veritabanı parolası kriptografik rastgele üretildi; Windows hesabına bağlı
şifreli credential olarak repository dışında saklandı. Token/parola kaynak
koduna, komut argümanına, log veya bu dosyaya yazılmadı. API/service-role
anahtarları bu aşamada okunmadı. CLI bağlantısı PROD'a link edilmedi; Flutter'ın
mevcut DEV yapılandırması değiştirilmedi.

## Deployment öncesi sonuç

25 migration sırası ve normalize kaynak hash'leri mevcut hazırlık aracıyla
doğrulandı; 8 hedef koruma ve 8 fiziksel izolasyon self-test'i geçti.
Yeni ref ile dry-run çalıştı: targetSyntaxVerified=true, deploymentReady=false.
Aracın remoteIdentityVerified=false değeri aracın kendisinin ağ doğrulaması
yapmadığını belirtir; bu oturumda ayrı Management API kimlik kontrolü yapıldı.
Normal dry-run'ın engelli çıkışı beklenendir, deployment başarısı değildir.

Hiçbir PROD migration veya Edge Function uygulanmadı. Dolayısıyla Group Drive
gate'i henüz kurulu değil; FALSE mevcut sunucu değeri olarak raporlanamaz.
Sonraki deployment için 25 migration, 9 Edge Function, private bucket'lar ve
sunucu gate FALSE doğrulaması ayrı açık kullanıcı onayı gerektirir.
Uygulama aktivasyonu, beta veya Play yayını onayı yoktur.

Auth site/redirect URL'leri, e-posta doğrulaması ve SMTP sağlayıcısı ayrıca
kararlaştırılmalı. Private world-drive-sources/phase8-drive-staging bucket'ları,
RLS/ACL, cleanup secret ve zamanlanmış bakım kurulup kabul edilmeli.
Gerçek PROD verisi oluşmadan DB ile Storage için ayrı yedek/geri yükleme
prosedürü ve operasyon sorumluluğu tamamlanmalı. Free proje inaktivitede
duraklatılabilir; otomatik günlük DB yedeği veya Storage dosyalarının DB
yedeğiyle korunması varsayılmaz. Plan yükseltme otomatik yapılmaz.

Resmî kaynaklar:
- https://supabase.com/docs/guides/platform/billing-on-supabase
- https://supabase.com/docs/guides/platform/regions
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/personal-access-tokens
