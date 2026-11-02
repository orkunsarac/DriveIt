# P-GR7I 4F1C — sürümlü reliable skor sözleşmesi

**Dar skor sözleşmesi / native Dart ↔ derlenmiş Planet JS kabulü: PASS.** Legacy v1 değişmedi. Public Planet yayın/karşılaştırma rollout'u, hosted kabulü ve cihaz kabulü bu kayıtla tamamlanmış sayılmaz.

## Açık kimlik

Skor kimliği artık yalnız algorithmVersion değildir:

| Alan | Legacy | Yeni reliable |
| --- | --- | --- |
| algorithmVersion (puan ağırlıkları/kuralları) | 1 | 1 |
| calculationMode | legacy_v1 | reliable_intervals |
| calculationVersion | 1 | 1 |
| reliabilityPolicyVersion | yok | 1 |
| PublishedDriveSource schema_version | 1 | 2 |

`calculate()` v1'in matematiği aynen korundu. `calculateReliable()` aynı mevcut reliable hesabı üretir, sonucu açık mod/sürüm/politika metadata'sıyla etiketler; yeni ağırlık/eşik eklenmedi. Eksik eski kayıt modu `unspecified` kalır; reliable olduğu tahmin edilmez. Mevcut snapshot varsa persistence coordinator onu aynı nesne olarak döndürür ve yazmaz.

## Yerel kayıt ve uyumluluk

- `DriveScoreResult` ve `DriveScoreRecord`: hesaplama modu/sürümü/politikası alanları.
- `DriveScorePersistenceCoordinator`: yeni policy 1 kayıtlarını mevcut %80 kapsam + hareket kanıtı kontrolünden sonra reliable hesaplar; bilinmeyen politika veya legacy/kanıtsız hız kaynağıyla yeni reliable skor üretmez.
- `DriveScoreRecordAdapter`: mevcut typeId 4 ve alan 0–6 korunur, yeni alanlar 7–9 eklenir. Eski 7 alanlı kayıt yeni okuyucuda aynı sayısal puanla açılır. Kayıtları topluca yeniden yazan bir migration yoktur.
- `LocalSourceBundle` ve owner-sync skor karşılaştırması mod metadata'sını kayıpsız taşır. `unspecified` eski kayıtlarda yeni alanlar payload'a zorla eklenmez; eski fingerprint anlamı korunur.

Test: sentetik eski 7 alanlı Hive dosyası açıldı; eski toplam aynı kaldı. Yeni reliable mod kayıt edilip box yeniden açıldığında mod/sürüm/politika korundu. Testte adapter override yalnız bu izole eski-format fixture'ını üretmek içindir, uygulamaya böyle bir override eklenmedi.

## Source schema 2

`PublishedDriveSource` legacy schema 1 JSON'unu korur. Schema 2 yalnız `reliable_intervals / calculationVersion=1 / reliabilityPolicyVersion=1` ile kabul edilir:

- Ham rota için `break_before`.
- Her kanonik örnek için `break_before`, `gap_duration_micros`, `speed_source`, `acceleration_reliable`.
- UTC ISO timestamp ve onunla tam eşleşen string `timestamp_micros`; JS Date.parse milisaniyeye indirgendiğinde kalan mikrosaniyeler BigInt ile ayrıca doğrulanır.
- `telemetry_reliability`: reliabilityPolicyVersion, startedAtMicros, stopRequestedAtMicros.
- Source started_at / ended_at reliable metadata'dan alınır; save zamanı veya DriveSession.duration kullanılarak reliable süre uydurulmaz.

`PublishedDriveSourceBuilder` yeni reliable kaydı, doğru driveId/telemetry sürümü ve saved score moduyla seçer; kaynak mevcut score sayısını içermez. Builder doğru owner deposundan hem telemetryLoader hem scoreLoader alacak şekilde enjekte edilebilir. Eksik mode/policy/quality ile schema 2 üretilmez. Eski/etiketsiz kayıtlar yalnız eski süreklilik guard'ıyla legacy kaynak yolunda kalabilir; reliable'a yükseltilmez. Eski hazır source path'leri değiştirilmez.

Gerçek source-upload servisi mevcut immutable, upsert=false JSON yükleme/attach yolunu kullanır. Schema 2 için server ACK source schema, algoritma/telemetri sürümü, sayılar, publish id ve path ile eşleşmelidir. Downgrade ACK başarısızdır. Bu bağlantı fake gateway ile test edildi; gerçek upload veya hosted işlem yapılmadı.

## Planet hesabı

`published_source_score_calculator.dart` schema 2'yi doğrular, tüm kalite alanlarını kayıpsız kanonik noktalara dönüştürür ve gerçek `calculateReliable()` çağırır. `tool/planet_detail_js.dart` schema 1 için eski calculator, schema 2 için bu helper'ı kullanır. Planet JS bundle elle yazılmış formül değildir; mevcut Dart compiler üreticisinden gelir.

