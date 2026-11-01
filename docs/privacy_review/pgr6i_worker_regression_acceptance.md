# P-GR6I worker regresyon kabulü

Tarih: 2026-11-01
Dal: `feature/gps-refactor`
Test hedefi: yalnız loopback API ve `pgr6a-749a37ae1b` izole yerel Supabase stack'i.

## Kök neden

Worker lease/SQL hatası tekrarlanan testlerde kanıtlanmadı. `account_deletion_worker_claim` tek satırı `FOR UPDATE SKIP LOCKED` ile seçiyor ve transaction içinde 120 saniyelik lease atıyor. Edge worker her sınırlı batch sonundaki `finally` bloğunda lease'i bırakıyor. Bu nedenle iki HTTP çağrısı aynı anda başlasa bile, ikinci çağrı ilk batch tamamlanıp lease bırakıldıktan sonra aynı job'ı sırayla alabilir.

33-survivor testi bu meşru sıralı sonucu yanlışlıkla başarısız sayıyordu: iki HTTP yanıtının mutlaka bir `pending` ve bir `idle` olması ve yalnız bir batch'in ilerlemesi beklenmişti. Yanıt düzeni, Edge iş süresine ve yerel servis zamanlamasına bağlıydı. Önceki bir tam koşuda A/B testinin ilk onay çağrısı da beklenmeyen HTTP sonucu verdi; o eski assertion yalnızca “A consent” yazdığı için HTTP durum/hata kodu kanıtı yok ve o tekil olayın kesin kök nedeni belirlenemedi. A/B testi ayrı koşuda ve düzeltilmiş üç tam paketin tamamında geçti; bu nedenle ona doğrulanmamış bir worker kusuru atfetmiyorum.

Bu, veri kaybı ya da aynı job'ın aynı lease'i iki worker'a verilmesi kanıtı değildir. PostgreSQL claim işlemi atomik ve lease kontrollüdür; replay checkpoint kaydı sürüm/fingerprint/CAS kontrollerinden geçer.

## Düzeltme

Yalnız `supabase/prod/tests/account_deletion_test.ts` içindeki 33-survivor testini değiştirdim. HTTP yanıt sırasına dayalı assertion yerine aynı DB claim RPC'sine 24 tur eşzamanlı çift istek uygulanıyor. Her turda:

- İki çağrıdan tam biri işi ve lease'i alıyor, diğeri `idle` dönüyor.
- Veritabanındaki lease'in tek kazananla eşleştiği doğrulanıyor.
- Kazanan lease kontrollü biçimde bırakılıyor.

Sonra tek Edge batch'i, checkpoint, geçersiz lease reddi, input değişiminde checkpoint invalidation, kayıp yanıt ve crash/restart sonrasında tam replay testleri aynı şekilde çalışıyor. Test atlanmadı; güvenlik assertion'ı gevşetilmedi. SQL ve Edge worker üretim/test dışı uygulama kodları değiştirilmedi. `tool/run_pgr6a.ps1` doğru pinned stack ve final cleanup kontrolleri için kullanıldı; değiştirilmedi.

## Sonuçlar

- Hedefli 33-survivor stres/crash/restart testi: **1/1 PASS**, exit code 0; 24 eşzamanlı claim çifti.
- Hedefli concurrent A/B requests testi: **1/1 PASS**, exit code 0.
- Tam servis paketi: **3 ardışık koşu; her biri 27/27 PASS, exit code 0**. Toplam 81 test sonucu PASS.
- Ayrı `deno check` çağrısı npm registry DNS erişimi olmadığı için bağımlılık indiremeyip çalışmadı; aynı test dosyası üç tam `deno test` koşusunda derlenip çalıştı ve test exit code'ları 0 oldu.
- Her koşuda B/C sürüşleri ve katkıları korundu; retry, rollback, lost ACK, lease expiry ve fail-closed Planet testleri koştu.
- Her koşunun son sentetik temizliği PASS: Auth users, profiles, jobs, operational events, replays, publishes, validated roads, active traces ve Storage objects sayıları sıfır; Group Drive gate `false`; signup `disable_signup=true` doğrulandı.
- P-GR6H Android backup/onboarding/audit koduna dokunulmadı. P-GR6H Flutter 56 testi, Android backup manifest check/build ve analyze baseline sonuçları önceki kabul kaydındaki gibi.

İmha audit tablosundaki append-only sentetik event kanıtları receipt/job verisiyle birlikte silinmez; bunlar yalnız yerel test stack'indedir ve test kimliği/rota/GPS/e-posta/token taşımaz. Audit değişmezliği gereği temizlenmeye çalışılmadı. Bu yerel, pseudonymous audit satırları test operasyonunun kasıtlı ve kalıcı çıktısıdır.

## Güvenlik sınırları

Hiçbir PROD/DEV veritabanı, kullanıcı, worker, cron, signup veya Group Drive ayarı değiştirilmedi. Docker volume silinmedi veya reset edilmedi. Test sonu gate kapalı ve signup kapalı doğrulandı. Audit retention migration'ı PROD'a uygulanmadı; üç yıllık teknik saklama adayı ile hukuki uygulanabilirlik ayrıca hukuk onayı bekliyor.
