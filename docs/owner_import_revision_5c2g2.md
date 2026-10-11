# DriveIt — Aşama 5C.2G.2 Owner Revision ve Durable Legacy Görünürlük

Durum: **repository/ledger çekirdeği uygulanmış; üretim ve ekran entegrasyonu kapalı**
Kapsam: 5C.2G.2. Bu aşama gerçek kullanıcı verisini migrate etmez ve `LocalOwnershipGate.production` değerini açmaz.

## Mimari kararı

İki seçenek değerlendirildi:

1. Verified legacy partition'ı ekran okumasında owner deposunun üzerine overlay etmek. Bu, her repository'de precedence/ID çakışması davranışı ve iki kaynağın tutarlı okunmasını gerektirir; World/Career semantiğini ekran okumasına dağıtır.
2. Kaynakları tek owner revision için hazırlamak ve yayınlamayı SQLite'daki tek pointer transaction'ıyla yapmak. Normal ekranlar ancak ileride revision-aware facade'a bağlandıktan sonra bu görünümü okuyabilir.

İkinci seçenek seçildi. Bu uygulama revision payload'larını henüz canlı owner Hive kutularına yazmaz ve ekranlara bağlamaz; yalnız opaque, adapter-encoded kayıtları ve dosya referans kanıtını hazırlayıp tek durable visibility pointer sağlar.

## Değişiklikler

- `LegacyClaimLedger` ayrı claim ledger'ını schema v1'den v2'ye additive yükseltir. Claims/receipts korunur; GPS journal v3 veritabanına dokunulmaz.
- V2 tabloları owner revision manifest/records/assets, owner başına current pointer ve immutable import visibility receipt'i tutar. Preparing kayıtları görünür değildir.
- `completedForOwner(UUID)` yalnız claim discovery yapar. `completed` hâlâ verified import partition kopyası demektir; visibility değildir.
- `VerifiedLegacyImport` adapter'ların gerçek Hive binary serialization çıktısını, source namespace/fingerprint ile beraber revision planına sağlar. Kaynak partition salt-okunur kalır. Dosya varlıkları namespace ve fingerprint üzerinden yeniden doğrulanır.
- `OwnerRevisionRepository` tam owner group coverage, owner lease, debug synthetic gate, aynı owner'a tamamlanmış claim, verified import, provenance çözümü, source-current kontrolü ve registered writer fence ister.
- Owner snapshot fingerprint'i kanonik kayıt kimliği/hash'leri ve asset identity/hash/size/path listesinden yeniden hesaplanıp prepare başlamadan karşılaştırılır; stale/tahrif edilmiş manifest revision oluşturmadan reddedilir.
- Provenance çakışması, aynı identity/farklı içerik, unresolved row, singleton profile/career/outbox belirsizliği, owner/claim uyuşmazlığı, stale base, eksik/bozuk asset veya domain evidence yokluğu fail-closed olur.
- Prepare ve verify sonrası publish tek SQLite transaction'ında revision'ı `published` yapar, expected base generation'ı CAS ile ilerletir ve visibility receipt'i yazar. Transaction başarısızsa pointer ve visibility birlikte rollback olur. Tekrarlanan başarılı işlem immutable receipt/revision kimliği ile aynı sonucu döndürür.
- `visibleRecords` sadece pointer'ın gösterdiği published revision'ı sayfalı olarak döndürür; stale owner lease reddedilir.

## Güven sınırı ve açık entegrasyonlar

`OwnerRevisionDomainVerifier` ve `RegisteredSourceWriterFence` zorunlu enjekte edilen arayüzlerdir. Bu aşamadaki test verifier'ı sentetiktir; gerçek My World rebuild, Career aggregate, tombstone provenance, poster resolver, profile merge veya Planet outbox doğrulamasının production implementasyonu değildir. Dolayısıyla revision publisher gerçek hesap verisi için güvenilir bir domain merge olarak sunulamaz.

Kayıtlar normal owner Hive kutularına promote edilmediğinden, `visibleRecords` yalnız repository API'sinde görünürlük sağlar. Bootstrap, ekranlar, arka plan consumer'ları ve legacy consent/navigator bu read API'ye geçirilmemiştir. Production gate varsayılan kapalı ve yeni API bu fazda mevcut üretim akışından çağrılmıyor. Gate kapalıyken gerçek import/merge/migration başlamaz.

## Recovery/idempotency

- Prepare/verify safhaları kalıcı intermediate revision kayıtları bırakabilir; pointer değişmediği için normal görünürlükte yer almaz. Aynı deterministik input güvenli retry için aynı revision identity'yi kullanır.
- Publish transaction'ındaki hata eski pointer'ı korur.
- Commit sonrası cevabın kaybolması durumunda aynı source/import/plan revision tekrar bulunur; yeni generation yaratılmaz.
- Eski source claim başka owner'a reassignment edilemez. Import kaynakları yalnız tamamlanmış claim ve aynı owner UUID/fingerprint ile kabul edilir.
- Writer fence başarıyla drain edilmeden işlem devam etmez; finally yolunda resume edilir. Fail-pause senaryosu importer'ın staging'e girmediği test edilir.

## Test kapsamı

Sentetik fixture/fake owner ile doğrulanan senaryolar: ledger v1→v2 additive migration ve completed claim koruması; owner/legacy provenance çakışmaları; identical dedupe ve conflicting payload; unresolved/cumulative Career; tombstone suppression; profile/outbox conflicts; missing/corrupt assets; prepare/verify kesintisi; publish transaction rollback; commit sonrası response-loss retry; stale base; source değişimi; writer fence pause/resume; stale owner lease; A/B pointer izolasyonu; gate kapalı erişim.

Kontrollü exception senaryoları gerçek OS process kill, Android power loss, fsync/flash failure veya multi-process cihaz kabulü değildir. Bu aşamada A55, Supabase ve gerçek kullanıcı verisi üzerinde işlem yapılmadı.

## Aşama kararı

5C.2G.2'nin **durable repository primitive** kısmı tamamlandı. Gerçek owner domain merge doğrulayıcıları, owner Hive'a materialization, bütün kişisel ekranların tek revision facade'a yönlendirilmesi ve restart kabulü eksiktir. Bu nedenle gerçek import/visibility akışı açılmamalı; sonraki ekran/domain entegrasyon aşamasından önce bu sınırlar korunmalıdır.