`source_contract.ts` mode/sürüm/politika, sürüm ve sayı eşleşmeleri, hız kanıtı, bool alanlar, gap, kronoloji ve mikrosaniye kanıtını doğrular. İstemciden yollanan hazır `score` kabul edilmez. `detail.ts` gerçek telemetriden server bundle ile hesaplar, reliable modun confidence/sürüm/katkı alanlarını döndürür. Bundle eskiyse veya mode/sürüm metadata'sı eksikse schema 2 yanıtı reddedilir. Cache anahtarı schema'yı da içerir; hesap sonrası schema/readyAt değişimi tekrar kontrol edilir.

## 711 ↔ 694 ve kapsama sınırı

Aynı büyük GPS boşluklu veride legacy ham hesap 694, reliable ham hesap 711'dir. Yeni schema 2 JS reliable sonucu native Dart reliable sonucu ile **711 ↔ 711** eşleşir; total/kategori/confidence/katkı/sürüm alanları da karşılaştırılır. Bu iki farklı modun matematiği birbirine zorlanmadı.

Bu özel tam-sürüş örneğinin ölçülmüş kapsamı %80'in altındadır. Telefonun persistence katmanı sayısal skor üretmez; server detay katmanı da `scoreEligible=false` için `score=null` döndürür. Sadece ham 711 eşitliğine bakıp eksik verili sürüşü puanlanabilir ilan etmedik. Kapsamı yeterli kısa boşluk, dur-kalk, segment sınırı ve unavailable örnek içeren reliable vakalar da ayrıca test edildi.

## Yayın ve karşılaştırma sürüm sınırı

Mevcut `process-world-publish/index.ts` ve `RequestSourceLoader` yalnız legacy source schema 1 karşılaştırmasını destekliyor. Bu guard gevşetilmedi: schema 2 aynı algorithmVersion=1 taşısa da v1 karşılaştırmaya sokulamaz. Yeni bir source2 yayımlama/karma-mod yol kazananı algoritması bu aşamada açılmadı. Schema2'yi eski motorun reddetmesi yeni testle doğrulandı; legacy World golden/parity sonuçları korundu. Yerel PlanetSegment outbox halen disabled gateway kullanır; onun eski payload'ları yeniden yazılmadı veya güvenilir public skor olarak kullanıma açılmadı.

Bu aşamanın tamamlanan işi yeni skor sözleşmesi, kayıpsız kaynak ve kaynak telemetrisinden güvenli server detay hesabıdır. Public schema 2 processing/ownership karşılaştırması için ayrıca kabul gerekir; mevcut uygulama bunu desteklenmiyor olarak reddeder.

DB migration gerekmedi: mevcut `world_publishes.source_schema_version` pozitif integer kabul eder; attach RPC de pozitif sürüm alanlarını taşır. Yeni mode/policy metadata'sı immutable source JSON'unun içinde schema 2'yle bağlanır. Canonical bootstrap SQL ve mevcut metadata sözleşmesi salt okunur incelendi; canlı şema sorgusu/değişikliği yapılmadı. Yeni migration dosyası veya deploy yok.

## Gerçek doğrulamalar

- Native Dart ↔ yeni Planet JS: **22/22 PASS**, exit 0 (12 legacy + 10 reliable). Toplam, display, kategoriler, confidence, contributions, algorithm/mode/version/policy ve eligibility karşılaştırılır; sayısal tolerans 1e-9.
- Korunan eski bundle ↔ native legacy: **12/12 PASS**, exit 0.
- Deno Planet/source-contract/World validation ve golden-scoring: **73 PASS**, exit 0. `planet-trace-detail/detail.test.ts` tek başına **12/12 PASS**; eski bundle'ın schema2 için reddi, eksik kanıt, sahte hazır skor ve 711/694 assertion'ları dahil.
- Tam Flutter host: **1228 PASS, 2 önceden mevcut skip**, exit 0. Son schema2 upload ACK kontrolü ve ek testi sonrası ilgili source/persistence hedefli paket: **16/16 PASS**, exit 0 (toplamlara tekrar eklenmez).
- Skip nedenleri: isolated Android compile-time define gerektiren guard testi; Windows'ta synthetic symlink oluşturma izni gerektiren poster testi. Bu görev test atlaması eklemedi.
- Tam Flutter analyze: önceki **3 warning + 4 info**, yeni bulgu yok. Yeni biçim bulguları giderildi. Flutter analyzer'ın bu baseline ile exit 1 davranışı korunur.
- `git diff --check`: PASS.

Üreticiler: `build_planet_detail_score.ps1` ve paylaşılan score-model bağımlılığı değiştiği için `build_world_scoring.ps1`. Her iki manifest ve boundary fixture güvenilir üreticiyle yeniden oluşturuldu; hash'ler elle yenilenmedi. Önceki skor parity aracı artık reliable schema2 vakalarını ayrı sözleşmeyle zorunlu karşılaştırır; legacy mod ile reliable modun aynı olması beklenmez.

## Açık sınırlar

Hosted PROD/DEV, gerçek cihaz, gerçek e-posta, kamuya yayın ve kaynak2'nin canlı World processing kabulü **NOT TESTED / ETKİN DEĞİL**. PROD Auth/signup, cloud/Planet/Group/deletion worker gate'leri ve hukuki onboarding korunur. Eski sürüşler yeniden hesaplanmadı. R1/signing ve ilgisiz yerel değişiklikler checkpoint dışında tutulur. Sonraki aşamaya geçilmez.
