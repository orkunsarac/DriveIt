# DriveIt — GPS Provenance End-to-End 5C.2G.2C.1

## Sonuç ve sınırlar

Sonuç: **KISMEN**. Kontrollü owner-scoped GPS yolu source identity'yi başlatma,
foreground doğrulaması/recovery ve SQLite→Hive transferinde aynı UUID v4 ile
koruyor; buna ek olarak World/Career için owner-scoped read-back sözleşmesi
eklendi. Normal üretim GPS başlangıcı ve ortak Hive kaydetme yolu bu kimliği
henüz üretmiyor/taşımıyor. Bu yolun açılması aktif Auth owner'ını üretim GPS
başlangıcında sabitlemeyi gerektirir; merkezi gate kapalıyken bunu yapmak,
eski davranışı ve sahiplik güvenliğini kanıtsız değiştireceğinden yapılmadı.

Üretim ownership gate kapalıdır. Gerçek kullanıcı verisi, eski Hive sürüşleri,
World/Career kayıtları, GPS journal v3, Supabase ve cihaz uygulaması üzerinde
işlem yapılmadı. World/Career merge, görünür aggregate veya trace/tombstone
remap yapılmadı.

## Kaynak çağrı zinciri

### Normal üretim yolu (provenance henüz yok)

`MapScreen` sürüş başlatma → `ForegroundService.start()` → `openGpsJournal()` /
`GpsSessionStore.create()` → `DriveTaskHandler.onStart()` aktif journal
session'ını açar → `GpsRecordingWriter` noktaları journal'a yazar → recovery,
stop ve replay aynı session ID'yi kullanır → `DriveSummaryDialog` `sessionId`
ve acquisition metadata ile `DriveStorageService.saveDrive()` çağırır →
`GpsSessionTransfer` + ortak `GpsHiveTransferSink` → Hive/score/World/Career
mevcut akışları.

Bu akış source ownership sidecar'ını açmıyor. Ortak `DriveSession` Hive
adapter'ına provenance alanı eklenmedi; ortak sink `ProvenanceGpsTransferSink`
değil. Bu yüzden normal üretim sürüşü için proven UUID iddiası yapılamaz.

### Kontrollü owner-scoped yol

Yalnız açıkça bağlanan test bridge'i `LocalOwnerGpsBridge.start()` owner lease'i
altında çalışır. `OwnedGpsSessionCoordinator` source UUID v4 ve ayrı planned
session UUID'si üretir; owner + identity sidecar'a kalıcı yazıldıktan sonra
journal tam planned session ID ile oluşturulur ve bind edilir. Journal oluşumu
ile bind arasındaki kapanmada `recoverBinding` yalnız aynı journal'da aynı
planned ID kanıtlanırsa bind'i tamamlar. `ownedStartCallback` Auth okumaz;
descriptor ile aynı journal/sidecar'ı açıp sidecar binding'ini doğrular.

Save, sidecar'daki sabit owner hedefine yönelir. Scoped sink drive manifest,
telemetry metadata ve ayrı `drive_source_provenance_v1` kaydını yazar; flush ve
read-back iki kimlik kanıtının da eşleşmesini gerektirir. Journal transfer
receipt'i, sidecar receipt'i ve hedef Hive kanıtı olmadan cleanup yapılmaz.

## Kimlik ve read-back sözleşmesi

- `sourceIdentity`: sidecar rezervasyonunda bir kez üretilmiş UUID v4; `drive.id`
  ve session ID alanlarından bağımsızdır.
- `sessionId`: journal'ın recovery/idempotency anahtarıdır; service recreation,
  Activity recreation, devam/recovery ve save sırasında değiştirilmez.
- `drive.id`: mevcut Hive/local record anahtarıdır; source identity ile aynı
  olmak zorunda değildir.
- `ownerScope`: kimlikten ayrı, sidecar'da sabitlenen yerel hedeftir.
- Eski/eksik kanıt `unproven`, bozuk veya çelişkili kanıt `conflict` sayılır.
  Hiçbir eski ID'den UUID türetilmez.

