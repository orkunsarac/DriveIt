# P-GR6B — ortak Planet katkısı kaldırma: yerel kabul PASS

Tarih: 1 Kasım 2026. Kapsam yalnız yerel adaydır; PROD/DEV SQL, Auth ayarı, Storage veya Edge deployment değişmedi. UI flag, signup ve Group Drive kapalı kalır. Hukuki saklama politikası bu çalışma ile kesinleştirilmez.

## Kaynak ve sahiplik sözleşmesi

- `supabase/prod/bootstrap/202609220001_canonical_planet_base.sql`: publish → user; validated road → publish/user; section → validated road. Raw GPS/telemetri `world-drive-sources/<user>/<publish>.json` içindedir. Yolun ortak olması aynı geometriyi tek bir sahipsiz GPS kaydına dönüştürmez.
- `supabase/migrations/202609300003_active_world_empty_generation.sql`: her aktif/tarihsel trace kaynak publish, drive, road, section ve offset aralığı taşır. Generation kaynak publish sırasını korur.
- `supabase/migrations/202610060002_active_world_mutation.sql`: yeni kazanan eski trace'i kapatabilir. Silinen kazananın trace'ini kaldırmak, daha önce kapanmış diğer katkıyı tek başına geri getirmez.
- `supabase/functions/process-world-publish/world_scoring_stage.ts` ve `world_mutation.ts`: geometric coverage, 3 km karşılaştırma eşiği, canonical telemetry scoring ve mevcut Dart planner birlikte sahipliği belirler. SQL tek başına coğrafi kesişimden kazanan seçmez.

## Uygulama

Yeni ileri adaylar `202611010012`–`202611010017`, eski uygulanmış migration'ları değiştirmez. Job'a yalnız yeniden hesaplanmış generation işareti eklenir. Service-only context/commit/block RPC'leri `SECURITY DEFINER`, boş `search_path` ve dar EXECUTE grant kullanır. İstemci replay başlatamaz veya keyfi trace yazamaz.

1. Mevcut talep/onay, yeniden parola doğrulaması, owner fence, receipt ve lease kullanılır. Kullanıcının raw source dosyaları mevcut sınırlı Storage temizliğinin kapsamındadır.
2. Kalan yayımlanmış kaynaklar özgün generation sırasıyla alınır. Publish/user/road kimliği, section sayısı, processing version, canonical source yolu ve Storage owner doğrulanır. Eksik sıra, legacy/uyumsuz kaynak ve başka bekleyen Planet silme talebinde fail-closed uygulanır.
3. Yalnız kalan kullanıcıların kaynakları indirilir. Her dosya mevcut `RequestSourceLoader/sourceMatches` ile doğrulanır. Silinen kullanıcının GPS'i yeniden hesaplamaya veya ortak kalıcı veriye eklenmez.
4. `planet_rebuild.ts` mevcut overlap, score ve Dart mutation bridge'ini tekrar kullanır. Aynı `section-0` anahtarı farklı yollarda bulunabilir: hesaplama sırasında `(roadId, sectionKey)` ile isim alanı oluşturulur, SQL'e yazarken özgün anahtar aynen geri yüklenir. Offset veya skor formülü değişmez.
5. Context fingerprint generation, kaynak/section metadata, geometri ve Storage nesne sürümünü kapsar. Commit aynı kanıtı ve lease'i tekrar doğrular. Kaynak değiştirilmişse eski plan uygulanmaz. Silinen tarafta da road/publish/trace sahipliği çelişiyorsa erken dönüşlerden önce engellenir; tekrarlanan drive kimliğinde hangi hesabın kaynağı olduğu varsayılmaz.
6. Türev ortak trace indeksinin bütün eski sürümleri ve yeniden oluşturulması tek transaction'dadır. Kalan kullanıcıların eski parçalarının sınırları da A'nın katkısıyla kesilmiş olabileceğinden tarihsel türev geometri tutulmaz; canonical road/section/source ve kişisel sürüş geçmişi aynen korunur. Kaynak sahipliği, section, yön, canonical bounds, offset, minimum uzunluk ve duplicate interval doğrulanır. İşaret ve yeni generation yalnız commit ile kalıcılaşır. Commit cevabı kaybolursa aynı iş yeniden uygulanmaz.
7. Mevcut purge yalnız aynı generation için doğrulanmış rebuild işareti varsa ortak Planet engelini geçebilir. A'nın tüm eski/yeni trace'leri, publish/road/section'ları ve kimlik bağları temizlenir; ardından mevcut Auth-last akışı tamamlanır. B/C kaynak dosyaları, publish metadata'sı, canonical yolları ve kişisel bulut sürüşleri korunur.

