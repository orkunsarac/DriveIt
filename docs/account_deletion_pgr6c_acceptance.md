# P-GR6C — kalıcı worker ve kontrollü Planet replay: yerel kabul PASS

1 Kasım 2026. Yalnız yerel aday geliştirmesidir. PROD/DEV, gerçek kullanıcılar, signup, Group Drive ve PROD cron/worker ayarları değiştirilmedi. Başlangıç HEAD `8e4105c949df852527039ded96993d4fdb9c0f99`, branch `feature/gps-refactor`.

## Mevcut yapıdan devam

P-GR6A/B'nin job, receipt, owner fence, Auth-last purge, lease ve idempotent ACK altyapısı korunur. Yeni bağımsız bir silme veya sync sistemi kurulmaz. `supabase/account-deletion/migrations/202611010018`–`024` ileri adaylardır; önceki uygulanmış dosyalar değiştirilmez. Adaylar varsayılan 25 migration/9 function PROD paketine eklenmez. Flutter/Android ve yerel sürüş depoları bu aşamada değişmez.

## Worker ve durumlar

- `018_account_deletion_worker_queue.sql`: otomatik seçim ile sahiplenme aynı transaction'da `FOR UPDATE SKIP LOCKED` kullanır. Seçilen iş 120 saniyelik benzersiz lease alır; başka çağrı aynı işi eşzamanlı yürütemez. İşi henüz sahiplenmeden receipt hash listesinden seçme akışı otomatik worker'da kullanılmaz.
- Job sonuçları `pending / blocked_planet / purged / completed`; işletim fazları `queued / storage / planet / auth / review / completed` olarak ayrı tutulur. Faz ilerlemesi tamamlanma kanıtı değildir. Auth/Storage/DB doğrulaması ve mevcut completion transaction'ı olmadan `completed` dönmez.
- Her çağrı en çok bir iş ve 100 nesnelik tek Storage bucket sayfası işler. Dosya kaldıysa Planet hesaplaması başlamaz. Yerel sürüş kaydı veya GPS hiçbir ağ cevabını beklemez.
- Ağ/sunucu hatası mevcut işi korur. Otomatik backoff 120 saniyeden üstel olarak en çok 3600 saniyeye çıkar; sekiz başarısızlıkta operatör incelemesi gerekir. HTTP 5xx/429, fetch ve stream timeout'ları retry yoluna gider; eksik/uyumsuz kaynak ve hesaplama sınırları `blocked_planet` olarak korunur.
- `022_account_deletion_crash_budget.sql`: finally çalışmadan kaybolan lease'lerin sekizinci tekrarı da `review` durumuna alınır. Normal lease bırakma veya açık operatör yeniden kuyruğa alma, crash sayacını temizler. Yalnız timeout olmuş olması başarı sayılmaz.
- Özel worker anahtarıyla `worker_status` ve `worker_retry` işlemleri vardır. JWT/client RPC yetkisi bunlara yetmez. Retry yalnız var olan, önceden onaylanmış ve lease'i aktif olmayan işi kuyruğa alır; yeni hedef hesap oluşturmaz, kaynak kontrolünü veya tamamlanmayı atlamaz.
- Status en çok 20 rastgele job kimliği, faz, sayaç, retry zamanı ve lease/review durumunu döndürür. Owner UID, e-posta, source yolu, koordinat, parola, receipt veya receipt hash'i dönmez. Audit olayları `replay_checkpoint`, `replay_invalidated`, `retry_required`, `worker_stalled`, `review_requeued` gibi sabit etiketlerdir; ham exception/GPS loglanmaz.

## Checkpoint matematiği ve ölçek

`019_account_deletion_replay_checkpoints.sql` ve `planet_rebuild.ts` aynı kronolojik planner'ı **iki challenger kaynaklık** adımlara böler. Her adım mevcut aktif trace kümesini, özgün source sırasını ve source generation zamanını kullanır. Önceki pasif kaynakların road/telemetry'si sonraki ownership kararının girdisi değildir; ihtiyaç duyulanlar yalnız o adımdaki aktif source'lar ve challenger'dır. Kullanılan overlap, score ve Dart bridge değişmez.

Ara trace'ler canonical section anahtarları ve float8 round-trip string'leriyle özel job checkpoint'inde kalır. Yeniden açılırken `(roadId,sectionKey)` namespace'i tekrar kurulur. Private prefix generation, herkese açık generation değildir. Bu dönüşümün kesintisiz sonuçla tam eşliği JSON kaydet/yükle testinde doğrulandı.

