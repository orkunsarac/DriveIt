# DriveIt — Aşama 6 offline sync istemcisi (ilk dikey dilim)

## Aşama 5 checkpoint

Release composition değişiklikleri `9114b5436670e629b228f3466153f9d7b88771b8` commit'iyle `feature/gps-refactor` dalına gönderildi. Commit ve remote HEAD eşleşiyor. Commit, fiziksel Android kabulinin beklemede olduğunu açıkça belirtiyor; üretim owner gate'i kapalıdır. A55 şu an ADB'ye bağlı değil; release-mode fiziksel kabul yapılmış sayılmıyor.

## Hazırlık incelemesi

Yeni sürüşün sabit owner ve `sourceIdentity` kanıtı, `GpsOwner`, `OwnerScopedLocalStore`, `drive_source_provenance_v1`, `LocalSourceBundle` ve `OwnedDriveFinalization` içinde zaten mevcut. Planet'in `planet_segment_outbox_v1` kutusu ayrı bir yayın alanıdır; özel sürüş senkronizasyonu için yeniden kullanılmadı. `OwnerScopedLocalStore.groups` altında ayrı, sürümlü `owner_sync_outbox_v1` kutusu eklendi. Bu store yalnız kontrollü owner-scoped bileşimde açılır; production bootstrap veya gate bağlantısı eklenmedi.

## Yerel sync mutation sözleşmesi v1

Her mutation şu sabit alanları taşır:

- `version`, `kind` (`driveUpsert` / `driveTombstone`)
- `ownerScope`, Supabase UUID'si olan `ownerId`
- UUID v4 `sourceIdentity`
- owner + işlem türü + kimlikten türetilen `idempotencyKey`
- payload SHA-256 `payloadFingerprint`
- v2 `LocalSourceBundle` sürüş içeriği veya sınırlı silme payload'u

`driveUpsert` yalnız account owner için; finalization `completed` ve `derivedReady` olmalı, History tombstone'u bulunmamalı, World source bundle, telemetry ve owner sidecar/Hive provenance kanıtı birbiriyle tutarlı olmalıdır. `guest`, `legacy_unassigned`, unproven, eksik ve tamamlanmamış sürüşler kuyruğa alınmaz. Yerel drive ID payload'da kalır; uzaktaki tekillik owner ve provenance kimliğiyle kurulur.

Poster dosyaları veya eski kayıtlar payload'a eklenmez. `LocalSourceBundle` içindeki mevcut sözleşme `mapImagePath` değerini boş gönderdiği için bu dikey dilim poster sync'i vaat etmez.

Outbox kaydı Hive `put` + flush + read-back kullanan owner-scoped store ile kalıcılaştırılır. Var olan key ve aynı fingerprint yeniden enqueue edilirse aynı kayıt döner; farklı içerik aynı idempotency anahtarına gelirse conflict oluşur. `sending` durumu ağ çağrısından önce kalıcıdır. Taşıma hatası güvenli hata koduyla `retryableFailure` olur. Uzak kabul sonrası yerel ACK yazılamazsa bir sonraki deneme aynı idempotency anahtarıyla yapılır. Uzak receipt'in owner scope, idempotency key veya fingerprint'i uyuşmazsa kabul edilmez. Yeniden deneme davranışı fake adapter üzerinden doğrulanmıştır; sunucu idempotency garantisi henüz yoktur.

## Silme/tombstone sınırı

Mutation wire modeli minimal `driveTombstone` çeşidini tanımlar; kaynak payload'u içermez. Ancak bugünkü `local_lifecycle_v1` History tombstone'u kalıcı `syncDeletionId`, orijinal `deletedAt` ve provenance bilgisini taşımıyor. Bu yüzden `enqueueTombstone` var olan kayıtta bu kanıtları arar ve bulamazsa kapalı davranır. Silme senkronizasyonu etkin değildir; timestamp/kimlik uydurulmaz. Çevrimdışı silme ile daha eski upload'ın server tarafında yarışmasını ve resurrection'ı çözmek için backend revision/cursor sözleşmesi sonraki gerçek backend fazında tanımlanmalıdır.

## Çalışan sentetik dikey senaryo

Gerçek kontrollü `ForegroundService.start()` → SQLite journal → `DriveStorageService.saveDrive()` → `LocalOwnerLease.transferGps()` → owner Hive read-back/finalization yolu tamamlandıktan sonra owner lifecycle yerel outbox reconciliation planlar. Reconciliation yalnız ilgili account namespace'indeki `owned_drive_finalization_v1` girdilerini tarar; yalnız `completed` + `derivedReady` finalization, mevcut proven source bundle/telemetry ve owner-scope eşleşmesi olan, History tombstone'u bulunmayan yeni sürüşü kuyruğa alır. Guest/legacy, belirsiz, yarım veya silinmiş kayıtlar atlanır. Bu tarama hiçbir remote adapter çağırmaz.