Yeni `DriveSourceProvenanceReader` / `OwnerScopedDriveSourceProvenanceRepository`,
World ve Career için read boundary sağlar. `proven` sonucu ancak owner-scoped
ayrılmış provenance kaydı ile telemetry acquisition metadata'sı aynı UUID,
namespace, sürüm ve owner scope'u doğrularsa döner. İki kayıttan biri eksikse
veya çelişirse fail-closed `conflict`; eski telemetry provenance anahtarı
taşımıyorsa `unproven` döner. Bu repository World/Career yazımını veya görünür
istatistikleri değiştirmez.

## Testler ve kapsam sınırı

Bu görevde eklenen testler, başarılı kontrollü transferde sidecar UUID'sinin
session ID'den ayrı kaldığını, Hive provenance kaydı ile telemetry metadata'sı
üzerinden read-back edildiğini; provenance'sız eski telemetry'nin `unproven`,
tek taraflı evidence'ın `conflict` olduğunu doğrular. Mevcut GPS ownership ve
transfer testleri planned-session recovery, Auth değişiminde sabit owner,
transfer retry, read-back ve receipt/cleanup bariyerlerini kapsar.

`test/gps_session_ownership_test.dart`,
`test/scoped_gps_transfer_test.dart` ve
`test/drive_source_provenance_test.dart` hedefli çalıştırmasında ilk denemede
yeni repository için eksik model importu derleme hatası verdi; import düzeltildi
ve ikinci hedefli koşu geçti. İkinci koşudaki toplam: **37 test geçti**.

Bu testler kontrollü fixture/FFI testidir. Gerçek Android process kill, A55,
native foreground isolate üzerinde yeni provenance akışı veya gerçek Auth
değişimi kanıtı değildir. Mevcut gerçek foreground task davranışı bu işte
değiştirilmemiştir.

## Açık GPS yolları ve sonraki API bağlantıları

Eksik kalanlar:

1. Normal `ForegroundService.start()` için kalıcı owner capture + source UUID
   rezervasyonunu güvenle kuran üretim bootstrap entegrasyonu.
2. Normal foreground callback/isolate'ın sidecar descriptor ile session
   provenance'ını doğrulaması.
3. Ortak `GpsHiveTransferSink` için proven identity write/read-back; bunun
   güvenli hedef owner'ı belirlenmeden kullanıma alınmaması.
4. Normal `DriveStorageService` kaydetme/reconciliation akışının identity
   conflict'ini fail-closed ele alması.
5. Activity/service restart, stop/continue, process recovery ve save için
   gerçek Android integration testleri.
6. World snapshot/trace/job/tombstone ve Career contribution referans closure'ı.

Yeni World/Career kodu için tüketim arayüzü:
`DriveSourceProvenanceReader.readForDrive(driveId)`; proven olmayan veya conflict
dönen kayıtlar domain merge'e kabul edilmemelidir. Ayrılmış kayıt telemetry
ile birlikte ancak scoped transfer doğrulamasından sonra okunabilir.

## Son doğrulama

Branch: `feature/gps-refactor`; başlangıç HEAD:
`f68445cb7038e50b95f0da139fc7b7b307267105`. Önceki Aşama 5 working tree
değişiklikleri korundu; `tatus` dosyasına dokunulmadı. Hedefli GPS
ownership/transfer/provenance koşusu **37/37** geçti. Tam
`flutter test --no-pub --timeout=2m`: **840 geçti, 2 koşullu atlandı, 0
başarısız**. `flutter analyze --no-pub`: yalnızca repodaki **4 mevcut info**
(yeni warning/error yok). `git diff --check` başarılı; Git ayrıca mevcut
LF→CRLF çalışma kopyası ve fsmonitor IPC uyarıları verdi. Üretim gate kapalı
kaldı.