## Kontrollü sınırlar ve çözülmeyen durumlar

Bu sürüm bütün kalan Planet kaynaklarını **sınırlı** yeniden oynatır: en çok 32 kalan road, 512 section, toplam 500 km, yol başına 100 km, 50.000 geometri noktası, 256 sonuç trace; dosya başına 4 MiB ve toplam 16 MiB source indirme; context en çok 2 MiB. Kaynak indirme stream sırasında sınırlanır ve aşımda iptal edilir; dosyanın tamamı indirilip sonra boyut kontrolü yapılmaz. Büyük veri kümeleri için kalıcı sayfalı replay henüz yoktur. Sınır aşımı veya kaynağın bozuk/eksik olması `blocked_planet` üretir; tamamlandı denmez ve başka kullanıcının canonical kaydı silinmez.

Mevcut fail-closed Planet okuma/yazma fence'i çözülmeyen işte genel Planet erişimini geçici durdurabilir. Bu kullanılabilirlik sınırı kaldırılmadı. Blocked işler private worker tarafından körlemesine döndürülmez; kaynak incelemesi/onarımdan sonra aynı receipt ile kontrollü retry gerekir. Receipt kaybı ile blocked işin operasyonel kurtarma prosedürü PROD aktivasyonu öncesinde ayrıca tamamlanmalıdır.

Altı yeni migration dahil aday zinciri henüz PROD'a uygulanmadı. Gerçek sağlayıcı log/backup/cache yaşam döngüsü ve hukuki inceleme, fiziksel cihaz KeyStore/GPS/logout kabulleri ve güvenli worker işletimi önceki rollout önkoşulları olarak kalır. Bütün sağlayıcı kopyalarının anında fiziksel silinmesi iddia edilmez.

## Gerçek test sonuçları

- Yeni replay sınır/fail-closed/stream testleri + mevcut overlap/score/mutation: **101 PASS, 0 FAIL, exit 0**.
- Güncel saf Dart calculator, 23 sentetik score oracle'ında mevcut JSON sonuçlarını aynen üretti; oracle veya beklenen skorlar değiştirilmedi.
- PROD hazırlık hedef/hash korumaları: **10/10 PASS**, yalnız sentetik hedefler, ağ yazması yok.
- Atomik baseline builder: **3/3 PASS, exit 0**; 25 migration ve tek transaction sözleşmesi korundu.
- Deno type check: endpoint ve gerçek servis test dosyası PASS.
- Yeni üç RPC için salt okunur katalog kabulü PASS: gerçek PUBLIC/anon/authenticated/service_role EXECUTE yetkileri, owner, SECURITY DEFINER ve boş search_path doğrulandı; runner bu kontrolü her hazırlıkta çalıştırır.
- Son birleşik gerçek servis koşusu: **20 PASS, 0 FAIL, exit 0 (2m37s)**; 14 eski + 6 yeni senaryo. Final temizlik geçti, signup ve Group Drive kapalı kaldı. Son kodda atlanan servis testi yok.

