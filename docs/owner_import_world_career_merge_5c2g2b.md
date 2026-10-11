# DriveIt — Aşama 5C.2G.2B World/Career Merge İncelemesi

Durum: **UYGUN DEĞİL — gerçek domain merge implementasyonu başlatılmadı.**
Branch/HEAD: `feature/gps-refactor` / `f68445cb7038e50b95f0da139fc7b7b307267105`.

## Karar özeti

İstenen merge'i mevcut World/Career depolarına güvenli biçimde bağlamak için gereken source-provenance/ref eşlemesi bu modellerde bulunmuyor. Revision katmanındaki `sourceIdentity`, caller-provided owner provenance resolver ile üretiliyor; gerçek eski World tombstone'ları ve Career kümülatif değerleri için kaynağın sahibi/provenance'ı kanıtlayan alan yok. Bu aşamada sentetik evidence üretip mevcut `OwnerRevisionDomainVerifier` üzerinden publish'e izin vermek güvenli olmaz. Gerçek kullanıcı verisi veya production gate'e dokunulmadı.

## Doğrulanan World modeli

- `WorldSourceSnapshotRepository` kaynak bundle'larını `drive.id` ile anahtarlıyor. `LocalSourceBundle` içindeki drive, telemetry, score ve validated road ilişkileri aynı `drive.id` üzerinden doğrulanıyor.
- `ActiveWorldTrace` yalnız `sourceDriveSessionId`, `validatedRoadId`, `matchedSectionId` ve offset aralığı taşıyor. Trace'te source namespace/fingerprint veya original-source identity yok.
- `LocalLifecycleJournal` tombstone'ları `world:<driveId>` veya `worldTrace:<traceId>` altında saklıyor. Trace tombstone payload'ı `sourceId`, road/section ID ve span içeriyor; provenance fingerprint'i içermiyor.
- `MyWorldRebuildService` mevcut `WorldIndexMutationPlanner`/processing/overlap servislerini kullanıyor; source drive ve validated road ilişkisini ID üzerinden yükleyip yeni index generation'ını yazar. Gerçek `MyWorldRepository` kutuları ve index pointer'ı owner-scoped Hive alanıdır.
- Dolayısıyla aynı drive/trace ID farklı kaynak provenance'ları için gelirse, raw revision satırlarını ayırmak yeterli değil: bütün source bundle, telemetry, score, validated-road, processing, pending-job, trace ve tombstone referansları deterministik remap edilip World rebuild'e verilmelidir. Mevcut tombstone alanları bu remap'in doğru kaynağı seçtiğini tek başına kanıtlayamaz. ID eşleşmesine göre tombstone uygulamak diğer provenance'ı silebilir.
- World rules v6 korunmalıdır. Bu incelemede mevcut rebuild motoru çağrılmadı ve generation üretilmedi.

## Doğrulanan Career modeli

- `CareerContributionRepository` katkıları `drive:<DriveSession.id>` Hive key'iyle saklıyor. Contribution JSON içindeki bundle'ın `drive.id` değeri de aynı kimliktir; kayıt provenance namespace/fingerprint taşımıyor.
- `career_totals` `totalDistance`, `totalDuration` ve `countedIds` gibi kümülatif değerleri tutuyor. `countedIds` source identity değil, drive ID listesidir.
- `prepareLegacy` mevcut toplamı katkılardan yeniden kurmayı yalnız exact ID/count/distance/duration eşleşmesi varsa kabul ediyor. Bu, silinmiş sürüşlerin tarihsel katkısını veya aynı ID'li farklı provenance'ları kanıtlamaz.
- Aynı drive ID farklı provenance ile ayrı tutulacaksa mevcut `drive:<id>` tüketicisi iki contribution'ı temsil edemez. Kümülatif toplam da katkı provenance'ı yoksa ne güvenle yeniden hesaplanabilir ne de otomatik eklenebilir. Kaynağı değiştirmeden unresolved bırakılmalı ve revision visibility engellenmelidir.
- `CareerStatisticsService` istatistikleri `DriveSession` kayıtları üzerinden hesaplar; source identity veya contribution receipt'i eklemez. Bu servisi doğrudan çağırmak provenance-aware exactly-once merge kanıtı olmaz.

