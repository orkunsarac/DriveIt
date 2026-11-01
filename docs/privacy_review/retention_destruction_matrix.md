# Saklama ve İmha Matrisi — Teknik ve Mevzuat Taslağı

> **[ONAY BEKLİYOR]** Süreler yalnız mevzuat kaynağında veya doğrulanmış sistem yapılandırmasında açıkça mevcutsa yazılmıştır. Uygulama için kesin retention süreleri uydurulmamıştır.

| Kayıt | Repository'de görülen saklama davranışı | Mevzuat/harici süre | Açık risk/karar |
|---|---|---|---|
| Cihaz SQLite GPS sessions/points | Uygulama veritabanı; kodda süre/TTL yok (`gps_session_store.dart`). | Bu ürün kaydı için doğrulanmış süre yok. | Kullanıcı silme davranışı, kullanıcı tarafından silme, backup dışlama, uygulama kaldırma sonrası sistem backup'ı — ONAY BEKLİYOR. |
| Hive sürüş/telemetri/skor/profil | Yerel box; repository'de genel TTL yok (`owner_scoped_local_store.dart`). | Belirli süre doğrulanmadı. | Cihazda hesap değişimi/hesap silme cleanup ve backup kapsamı doğrulanmalı. |
| Kişisel cloud drive/telemetry | Sync şeması ile owner kayıtları; saklama/TTL bu incelemede belirlenmedi. | Belirli süre doğrulanmadı. | Auth silme prod'a alınmadı; retry, backup, deletion tombstone süresi kararı açık. |
| Planet publish/raw source/derived road | Private source bucket ve DB; genel retention kanıtı yok. | Belirli süre doğrulanmadı. | Hesap silme ortak katkı ile kişisel rota ayrışımı/recompute. Genel Planet yazı kilidi ve yedeklerden silme kabulü gerekli. |
| Group Drive live location | Feature kapalı; olası açılış için uygulama/DB/Realtime log süreleri kanıtlanmadı. | Belirli süre doğrulanmadı. | Açılmadan önce retention, canlı kanal kapatma, log minimizasyonu kararı. |
| Supabase Auth/API/Postgres/Storage/Edge/Realtime logları | Servis logları vardır; repo exact retention/config göstermiyor. Supabase retention plan/servis bazlıdır. | Dış sağlayıcı sözleşmesi/ayarına bağlı. | Supabase dashboard/contract kanıtı, export/deletion ve veri konumu/alt işleyen. |
| DB backup | Free planda otomatik günlük DB backup yok; Storage objeleri DB backup kapsamı dışında. | Repo tarafından garanti edilen süre yok. | Harici backup sistemi ve restore testi yok. Backup içindeki silme nasıl uygulanır/expire olur — ONAY BEKLİYOR. |
| Destek e-postası | Kullanıcı Gmail'e talep gönderirse sağlayıcı posta kutusu ve operatör erişimi. | Google/Gmail hesap ve hizmet saklama koşulları. | Retention, yetkili operatör, MFA, vaka kaydı ve talep kapatma takvimi. Her e-posta için 3 yıl varsayılmamalı. |
| Silme işi / imha audit | Aday migration; completed job 24 saat sonra silme fonksiyonu (`202611010002_account_deletion_audit.sql:27-28`), geçici owner email (`202611010009...:3-12`). PROD'a uygulanmış değil. | KVKK Silme/Yok Etme/Anonim Hale Getirme Yönetmeliği m.7/3: imha işlemleri kayıtları diğer hukuki yükümlülük saklı kalmak üzere en az 3 yıl. | 24 saat receipt pruning bu audit amacıyla çelişebilir. Aday migration deploy edilmeden tasarım düzeltilmeli; audit minimal/pseudonymous tutulmalı. Üç yılın hangi records'a uygulandığı hukukça ONAY BEKLİYOR. |
| İlgili kişi başvurusu/yanıtı | Mevcut statik e-posta yolu için uygulama içi saklama sistemi yok. | KVKK Kurul duyurusu: başvuruya en kısa sürede ve en geç 30 gün içinde cevap. | Operasyon SLA'sı ve vaka materyalinin minimum saklama süresi hukukça belirlenmeli. |

## Mevzuat kaynakları

- [Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik](https://www.kvkk.gov.tr/Icerik/5441/KISISEL-VERILERIN-SILINMESI-YOK-EDILMESI-VEYA-ANONIM-HALE-GETIRILMESI-HAKKINDA-YONETMELIK): hukuki şartlar bittiğinde silme/yok etme/anonimleştirme; m.7 imha işlem kayıtları en az 3 yıl; m.11 periyodik imha üst sınırı 6 ay; periyodik imha yapmayan veri sorumlusu için yükümlülük doğumundan itibaren 3 ay. Uygulama ve güncel metin avukatça doğrulanmalı.
- [KVKK ilgili kişi başvurularına cevap usulü duyurusu](https://www.kvkk.gov.tr/Icerik/9024/ilgili-kisilerin-basvurularina-verilecek-cevabin-bildirim-usulune-iliskin-kamuoyu-duyurusu): en kısa sürede ve en geç 30 gün içinde cevap.
- [Aydınlatma yükümlülüğü](https://www.kvkk.gov.tr/Icerik/2033/Aydinlatma-Yukumlulugu-) ve [KVKK Kurul duyurusu](https://www.kvkk.gov.tr/Icerik/6765/AYDINLATMA-YUKUMLULUGUNUN-YERINE-GETIRILMESI-HAKKINDA-KAMUOYU-DUYURUSU).
- [Supabase backup documentation](https://supabase.com/docs/guides/platform/backups) and [log documentation](https://supabase.com/docs/guides/observability/logs); actual account config/retention in this task was not queried.
