# P-GR5B izole sunucu entegrasyon kabulü

**Yerel sunucu servis kabulü PASS.** Gerçek Auth, PostgreSQL/PostgREST, Edge Functions, private Storage ve Realtime kullanıldı. Dış Mapbox servisi deterministik yerel fixture ile değiştirildi; ücretli/dış çağrı yapılmadı. Bu sonuç canlı Mapbox, PROD test hesabı veya fiziksel iki cihaz/GPS kabulü değildir.

Bu görevde PROD/DEV'e yazma veya deployment yapılmadı. Yerel grup regresyonunda gate test kapsamında açılıp sonunda FALSE'a döndü; PROD signup/gate değiştirilmedi.

## Fiziksel ortam

- Stack: `pgr2b-canonical-20261031`; project_id: `driveit-prod-bootstrap-pgr2b`.
- Stack ID: `6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe`.
- API: `http://127.0.0.1:27773`; DB host yalnız `127.0.0.1`.
- PostgreSQL system identifier: `7702837359395967017`.
- PGDATA subpath: `instance-6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe-f4223b3e-8b1a-4c2a-bc16-707753a33aca/data`.
- P-GR1 (`7702818118349594665`) ve atomik test (`7702852553093967913`) kümelerinden farklıdır. Ortak Docker volume adı fiziksel dizin eşitliği sayılmadı.
- 25 migration mevcut; kaynak migration'lar değiştirilmedi veya yeniden uygulanmadı.

## Gerçek sonuçlar

| Çalıştırıcı | Kapsam | Sonuç | Exit |
|---|---|---|---|
| `tool/test_prod_bootstrap.ps1` | M4 kapalı gate, grup/lobby/rejoin, kişisel sync, M2 fencing/cancellation | 185 SQL PASS | 0 |
| Aynı runner / `canonical_realtime_test.ts` | Auth profil trigger, owner UPDATE, private Storage/attach, kapalı RPC, yetkisiz açma, açık Edge/Reatime, pause/ban/leave/end/eski kanal | 1 PASS | 0 |
| `tool/run_pgr5b.ps1` / `canonical_drive_edge_test.ts` | Gerçek begin/upload/finalize/download, A/B ve anonim erişim reddi, replay/ACK, snapshot sayfalama, changed claim/bozuk envelope/hash reddi | 1 PASS | 0 |
| Aynı runner / `canonical_planet_edge_test.ts` | Auth/profil, private source, cross-owner publish reddi, attach, publish/aktivasyon, retry/tek road, başka hesapla viewport ve trace-detail | 1 PASS | 0 |

Son iki test toplu koşusu: **2 passed, 0 failed**, 40 saniye, exit 0. Önceki 65 owner-sync istemci testi canlı Edge yerine sayılmadı. 84 grup SQL kontrolü 185'in alt kümesidir; mükerrer toplanmadı.

## Onarımlar ve dış sağlayıcı sınırı

Kanonik stack önceki katalog incelemesinden kalan database-only seçimiyle çalışıyordu. Belgelenmiş veri koruyan `stack stop --stack-id` ardından `stack start --stack-id --eager` kullanıldı. Ham CLI JSON çıktısı bellekte tutuldu; anahtarlar yazdırılmadı. Hiçbir volume silinmedi/sıfırlanmadı.

Planet fixture'ı eski World Rules nedeniyle `unsupported_version`, 5 km altı rota nedeniyle `world_ineligible` aldı. Sunucu kuralları gevşetilmedi: test v6 ve yaklaşık 6.6 km sentetik rota kullanıyor. Edge runtime env yazımını desteklemediğinden yerel fixture yalnız test worker'ındaki env okumasını ve Mapbox HTTP transport'unu değiştiriyor.

`mapbox_fixture_entry.ts` yalnız `tmp/pgr2b-canonical` fonksiyon kopyasına kurulur; özgün handler aynı dizine `production.ts` olarak kopyalanır. Diğer HTTP istekleri gerçek servislere gider. Runner sonunda yerel entry özgün index ile geri yüklenir. PROD source/manifest/deploy paketine fixture eklenmez. Gerçek Mapbox anahtarı, eşleme kalitesi ve limitleri ayrıca kabul edilmelidir.

## Güvenlik ve temizlik

Runner API/DB loopback, container, fiziksel PGDATA ve sistem kimliğini Storage ayarı/hesap işleminden önce doğrular. Deno testleri kimliği tekrar kontrol eder ve uzak proje seçimini reddeder. Deno servis network izni yalnız `127.0.0.1:27773` içindir.

Drive testi mevcut Phase 8 çekirdek M1 senaryosundan türetilmiştir; global orphan sweep çalıştırılmaz. Cleanup yalnız bu run'da yaratılan owner UUID'lerine bağlıdır. Immutable test sürüşleri yalnız bu izole DB'de ve bu owner'lar için kaldırılır. Planet cleanup yalnız kendi publish/source/road/trace/generation kayıtlarını hedefler, kendi generation değişikliğini başlangıca döndürür. Başka owner verisi silinmez.

Son SQL sayımları: users=0, profiles=0, Storage objects=0, publishes=0, roads=0, traces=0, groups=0, memberships=0, manifests=0, intents=0; gate=false, generation=0, migrations=25.

Kimliği sabitlenmiş çalışan stack üzerinde `tool/run_pgr5b.ps1` iki ek testi, `-Filter Planet` yalnız ilgili testi çalıştırır. Uzun komutlar session ID ile gerçek exit code alınana kadar izlenir; runner başarısızlıkta nonzero döndürür.

## Politika denetimi ve beta sınırı

`tool/audit_prod_policies.ps1` 25 migration hash/sırasını doğrular; ayrı atomik test DB'sinde rollback transaction ile beklenen katalog üretir; PROD'u yalnız read-only katalog sorgusuyla karşılaştırır. RLS, policy ifadeleri/rolleri, CRUD/table yetkileri, fonksiyon gövdeleri, SECURITY DEFINER/search_path ve EXECUTE hakları [raporda](prod_pgr5_policy_audit.md) nesne başına kayıtlıdır: 18 tablo, 11 policy, 39 fonksiyon, 0 uyuşmazlık, exit 0.

Beta için gerçek Mapbox ve fiziksel iki cihaz/GPS/recovery; SMTP/domain/redirect; hesap/veri silme; Gezegen saklama/hukuki kararları ayrıca tamamlanmalıdır. PROD aktivasyonu ayrı karardır. Broad PAT bu entegrasyon görevinde kullanılmadı veya iptal edilmedi; önceki read-only politika denetiminde kullanılmıştı.