## Revision katmanıyla fark

`OwnerRevisionRepository` generic binary row + `sourceIdentity` saklayabilir ve generic conflict/dedupe kuralları uygular. Ancak generic planner:

- Legacy `local_lifecycle_v1` tombstone'larından doğrulanmış source target identity üretmiyor.
- World kaynakları için complete remap/ref closure oluşturmuyor ve gerçek `MyWorldRebuildService` sonucunu revision payload'ına yazmıyor.
- Career contribution JSON'larını `CareerContributionRepository` semantiğiyle birleştirmiyor veya aggregate read-back yapmıyor.
- `OwnerRevisionDomainVerifier`'ın döndürdüğü map'in sentetik `verified: true` olmasını tek başına domain doğrulaması kabul ediyor. World/Career proof'unun gerçek depolardan geldiği garantisi yok.

Bu nedenle mevcut 5C.2G.2 sentetik pointer yayın testleri, World/Career merge veya onların production doğrulaması olarak yorumlanmamalıdır. Bu aşama raporu mevcut altyapıyı başarısız/bozuk diye sınıflandırmaz; eksik yeteneği açıkça ayırır.

## Güvenli devam için gerekli sözleşme

1. Provenance taşıyan typed revision input: her source bundle, contribution ve tombstone için sabit source namespace/fingerprint + original key.
2. World collision remap tablosu: eski → deterministik yeni drive/road/section/trace/job key eşlemesi; bütün foreign-reference alanlarını kapsayan closure doğrulaması. Geometri ve canonical offsetler byte/değer olarak değişmemeli.
3. Tombstone resolution: legacy tombstone yalnız aynı source namespace/fingerprint içindeki unambiguous target'a uygulanmalı; provenance alanı olmayan/çoklu hedefli tombstone unresolved olarak kaydedilip publish'i engellemeli.
4. World staging: gerçek `MyWorldRebuildService` ve world rules v6 ile yalnız disposable staging repositories üzerinde generation üretmek; typed snapshot/checksum'i immutable revision payload'ına yazıp flush/close/reopen/read-back doğrulamak. Owner active pointer bu staging sırasında değişmemeli.
5. Career staging: contribution identity'yi `(owner, source namespace, source fingerprint, original drive ID)` üzerinden taşıyan revision-only hesap; duplicate içerik tam bir kez, aynı identity/farklı içerik conflict. Cumulative-only total unresolved kaydı olarak korunmalı ve user/product çözümü olmadan publish engellenmeli.
6. Bütün-domain publisher: World/Career verifier başarıları tek başına yeterli olmamalı. History/Score/Profile/Poster/Planet/outbox ve relationships için gerçek verifier yoksa visibility pointer transaction reddedilmeli.

Bu 5C.2G.2B turunda bu sözleşme tasarımı dışında kod, migration, gerçek World generation veya Career verisi değiştirilmedi. Sahte source identity, geometri veya contribution üretilmedi.

## Test ve çalışma ağacı

Bu turda kod değişikliği olmadığı ve doğrulanmış veri modeli çelişkisi implementation'ı bloke ettiği için yeni merge testleri çalıştırılmadı; daha önceki 827/827 Flutter sonucu bu yeni World/Career davranışını kapsamaz. Analyze/diff sonucu da bu aşama için yeniden üretilmedi. Başlangıçta var olan 5C.2F/5C.2G.2 dirty ve untracked dosyalar korunmuştur; `tatus` dosyasına dokunulmamıştır. Commit/push, A55, Supabase ve gerçek kullanıcı verisi işlemi yapılmadı.

**5C.2G.2B kararı: HAYIR / devam için güvenli değil.** Önce provenance/ref-closure sözleşmesi ve revision-only World/Career staging çözümü uygulanıp sentetik oracle testleriyle kanıtlanmalıdır. Üretim gate kapalı kalmalıdır.
