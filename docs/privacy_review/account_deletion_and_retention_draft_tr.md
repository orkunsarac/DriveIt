# Hesap ve Veri Silme Politikası — Taslak

> **[ONAY BEKLİYOR — hukuki/operasyonel kabul ve üretim uygulaması yapılmadan kullanıcıya nihai vaat verilmemeli.]**

## Mevcut durum

- PROD signup kapalı; P-GR6A/B/C silme aday zinciri ve worker üretimde etkinleştirilmiş kabul edilmemelidir.
- P-GR6F operatör akışı yerel prototype/runbook ve Mailpit test tasarımıdır; kamuya açık web hizmeti değildir. `site/account-deletion` yayımlanmamıştır.
- Destek adresi `driveit.osaracx@gmail.com`; kullanıcı mail uygulamasıyla başvurabilir. E-posta gönderen adresi tek başına hesap sahipliği kanıtı sayılamaz.
- Yerel SQLite/Hive sürüş geçmişinin Auth hesabı silindiğinde cihazdan kaldırıldığı doğrulanmamıştır. Android backup kuralları yerel sürüş depolarını açıkça dışlamıyor.
- Planet ortak yollar için güvenli sahiplikten bağımsızlaştırma/recompute kanıtı yoksa silme `blocked_planet` kalmalıdır; tamamlandı denmemelidir.

## Başvuru akışı için şartlar

1. Benzersiz vaka numarası; talep için yalnız gerekli iletişim/işlem verisi.
2. Gönderici adresine güvenmek yerine mevcut doğrulanmış Auth adresine tek kullanımlık, hash'lenmiş, süreli challenge. Hesap varlığını yanıtla dışarı sızdırmama, rate limit ve replay koruması.
3. Açık teyitten sonra silme worker'ına idempotent iş oluşturma. Operatörün rolü, MFA, least privilege ve audit gereklidir.
4. Terminal `completed` ancak Auth kimliğinin, profil/kişisel bulut/Storage kaynaklarının ve ilgili Planet katkısının doğrulanmış terminal kanıtından sonra. `blocked_planet`, bekleyen ve başarısız işler tamamlandı sayılmaz.
5. Yerel cihaz verisi için kullanıcıya ayrı, cihaz-bağlamlı adımlar ve Android backup/transfer davranışı açıkça anlatılmalı; hesap silme ile cihaz içi silme aynı şeymiş gibi sunulmamalı.
6. Yedeklerde silme, backup expiration/restore replay ve log saklama kanıtı olmadan “kalıcı olarak hemen silinir” denmemeli.

## Veri kategorilerine göre önerilen silme kapsamı

| Kategori | Hedef işlem | Kanıt/koşul |
|---|---|---|
| Auth kimliği / e-posta | Kimlik doğrulanmış, açıkça onaylı talep sonunda silme | Auth admin terminal yanıtı; ilişkili audit'te gereksiz PII kalmadığı doğrulama |
| Profil | Auth FK cascade veya açık cleanup ile kaldırma | Gerçek cascade/trigger ve avatar nesnesi davranışı doğrulanmalı |
| Kişisel cloud sürüş/telemetri/outbox | Owner'a ait satır ve staging nesnelerini idempotent silme | tüm bucket/key prefix erişim ve retries; diğer owner verisine dokunmama |
| Planet raw route source | Kaynak objeyi kaldırma | Storage delete ACK; kaynak referansları ve tekrar deneme |
| Planet publish ve ortak road | Geri çekme + yeniden hesaplama veya `blocked_planet` | Geçerli diğer kaynaklar korundu; anonimleştirme hukuken/teknik olarak kanıtlı değilse kalıcı ortak katkı bırakma |
| Cihaz SQLite/Hive | Hesap silme backend'i tarafından otomatik silindiği iddia edilmez | cihazda açık yerel temizleme akışı ve backup/transfer dışlama kararı |
| Log/backup | Minimize, retention sonunda purge/expire | sağlayıcı ayarı, backup takvimi ve restore sonrası silme replay testi |
| Başvuru/audit kaydı | Kimlikten ayrıştırılmış minimum kanıt | KVKK imha işlem kaydı saklama yükümlülüğü ve minimum alanlar hukukça kararlaştırılmalı |

## Hukuki sürelerden ayrım

KVKK silme/yok etme/anonimleştirme yönetmeliğinde ilgili imha işlemlerinin kayıtlarının en az üç yıl saklanması hükmü vardır. Bu, otomatik olarak her e-posta gövdesinin, GPS verisinin veya hesabın 3 yıl tutulacağı anlamına gelmez. Başvuru cevabı en kısa sürede ve en geç 30 gün içinde verilmelidir. Periyodik imha, yükümlülük/periodic deletion policy kapsamına göre en fazla altı aylık aralık; periyodik imha yükümlülüğü olmayan durumda şartların kalkmasını izleyen üç ay hükmü hukuki inceleme gerektirir.

## Güvenli kullanıcı metni için geçici cümle

“Hesap silme talebi için driveit.osaracx@gmail.com adresine başvurabilirsiniz. Gönderen e-posta adresi tek başına hesabın size ait olduğunu doğrulamaz; doğrulama adımı gerekir. Ortak Planet katkıları güvenli biçimde ayrıştırılamıyorsa talep beklemede kalabilir. Cihazdaki yerel sürüş geçmişi ve cihaz yedekleri için ayrıca adımlar gerekebilir. Silme ve yedeklerden kaldırılma süresi hakkında kesin bilgi, teknik ve hukuki inceleme tamamlanana kadar verilemez.”
