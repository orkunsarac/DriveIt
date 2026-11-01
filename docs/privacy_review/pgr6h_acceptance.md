# P-GR6H teknik kabul kaydı

Tarih: 2026-11-01
Kapsam: Android yedekleme kuralları, onboarding/konum açıklaması ve hesap silme imha audit'i. Bu kayıt hukuki onay veya PROD kabulü değildir.

## Sonuç

P-GR6H kapsamındaki üç değişiklik yerel/izole testlerle doğrulandı. PROD/DEV ayarı, migration veya veri değiştirilmedi; yeni migration yalnız `pgr6a-749a37ae1b` disposable yerel Supabase ortamına uygulandı. Site, signup, worker ve Group Drive etkinleştirilmedi.

## Android yedekleme

- `android:allowBackup="false"` açıkça ayarlandı; Android 11 ve öncesi legacy kuralları ile Android 12+ cloud-backup ve device-transfer kuralları tüm app-private veri alanlarını dışlıyor.
- Kaynak XML ve Gradle birleştirilmiş manifest kontrolü PASS (21 politika kontrolü; `:app:processDebugMainManifest` başarılı).
- Yerel SQLite/Hive verisi mevcut cihazdan silinmez. Yeni cihazda Android yedekleme/cihaz aktarımıyla otomatik geri yüklenmez. Önceki sağlayıcı yedeklerinin geriye dönük silindiği iddia edilmez.
- Debug APK derlemesi başarılı; gerçek cihaza yükleme yapılmadı. Android 11 ve 12+ cihaz aktarım kabulü bekliyor.

## Onboarding ve konum

- Onboarding katalogundaki KVKK, gizlilik, koşullar ve açık rıza belgeleri `pending_legal_review`; sürüm/onay referansı/onay zamanı ve gerçek metin olmadan kabul edilemez. Katalog yükleme hatası da akışı kapalı tutar.
- Konum izninden önce ayrı ve belirgin açıklama gösteriliyor. Kullanıcı vazgeçerse runtime izni istenmiyor ve onboarding ilerlemiyor. Android Geolocator coarse+fine isteğini birlikte yapar; Android 12+ approximate/precise seçimini sistem sunar. Bu onboarding adımı background izni istemez.
- İlgili Flutter onboarding ve yerel GPS/Hive testleri: 56/56 PASS.
- `flutter analyze` 7 mevcut baseline bulgusuyla exit 1 verdi (3 warning, 4 info); P-GR6H değişikliklerinde yeni bulgu yok.

## Silme audit'i

- `202611010025_account_deletion_retention_audit.sql` ileriye dönük yerel aday migration'ıdır. Kısa ömürlü operasyonel receipt/job kayıtlarından bağımsız, append-only ve asgari audit tablosu kurar.
- Audit yalnız kaynak event kimliği, opak operasyon UUID'si, durum ve zamanları taşır; e-posta, Auth UID, rota/GPS, token veya receipt hash alanı yoktur. Opak operation UUID yine pseudonymous kabul edilip hukuki incelemede değerlendirilmelidir.
- Job cascade/prune audit tablosunu silmez. Event tekrarı idempotenttir; UPDATE/DELETE reddedilir; client rollerine erişim verilmez. SQL kabul testi rollback içinde PASS; 14 hesap silme entegrasyon testi PASS.
- 1096 gün teknik alt sınır adayıdır; KVKK'nın belirli imha kayıtlarına uygulanabilirliği, saklama başlangıcı ve yasal saklama bittikten sonraki imha yöntemi **ONAY BEKLİYOR**. Migration PROD'a uygulanmamıştır. Önceki 24 saatlik temizliğin zaten sildiği audit olayları geri getirilemez.

## Diğer kontroller ve kalan risk

- P-GR6G belge tutarlılık denetimi PASS (7 belge, 18 kaynak dayanağı, 3 kaynak URL).
- `git diff --check` PASS.
- Daha geniş 27 testlik P-GR6A/P-GR6C paketi iki tam çalıştırmada 26/27 verdi; başarısızlıklar değişken biçimde eski 33-survivor worker concurrency testi veya aynı paketteki başka sıra-bağımlı worker assertion'ı oldu. İki bildirilen senaryo tek başına yeniden çalıştırıldığında geçti; bu dalgalanma tam paket PASS olarak sunulmamaktadır. P-GR6H audit ve hesap silme adlandırılmış testleri PASS.
- Bilinen ürün/hukuk kararları açık: Planet ortak geometrisi ve yedeklerinden silme, geniş authenticated profil okuması, üçüncü taraf aktarım kapsamı, saklama süreleri ve belge metinlerinin onayı.
- Gerçek Android 11/12+ cihaz kabulü, Play Console background-location declaration/video incelemesi, hukuk onayı ve Auth SMTP kurulumu beta öncesi tamamlanmalı.

## Kaynaklar

- Android Auto Backup ve extraction kuralları: https://developer.android.com/identity/data/autobackup
- Android 11 arka plan konum izni: https://developer.android.com/about/versions/11/privacy/location
- Android 12 konum runtime izinleri: https://developer.android.com/develop/sensors-and-location/location/permissions/runtime
- Google Play background location: https://support.google.com/googleplay/android-developer/answer/9799150
- KVKK silme/yok etme/imha yönetmeliği: https://www.kvkk.gov.tr/Icerik/5441/KISISEL-VERILERIN-SILINMESI-YOK-EDILMESI-VEYA-ANONIM-HALE-GETIRILMESI-HAKKINDA-YONETMELIK
