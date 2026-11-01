# P-GR6A hesap silme — yerel kabul PASS, PROD aktivasyonu kapalı

## Uygulanan kapsam

`supabase/account-deletion/migrations` ayrı ve ileri sürümlü aday zinciridir; standart 25 migration PROD manifestine eklenmedi. `delete-account` Edge adayı PROD/DEV'e dağıtılmadı. Flutter akışı `DRIVEIT_ACCOUNT_DELETION_ENABLED` varsayılan FALSE arkasındadır. Signup veya Group Drive açılmadı.

Kullanıcı JWT'si sunucuda doğrulanır, aynı UID için mevcut şifre yeniden doğrulanır ve açık DELETE_MY_ACCOUNT onayı gerekir. İstemcinin expectedOwner alanı doğrulanan JWT subject'iyle eşleşmelidir; bu eski hesap ekranından gelen isteği durduran önkoşuldur, silme hedefini seçen yetki kaynağı değildir. Yeni talepler güçlü private worker anahtarı olmadan kabul edilmez. Password hiçbir receipt'e yazılmaz. 256-bit receipt cihazda Flutter Secure Storage 11.2.0 ile şifreli tutulur; endpoint/owner ayrımı ve single-flight vardır. Yerel Hive/SQLite/History silme bağımlılığı yoktur. Aktif GPS işleminde mevcut owner guard talebi durdurur.

Kalıcı iş, lease, sınırlı Storage sayfası, Auth'u en son silme, doğrulanmış tamamlanma ACK'i, durum/failure audit'i ve private recovery worker vardır. Bir worker çağrısı bir işi ve en çok 100 nesnelik tek bucket grubunu işler. Ağ/backend çağrıları 15 saniyeyle sınırlıdır. Worker hatasında iki dakikalık backoff kaydedilir; yeni polling servisi veya PROD cron kurulmadı. Cihaz receipt'i kaybolduğunda yetkili sunucu worker'ı işi sürdürebilir. Gerçek PROD aktivasyonundan önce bu worker'ın güvenli çağrı/schedule/izleme kurulumu ayrıca onaylanmalıdır.

Tamamlanınca owner bağlantısı temizlenir; rastgele, kimliksiz receipt/state kayıtları 24 saat sonrası pruning'e uygundur. Bunlar yeni bir kişisel veri saklama istisnası olarak tanımlanmadı. Yeni talep/worker pruning'i ve hukuki/operasyonel izleme kabulü rollout önkoşuludur.

## Veri yaşam döngüsü

- Auth: kullanıcı ve session/refresh yetkisi kaldırılır. Eski access JWT'sinin imzası sürebildiğinden SQL ve Storage fence, Auth subject'inin hâlâ varlığını da kontrol eder.
- Profil: sunucu profili silinir; silme sırasında mevcut authenticated okuma/update yolları fence'lenir.
- Kişisel cloud: upload intents, immutable manifest/change kanıtları, snapshots, sequences, lease/tombstone/cancellation satırları yalnız hedef owner için kaldırılır.
- Storage: metadata owner veya owner namespace ile sahipliği kanıtlanan nesneler kaldırılır. Çelişkili sahiplikte başka kişinin nesnesi silinmez; iş tamamlanmaz.
- Planet: kendi raw source, publish, validated road/section ve trace verisi silme kapsamındadır. Kaynak kimliği/mesafe/tarih bağlantıları generation metadata'sından çıkarılır; diğer kayıtların ihtiyaç duyduğu nötr sıra bilgisi kalır. Silme generation değiştirerek eski mutation planlarını geçersizleştirir.
- Ortak Planet: diğer owner doğrulanmış yollarının varlığında bağımsızlık kanıtı yoksa konservatif blocked_planet kullanılır. Yayın okuma ve türev yazmalar fail-closed olur; başka kişilerin satırları silinmez. Bu durum genel Planet erişimini geçici olarak durdurabilir; çözülmeden PROD açılmamalıdır. Doğrulanmamış anonimleştirme uygulanmadı.
- Grup: silinen yöneticiye ait grup sonlandırılır ve grant'ler kapatılır; diğer üyelerin kişisel sürüşleri korunur. Kendi üyelikleri ve yönettiği grubun metadata'sı kaldırılır. Normal üye silinmesinde başka yöneticinin grubu korunur; generation/revision yenilenerek yeni konumlar eski topic'e gönderilmez. Eski socket'in anında kopması iddia edilmez.
- Cihaz: sürüşler/guest/arşiv/GPS recovery kayıtları korunur; logout sonrası eski owner alanı görünmez, başka hesaba otomatik taşınmaz. Şifreli receipt hariç yerel geçmişe silme/aktarma yapılmaz.
- Önceden alınmış ekran görüntüsü/cache veya dağıtılmış konum geri çağrılamaz. Önceden verilmiş signed URL nesne kaldırılana kadar yaşayabilir; Storage/Auth doğrulanmadan tamamlandı dönmez.

## Gerçek test kanıtları

| Kontrol | Gerçek sonuç |
|---|---|
| Flutter host paketi | 1176 PASS, 2 skip, process exit 0 |
| Yeni receipt/controller/widget alt kümesi | 9/9 PASS, exit 0; host sayısına dahildir |
| Statik analiz | 3 warning + 4 info eski baseline; yeni bulgu yok |
| Android debug Kotlin/resource | BUILD SUCCESSFUL, exit 0; cihaza yüklenmedi |
| Son izole P-GR6A servis koşusu | 14/14 PASS, process exit 0 |

