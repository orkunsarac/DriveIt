# P-GR6A hesap silme — uygulama öncesi politika bağımlılığı

Bu belge tasarım ve bağımlılık kaydıdır. Yerel uygulama adayı geliştirilmiştir; gerçek kabul durumu `account_deletion_pgr6a_acceptance.md` dosyasındadır. PROD/DEV'e yazma yapılmadı. Hukuki Planet retention politikası kesinleşmiş ilan edilmedi.

## Kanıtlanmış bağımlılıklar

- `supabase/prod/bootstrap/202609220001_canonical_planet_base.sql:245`: profil Auth kullanıcısına ON DELETE CASCADE bağlı.
- Aynı dosya `:248`, `:251`, `:254`, `:257`: Planet publish, validated road ve road section zincirinde cascade bulunuyor. Dolayısıyla doğrudan Auth delete, Planet saklama kararından bağımsız bir işlem değildir.
- `supabase/phase8-dev/supabase/migrations/202610120001_phase8_drive_sync.sql`: upload intent, owner sequence, manifest, changes ve snapshots Auth owner'a RESTRICT ile bağlı. Manifest/change immutable trigger'ları fiziksel silmeyi ayrıca reddeder.
- `supabase/phase8-dev/supabase/migrations/202610160001_phase8_m2_deletion_fencing.sql`: lease/tombstone ve diğer deletion-fencing kanıtları aynı owner yaşam döngüsüne bağlıdır; tek sürüş tombstone işlemi hesap silme değildir.
- `supabase/phase8-dev/supabase/migrations/202610160004_phase8_m4_group_drive.sql:7,21,22`: grup yöneticisi ve üyelikler RESTRICT bağımlılıkları taşır. Yönetici hesabı silinirken diğer üyelerin erişimi ve açık grant/generation güvenliği ele alınmalıdır.
- İki private Storage bucket'ı ayrı servistedir. Auth delete başarılı olsa bile Storage temizliği tamamlandı sayılamaz.
- `lib/services/supabase_local_owner_auth.dart`: SDK Auth değişimlerini owner lifecycle'a iletir. `lib/services/local_owner_lifecycle.dart:1782` kapatma akışı store'u kapatır; hesap silme entegrasyonu yerel History/store silme çağrısı yapmamalıdır.
- `docs/prod_setup_preparation.md:102` ve `docs/prod_predeployment_pgr4a.md:21`: Planet saklama politikası hukuki karar bekliyor; bu aşamada otomatik silme veya anonimleştirme kararı çıkarılamaz.

## Güvenli uygulama sözleşmesi

1. Sahipliği sunucunun doğruladığı JWT'den türet; istemci ownerId kabul etme. Hassas işlem için güncel yeniden doğrulama ve açık kullanıcı onayı gerekir; JWT refresh tek başına yeniden kimlik doğrulama sayılmamalıdır.
2. Planet ortak bağımlılık kontrolünü purge öncesinde tamamla. Kullanıcının aşağıdaki kararı kapsamında tek sahipli kaynakları sil; bağımsızlığı kanıtlanamayan ortak katkıda blocked_planet kullan, anonimleştirme veya tamamlanma varsayma.
3. Kalıcı idempotent silme işi ve owner fence oluştur. Mevcut ve yeni sync, Storage upload ve grup grant işlemleri silme sırasında yeni içerik üretememeli; yarışlar ilgili owner kilidiyle çözümlenmeli.
4. Storage temizliği doğrulanmadan Auth hesabını silme. Kısmi hata işi bekletmeli; başarılı gibi yanıtlanmamalı. Retry aynı hesabın kendi işi üzerinde ilerlemeli.
5. Grup sonlandırma/üyelik-grant iptali diğer üyelerin yerel sürüşlerini veya kişisel bulutlarını silmemeli.
6. Kişisel bulut satırlarını FK ve immutable kurallarına uygun, yalnız dar sunucu yetkili orkestrasyonla temizle. İstemciye immutable bypass veya service key verme.
7. Auth delete son adım olmalı; eski token, refresh session ve geciken yanıt davranışları gerçek izole servislerle test edilmeli. Hesap ortadan kalkınca istemci geçerli owner epoch'uyla çıkışa geçmeli; eski owner'ın yanıtı yeni hesaba uygulanmamalı.
8. Yerel History, GPS recovery, guest ve cihaz arşivi korunmalı. Aktif sürüşte işlem başlatılmamalı; kullanıcı yerel kayıtların korunma/erişim davranışını açıkça görmelidir.

## Gerekli ürün kararı

Kullanıcı mühendislik sınırını netleştirdi: Planet hesabının talebi kabul edilir; yayın/konum erişimi kapatılır; kaynak ve kimlik bağlantıları silme kapsamındadır; başka kişilerin verileri korunur. Doğrulanmış anonimleştirme varsayılmaz. Ortak bağımlılık belirsizse tamamlandı gösterilmez ve yayın fail-closed kalır. Bu karar hukuki saklama politikasının tamamlandığı anlamına gelmez.

## Gerekli kabul senaryoları

A/B yetki izolasyonu; eksik/geçersiz/eski oturum; yeniden doğrulama; profile-only hesap; kişisel cloud/Storage dolu hesap; yarım Storage hatası ve idempotent retry; aynı anda upload/finalize/download; grup üyesi/yönetici; Planet politika engeli; iş tamamlanmadan Auth silinmemesi; eski JWT/refresh; hesap değişimi; yerel sürüş/GPS recovery regresyonu. Çalıştırılan testlerin sayıları ve kalan kontroller kabul kaydında ayrı belirtilir.