Servis senaryoları: önceki 14 hesap silme regresyonu; A/B/C tam overlap ve eşit skorda kalan B'nin geri gelmesi; kısmi overlap'te B ve C'nin geçerli aralıkları; yalnız A'nın desteklediği geometrinin kaybolması; eksik B GPS kaynağında tamamlanmanın reddi ve aynı receipt ile recovery; client RPC reddi, sahte A provenance reddi, INSERT aşamasındaki hata sonrası generation/retirement rollback; eski Storage sürümüne bağlı plan reddi; commit cevabı kaybında tek uygulama; çelişkili road/publish sahipliğinde silmenin engellenmesi; A'nın etkilediği eski B sınırlarının tutulmaması. Final test sentetik Auth/Storage/Planet/job/event/private-drive verilerinin temizliğini ve kapalı kilitleri doğrular.

## Bulunan ve giderilen teknik sorunlar

- SQL float değişkenlerinin JSON alias'larıyla çakışması: uygulanmış aday geriye dönük değiştirilmeden 013/014 ileri düzeltmeleri eklendi.
- 015 adayı: silinen taraftaki çelişkili road/publish sahipliği ve trace kaynak ilişkileri de erken dönüşlerden önce fail-closed denetlenir.
- 016 adayı: A'nın etkisiyle kesilmiş eski B/C trace sınırları kalıcı tutulmaz; yalnız türev indeks atomik yeniden kurulur, canonical kaynak ve kişisel sürüşler silinmez.
- Supabase `safeupdate`, 016'nın WHERE koşulsuz türev temizliğini reddetti; o koşu **15 PASS / 5 FAIL** ile bitti ve transaction'lar geri alındı. 017 adayı temizliği yalnız doğrulanmış `active_from_generation <= captured_generation` sürümleriyle kısıtlar, geleceğe ait tutarsız sürümlerde fail-closed döner. `safeupdate` kapatılmadı veya atlanmadı.
- Bridge'in road-local section anahtarlarını global sanması: yalnız withdrawal adaptöründe geçici namespace ve exact key restore uygulandı; duplicate denetimi kaldırılmadı.
- Önceden var olan compiler manifest sapması: dokuz transitive Dart kaynağı 10 Ekim güncellemeleriyle artefakt manifestinden ayrılmıştı. İlk planner koşusu **94 PASS / 1 FAIL** verdi. Hash körlemesine yenilenmedi: güncel native Dart'ın 23 oracle sonucu aynı çıktı; resmî `tool/build_world_scoring.ps1` ile JS + boundary artefaktları/manifest yeniden üretildi; mevcut 95 test ve yeni 3 test PASS oldu. PROD hazırlık manifestinde yalnız bu iki gözden geçirilen kaynak girdisinin hash'i güncellendi. 25 baseline SQL ve dokuz PROD function listesi aynı; yeni delete endpoint'i varsayılan deployment paketine eklenmedi. Gerçek PROD'daki artefaktlar bu görevde değiştirilmedi; ileride deployment ayrıca onay ister.

## Tekrar çalıştırma

Mevcut fiziksel kimliği pinlenmiş disposable descriptor ile `tool/run_pgr6a.ps1`; yalnız yeni senaryolar için `-Filter 'Planet withdrawal:'`. Yeni ortam istenirse `-Initialize` benzersiz stack yaratır, 25 doğrulanmış baseline + ayrı aday zincirini açıkça uygular; eski volume'ları reset/silmez. API ve DB 127.0.0.1, PGDATA subpath ve PostgreSQL system identifier doğrulaması korunur. Secret içeren stack JSON/env dosyaları rapor veya commit'e alınmaz.

Kullanılan ortam: `pgr6a-8e36def346`, PostgreSQL system identifier `7702955514769424425`; `instance-b3436369414ea6f69a97f0ab0683ed6e47a8d313236adcc1d9ab43b1d8d3786c-ea506b67-df52-4d8f-bd89-21aaa514b87d/data` subpath'i descriptor'a pinlidir. Runner her koşuda diğer çalışan DB mount'larıyla çakışmayı reddeder. Eski DEV veya PROD hedefi seçilemez. Bu çalışma temiz yeni PROD deployment testi veya canlı iki cihaz kabulü değildir.