Geçen servis senaryoları: dolu kişisel bulut + grup yöneticisi silme/B koruma; tek sahipli Planet erasure/generation; açık onay/password/A-B/expectedOwner yetki; 101 Storage nesnesinde bounded paging ve eski JWT; single-flight + Auth cevabı kaybı; gerçek Storage pause/unpause kesintisi ve retry; crash lease expiry; ortak Planet fail-closed; cihaz receipt'i olmadan private server recovery; çelişkili Storage sahipliği; Auth audit ayrıştırma ve bilinmeyen kimlik bağlantısında fail-closed; normal grup üyesi silinmesinde generation yenileme; final sentetik veri temizliği. Önceki stop/start kesinti denemesi servis yöneticisiyle yarışıp başarısız oldu; son geçen koşu aynı disposable Storage container'ında pause/unpause kullandı.

## Temiz kurulum ve ortam engelinin çözümü

Yeni `pgr6a-8e36def346` stack başlatması sonrası Docker API/WSL yanıtları takıldı; WSL `WSL/Service/WSAETIMEDOUT` verdi. İlk boş RAM ölçümü yaklaşık 527 MiB idi; kesin nedenin RAM olduğu kanıtlanmadı. 85 Docker istemcisinin çoğu normal log/wait akışlarıydı. Kendi bekleyen initializer ve salt-okunur komutları kontrollü iptal edildi; exit -1 test başarısı sayılmadı.

Kullanıcı Docker Desktop restart'ını açıkça onayladı. Normal restart timeout/exit 1 verdi; desteklenen stop --force denemesi Desktop'ın zaten kapandığını bildirdi, ardından start başarılı oldu. Engine 29.8.2 tekrar doğrulandı. Bu onaylı restart diğer yerel bağlantıları da kesti; volume silinmedi veya reset yapılmadı. Sonrasında yalnız P-GR6A açıldı. CLI partial lifecycle hatası kendi önerdiği veri koruyan stop/start ile giderildi; gerekli olmayan studio/analytics/mail servisleri açılmadı.

DB başlangıcında Auth ve public uygulama tabloları 0 doğrulandı. Hash/sırası doğrulanan 25 baseline migration kuruldu, ardından ayrı klasördeki 11 forward aday uygulandı. Adaylar standart PROD manifestine veya varsayılan migration zincirine eklenmedi. Son scriptte tüm 14 servis testi PASS. Temizlik testinde jobs/events/Storage/users/profiles/Planet/grup/private-drive kayıtları 0 ve Group gate FALSE; Auth ayarı disable_signup=true kaldı. Testte replication-role ile yapılan sentetik teardown'ın event FK cascade'ini atladığı saptandı: yalnız bu run'ın job UUID'leri için açık event cleanup eklendi ve final temizlik testi geçti.

Fiziksel kanıt: stack ID `b3436369414ea6f69a97f0ab0683ed6e47a8d313236adcc1d9ab43b1d8d3786c`; PostgreSQL system identifier `7702955514769424425`; PGDATA subpath `instance-b3436369414ea6f69a97f0ab0683ed6e47a8d313236adcc1d9ab43b1d8d3786c-ea506b67-df52-4d8f-bd89-21aaa514b87d/data`. Bu kimlikler descriptor'a pinlenir; değişirse runner durur. API/DB yalnız 127.0.0.1 hedefidir.

Auth schema metadata'sını alternatif salt okunur Management API'den alma denemesi mevcut PAT için Invalid access token döndürdü. Token yenilenmedi; PROD/DEV verisi değiştirilmedi. Yerel gerçek servis üzerinden devam etmek esas yoldur.

## Auth audit/provider sınırı

[Supabase Auth kaynak kodu](https://github.com/supabase/auth/blob/master/internal/api/admin.go) hard-delete sırasında ayrıca user_deleted audit olayı kaydeder. [Audit modeli](https://github.com/supabase/auth/blob/master/internal/models/audit_log_entry.go) payload içinde actor/traits ve ayrı IP alanını kullanır. Sadece Auth kullanıcı sayısının sıfırlanması kişisel audit kalıntısının yokluğunu kanıtlamaz.

009 adayı gerçek yerel PostgreSQL/Auth üzerinde geçti: subject metadata'sı private işte geçici tutulur, Auth kalıntıları/audit kimlik bağları completion transaction'ında temizlenir. Başka actor/target korunur; tanınmayan kimlik bağlantısı varsa tamamlandı dönülmez. Ayrı testte bu bağlantı yalnız kendi sentetik satırında açık incelemeyle kaldırıldıktan sonra aynı receipt ile başarıyla devam edildi. 010 adayı owner/world kilit sırasını ve trigger'da yeniden fence kontrolünü uygular. Hosted sağlayıcının proje dışı güvenlik logları/backup/cache saklama koşulları hukuki/operasyonel inceleme gerektirir; bunlar otomatik olarak izinli saklama istisnası ilan edilmedi. Bu yerel kabul, bütün sağlayıcı kopyalarının anında fiziksel silindiği iddiası değildir.

## Gerçek cihaz ve rollout

Android KeyStore receipt kalıcılığı, reboot/uygulama kapanması, yedekten dönüş, owner navigation/logout ve aktif fiziksel GPS recovery kabulü cihazda ayrıca yapılmalıdır. Backup XML yalnız secure storage ciphertext dosyalarını hariç tutar; sürüş geçmişi yedeklerini genel olarak kapatmaz. Hiçbir APK yüklenmedi. Yeni endpoint/migration/worker secret/scheduler ve UI flag için PROD aktivasyonu ayrı onay ve tüm kalan kabulleri gerektirir.