`LocalOwnerLifecycle` aynı reconciliation'ı owner deposu güvenli biçimde açıldıktan sonra da çalıştırır. Böylece owner Hive finalization tamamlanıp outbox kalıcılaşmadan süreç kapanırsa sonraki güvenli owner başlangıcı eksik outbox girdisini aynı idempotency key ile tamamlar. Bir kuyruk flush hatası finalization sonucunu başarısız yapmaz; güvenli `owner_sync_queue_pending` durumu tutulur ve sonraki başlangıçta tekrar denenir. Reconciliation çalışırken yeni bir finalize olursa ikinci bir pass işaretlenir; başlangıç taraması yeni sürüşü kaçırmaz.

`OwnerDriveSyncWorker.runOnce()` yalnızca açıkça verilen adapter ile, sabit pending-key snapshot'ını ve sınırlı sayıda kaydı işler. Timer, arka plan servisi, kendiliğinden tekrar döngüsü veya production network adapter yoktur. Fake remote önce `offline` hatası verir; outbox `retryableFailure` olarak kapanıp yeniden açıldıktan sonra aynı key/fingerprint ile tekrar gönderilir. A→B→A geçişinde B'nin lease'i A kuyruğunu okuyamaz; eski A worker'ının gecikmiş yanıtı B deposuna ACK yazamaz ve A'ya dönünce aynı key güvenle denenebilir. Fake remote idempotency davranışıyla yalnız bir uzak kayıt kaldığı doğrulanır.

Ek bir koruma olarak, kuyrukta bekleyen upsert sürüşü yerel History tombstone'u almışsa worker remote çağrısından önce mutation'ı kalıcı conflict olarak işaretler; henüz sözleşmesi bulunmayan silme işlemi, daha eski bekleyen upsert ile sürüşü diriltmez.

## Güvenlik ve açık sınırlar

- `LocalOwnershipGate.production` ve `main()` değişmedi; gate kapalı.
- Production composition'da owner açılışı/finalization sonrasında otomatik olan adım yalnız yerel outbox reconciliation'dır; production remote adapter/worker yoktur. Sentetik kabul composition'ı açıkça fake adapter verirse lifecycle owner-ready/finalization'da bir bounded worker pass çalıştırabilir ve `onOwnerResumed()` ile tek bir retry pass tetikleyebilir. Bu test yolu gerçek Supabase/HTTP kullanmaz.
- Gerçek A55/DriveIt verisi veya Supabase kullanılmadı; backend deploy yapılmadı.
- Outbox A/B/guest/legacy Hive namespace'lerinden ayrıdır.
- Outbox flush hatası + store kapat/aç kontrollü hata testiyle crash-gap recovery doğrulandı; bu gerçek OS process kill/power-loss kabulü değildir. Fake remote gerçek sunucu idempotency garantisi değildir.
- Tombstone/remote revision ve multi-device merge çözümü eksiktir.

İki bağımsız local store ile fake pull/cursor kabulinin ayrıntılı wire ve güvenlik sözleşmesi `docs/drive_sync_contract_phase6.md` içindedir. Download uygulaması sınırlı olarak History/route/telemetry/provenance ve mevcut Score snapshot'ını kopyalar; World/Career'ın diğer cihazdaki türetilmiş projection'larının eşitlenmesi bu kabulde iddia edilmez.

## Testler

- `owner_drive_sync_client_test.dart`: 5/5 geçti.
- `owned_drive_delivery_test.dart`: 25/25 geçti.
- Tam `flutter test --timeout=2m`: 908 geçti, 2 koşullu atlandı.
- Atlananlar: izole Android compile-time guard gerektiren test ve Windows'ta
  sentetik symlink oluşturulamayan test.
- `flutter analyze`: yeni uyarı yok; önceden var olan 4 info.
- `git diff --check`: başarılı.

Aşama 6 için tamamlanan kapsam: yeni, proven account drive'ın gerçek kontrollü finalization yolundan kalıcı owner-scoped outbox'a alınması; owner açılışında crash-gap reconciliation; açıkça enjekte edilen fake remote worker ile offline/retry/ACK/idempotency dikey dilimi. Gerçek senkronizasyon, otomatik uzak worker, tombstone replikasyonu ve A55 release kabulü tamamlanmış değildir.

## İstemci/fake kabul kapanışı

Client/fake sync kabulü TAMAMLANDI: ayrı iki owner-scoped store arasında
sentetik upload/download, kalıcı ACK/cursor, kontrollü flush kesintisinden
retry, duplicate önleme ve A/B izolasyonu doğrulandı.

Aşama 8 gerçek backend kabul listesinde zorunlu olarak kalan işler:

- Production worker ve Supabase sync henüz yok.
- Delete sync fail-closed; tombstone identity/time/version/provenance eksik.
- Server lease/heartbeat/fencing eksik.
- Server cursor/snapshot tutarlılığı henüz gerçek sunucuda kanıtlanmadı.
- Cross-device World/Career projection eksik.

Production ownership gate KAPALI. Aşama 5 fiziksel A55 release kabulü
bekliyor. Fake kabul gerçek sunucu veya fiziksel release kabulü sayılmaz.