Her checkpoint lease, önceki checkpoint version, kaynak prefix sırası ve canonical provenance ile doğrulanır. En çok iki sıra ilerleyebilir. Aynı ACK kaybolursa aynı içerik ikinci kez uygulanmaz. Kaynak/Storage sürümü veya global generation değişirse eski snapshot/trace prefix temizlenir ve baştan güvenli snapshot alınır; olay kaydı oluşur. Bütün kaynaklar işlenmeden final RPC reddedilir.

Kısmi index hiçbir kullanıcıya sunulmaz. Finalde mevcut atomik commit, snapshot/CAS kontrolüyle bütün türev index'i değiştirir; eski hesap etkili tarihsel trace sınırları da kaldırılır. Kalan kullanıcıların canonical road/section/source ve özel sürüş kayıtları silinmez. Auth tamamlanmasıyla özel replay snapshot ve staged geometry aynı completion transaction'ında temizlenir; job pruning'in FK temizliği de vardır. Review işinin tamamlanmış gibi gösterilip verisinin sessizce atılması söz konusu değildir.

**Sınır yükseltmek tek çözüm olarak kullanılmadı:** 32 road, 500 km, 512 section, 50.000 nokta çalışma seti sınırları her hesaplama adımında korunur; yol başına 100 km, 256 staged trace, 1 MiB staged plan, dosya başına 4 MiB ve çağrı başına 16 MiB stream bütçesi geçerlidir. Böylece pasifleşmiş kaynakları çok olan 33 road / 570 km gerçek servis işi küçük turlarla tamamlanabilir; saf 33 road / 594 km testi de geçer. Kaynaklar farklı turlarda yeniden indirilebildiğinden bandwidth maliyeti ayrıca izlenmelidir.

Metadata snapshot bütçesi ayrı olarak en çok 128 kalan road, 512 section ve yaklaşık 2 MiB'dir. Çok sayıda **aynı anda aktif** kaynak çalışma setini aşarsa veya metadata bütçesi yetmezse iş yine `blocked_planet` olur. Sonsuz büyüklükte dünya, keyfi büyüklükte geometri veya sınırsız streaming replay desteği iddia edilmez. Daha büyük bütçe için spatial partition ve etki bağımsızlığı kanıtı gerekir; kontrol kaldırılmadı.

## Eşzamanlı silme ve erişilebilirlik

Her job kendi özel checkpoint'ini tutar. Kalan kaynak listesi, silme talebi kabul edilmiş bütün owner'ları dışarıda bırakır; bu başka kişinin özel verisini silme yetkisi vermez. A/B eşzamanlı işlemlerinde final CAS kaybeden iş bekler/yeniler; C kaynakları korunur. Onayı olmayan owner iş seçimi veya body alanıyla hedeflenemez.

`020`–`021`–`023`–`024` adayları map/detail okumalarını, silinen kaynaklara konservatif olarak bağlı road bileşeninde gizler. Aynı canonical road GIST index'iyle 0.01 derece genişletilmiş kutuların geçişli kapanışı kullanılır. Bu ordinary map domain'inde mevcut 15 m overlap toleransını kapsayan **geniş** bir etkilenme alanıdır; hassas metrelik sınır iddiası yoktur. Polar/dateline/bozuk geometri, çelişkili sahiplik veya 128 road üzerindeki kanıt bütçesinde NULL/global read fence uygulanır. Viewport ve detail NULL'u fail-closed işler. Planet ile ilişkisi olmayan özel silme işi bu fallback'i tetiklemez; 129 yollu ilgisiz dünya için gerçek servis testi vardır. Önceden cache'lenmiş detail de current SQL context kontrolünü geçmek zorundadır.

Testte A'nın sorunlu yakın bileşeni görünmezken uzaktaki C trace'i/detail'i ve C'nin gerçek authenticated cloud-download Edge'i çalışır. **Yeni Planet yazıları global olarak beklemeye devam eder.** Yeni bir publish'in doğrulanmadan etki alanı kanıtlanamadığı için bu koruma gevşetilmedi. Kişisel bulut/GPS ve kaynak hesapların özel sürüşleri bu global Planet yazı kilidinden etkilenmez. Büyük/bağlantılı bir bileşenin yine geniş bir okuma kesintisi yaratabileceği açık kalan işletim riskidir.

## Yerel işletim ve restart

`tool/run_pgr6a.ps1` aynı pinlenmiş disposable descriptor'ı kullanır:

- `-WorkerMode status`: gizlilik korumalı kuyruk durumu.
- `-WorkerMode once`: tek sınırlı worker çağrısı; polling/cron değildir.
- `-WorkerMode retry -ReviewJob <job UUID>`: kaynak incelemesi/onarımdan sonra açık operatör requeue; yalnız mevcut yerel onaylı işe uygulanır.
- `-RestartLocal -PrepareOnly`: yalnız descriptor stack-id için CLI'nin veri koruyan resmi restart'ı; başlangıç/sonrası PGDATA ve system identifier aynı olmalıdır. Yeni proje veya migration bootstrap yapılmaz.

CLI JSON/env ve anahtarlar çıktıya verilmez. API/DB 127.0.0.1; stack `pgr6a-8e36def346`, system identifier `7702955514769424425` ve mevcut PGDATA subpath pinleri korunur. Container adı restart'ta değişebilir; testler ancak aynı stack öneki, aynı PGDATA ve aynı sistem kimliği doğrulandığında geçici adı yeniler. Docker `restart` tek başına deneysel Edge route kaydını geri getirmediği için kullanılmaz.

Test geliştirmesinde Docker-only restart sonrasında 404, ardından CLI restart/status JSON sözleşmesi ve geçici container adı farkı saptandı. Kontroller kaldırılmadı: resmi restart + açık `status.identity.id/name` doğrulaması + fiziksel pin kontrolü geliştirildi. Kesilen denemenin yalnız üç `example.invalid` hesabı, 34 sentetik yayını ve tek özel replay işi sahiplik/cluster kanıtıyla temizlendi; eski veri dizini/volume sıfırlanmadı. Son gerçek restart testi bütün yerel servisleri yeniden açtı ve kalıcı prefix'ten devam etti. Lease kaybı süresi testte kontrollü ileri alınır; bu, gerçek zamanda 120 saniye beklenmiş veya ağ ortasında kill edilmiş gibi raporlanmaz.

## Son doğrulama

- Saf replay/overlap/score/atomic builder: **106 PASS, 0 FAIL, exit 0** (103 planner/replay + 3 builder).
- Önceki servis sözleşmeleri: 20/20 PASS, exit 0 (ilk regresyon koşusu).
- Yeni büyük batch/restart, concurrent A/B, retry/review, bağımsız okuma/cloud Edge, crash tavanı: 5/5 PASS, exit 0 (ara koşu).
- Ön birleşik gerçek servis koşusu: 26/26 PASS, exit 0 (4m49s); ayrıca 129 kalan kaynak sınırı ve Planet ile ilişkisi olmayan özel hata için hedefli son kontroller PASS.
- Son birleşik gerçek servis koşusu: **27/27 PASS, 0 FAIL, exit 0 (4m53s)**; 20 önceki + 7 yeni senaryo. Atlanan servis testi yok. Final Auth, Storage, Planet, job/event/replay ve özel cloud sentetik kayıtları temiz; signup ve Group Drive kapalı.
- 11 public worker/replay/scope RPC için gerçek EXECUTE, SECURITY DEFINER, owner ve boş search_path katalog kontrolü PASS; internal validation/trigger yardımcıları istemciye açılmaz.
- Son yerel işletim doğrulaması: `WorkerMode status` → pending 0 / review 0 / jobs []; `WorkerMode once` → idle. İki komut da exit 0; yeni kullanıcı/iş oluşturulmadı.

Ek son kontroller: Deno type check PASS, PowerShell parse PASS, preparation/hash hedef korumaları 10/10 PASS. Checkpoint staged diff/secret taramasından sonra alınır; bu kayıtta token veya kullanıcı içeriği yoktur. Gerçek cihaz testi veya PROD deployment testi yapılmış sayılmaz.

## PROD aktivasyonundan önce kalanlar

Özel worker secret/scheduler kurulumu ve rotasyon/erişim planı ayrıca onay ister; bu görev PROD worker/cron açmaz. Review queue için operatör sorumlusu ve yanıt süresi, geçici snapshot/iş kaydı yaşam döngüsünün hukuki incelemesi, gerçek Free plan CPU/egress bütçesi, cihaz KeyStore/logout/GPS kabulü ve daha büyük spatial partition protokolü ayrıca gereklidir. Kişisel veriyi kalıcı tutmak için yeni hukuki istisna varsayılmaz. Yerel kabul, beta başlatma izni veya bütün Planet işlemlerinin sınırsız ölçeklenebildiği iddiası değildir.
