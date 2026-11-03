# P-GR7H — Play R1 veri envanteri ve hukuki taslaklar

**TASLAK — HUKUKİ ONAY BEKLİYOR.** Bu metin kullanıcıya yayımlanacak nihai belge veya Play Console beyanı değildir. Köşeli parantezli alanlar doğrulanmadan doldurulmaz. Bu incelemede hosted PROD/DEV ayarları veya verileri okunmadı ya da değiştirilmedi. Son yerel Play build'inde Supabase URL/key ve hesap sync, deletion, Group Drive etkinleştirmeleri release guard ile reddedilir (`android/app/build.gradle.kts:60`, `tool/build_play_aab.ps1:52`). Bu yerel dosyalar daha önceki R1 çalışma ağacı değişiklikleridir. Hukuki onboarding şu anda `pending_legal_review` nedeniyle geçilemez (`assets/legal/legal_documents.json:7`, `lib/features/onboarding/screens/legal_safety_onboarding_page.dart:73`). Aşağıdaki Play R1 değerlendirmesi bu build koşullarına ilişkindir; mağazaya gönderilecek nihai artefakt ayrıca doğrulanmalıdır.

## 1. Teknik envanter

| Veri / erişim | Yer ve amaç | Play R1 / ileride | Silme, alıcı ve bilinmeyenler |
| --- | --- | --- | --- |
| Konum, zaman, hız, yön/irtifa/doğruluk ve GPS rotası | Yerel GPS SQLite journal ve sürüş/recovery (`lib/services/gps_session_store.dart:80`); aktif sürüşte foreground service; Android foreground/background konum izinleri (`android/app/src/main/AndroidManifest.xml:4`). | R1'de kayıt altyapısı vardır; gerçek cihazdaki izin/onboarding engeli yüzünden tüm akış kabul edilmedi. Arka plan konumu uygulama için hassas ve Play beyanına tabidir. | Cihaz verisi hesap silme ile otomatik silindiği doğrulanmadı. Harita/eşleme etkinse Google Maps/Mapbox aktarımı olabilir; çağrı koşulları ve sağlayıcı logları ayrıca doğrulanmalı. |
| Sürüş geçmişi, rota, telemetri, Drive Score ve istatistikler | Hive ve yerel depolar (`lib/main.dart:291`, `lib/services/drive_score_storage_service.dart`, `lib/services/drive_telemetry_storage_service.dart`); geçmiş, Replay ve puan üretimi. | Yerel altyapı mevcut; yeni Play applicationId eski DEV sandbox'ını devralmaz. Gerçek Play ilk açılışında geçmiş ekranı hukuki engel nedeniyle test edilmedi. | Android backup `allowBackup=false`; legacy ve Android 12+ kurallarında hassas alanlar dışlanır. Önceki yedeklerin silindiği kanıtlanmadı. Cihaz değişiminde yerel kayıtlar otomatik taşınmayabilir. |
| Hesap, e-posta, kullanıcı adı, görünen ad, avatar, Auth UID ve oturum | Supabase Auth ve `public.profiles` (`supabase/prod/bootstrap/202609220001_canonical_planet_base.sql`); yerel profil (`lib/services/profile_storage_service.dart`). | R1 bulut yapılandırmasız; hesap özelliği çalışıyor diye tanıtılmaz. İleride Auth/SMTP ve callback ayrı kabul gerektirir. | Auth/log/backup silme ve sağlayıcı retention süreleri doğrulanmadı. Mevcut şemada authenticated kullanıcıların profil satırlarını okuyabilmesi ayrıca gizlilik kararı gerektirir; bkz. `docs/privacy_review/pgr6g_data_inventory.md`. |
| Kişisel bulut ve Planet | Owner Sync tabloları, private Storage ve Edge Functions; Planet yayın/rota kaynakları (`supabase/prod/preparation_manifest.json`, `supabase/functions`). | R1'de etkin değil. Kişisel bulut ile kullanıcı onaylı herkese açık Planet yayını ayrı işlemlerdir. | Üretim silme zinciri ve ortak yol katkılarının güvenli yeniden hesaplanması ayrı kabul gerektirir. `blocked_planet` belirsizlikte tamamlandı denmesini engeller; ortak katkı saklama politikası ONAY BEKLİYOR. |
| Group Drive ve canlı konum | Grup üyeliği/izinleri, Realtime ve publish; `supabase/phase8-dev/supabase/migrations/202610310001_phase8_m4_server_gate.sql`. | R1 istemci gate kapalı; sunucu gate varsayılan FALSE. Hosted son değer bu görevde doğrulanmadı. | Üye alıcıları, retention ve kapatma sonrası etkin bağlantıların davranışı ayrıca kabul edilmelidir. |
| Hesap/veri silme ve destek başvurusu | Yerel aday worker/operatör ve e-posta kanalı; `docs/privacy_review/account_deletion_and_retention_draft_tr.md`, `site/account-deletion/index.html`. | PROD worker etkin değil; web sayfasının yayımlandığı doğrulanmadı. | Gönderen e-postası sahiplik kanıtı değildir; doğrulama ve güvenilir terminal sonuç gerekir. Yerel cihaz, bulut, Storage, Planet, log ve yedek kapsamları ayrı doğrulanmalıdır. |
| Log, hata, denetim ve yedek | Yerel tanılama, Supabase/SDK operasyon logları, olası yedekler; `docs/privacy_review/retention_destruction_matrix.md`. | Gerçek PROD log alanları ve süreleri bu incelemede doğrulanmadı. | İmha işlemleri kayıtları için yönetmelik m.7/3 en az üç yıl öngörür; kayıt alanları ve diğer veri süreleri ONAY BEKLİYOR. Yedeklerde silme/restore replay kanıtlanmadı. |
| Üçüncü taraf SDK/hizmetler | Google Maps SDK, Mapbox eşleme (`lib/features/my_world/providers/mapbox/mapbox_road_matching_provider.dart:35`), Supabase ve Gmail/SMTP koşullu hizmetleri. | Google Maps yerel harita ekranlarında kullanılır; Mapbox yalnız ilgili istek yapılandırma/akışında. Auth SMTP/Planet kullanıcı özelliği R1'de aktif kabul edilmez. | Tam SDK veri alanları, alıcı/alt işleyenler, işleme ülkeleri, aktarım hukuki mekanizması ve sağlayıcı süreleri ONAY BEKLİYOR. |

## 2. KVKK aydınlatma metni — taslak

**Veri sorumlusu:** [kimlik/unvan ve adres — ONAY BEKLİYOR]. **İletişim:** [yetkili başvuru yöntemi — SEÇİLMEDİ; kullanılabilir destek kanalı yok]. DriveIt, sizin başlattığınız sürüşlerde konum, rota, zaman, hız ve sürüşe ilişkin teknik ölçümleri; tercih ettiğiniz profil bilgilerini ve kullanım için gerekli cihaz kayıtlarını işleyebilir. Bunlar sürüşü kaydetme, rota ve istatistikleri gösterme, kayıt kurtarma ve güvenlik amaçlarıyla kullanılır. [Her amaç için uygulanabilir hukuki sebep — ONAY BEKLİYOR.] [Alıcılar, yurt dışı aktarım şartları ve yöntemleri — ONAY BEKLİYOR.] [Saklama ve imha süreleri — ONAY BEKLİYOR.] Kanun kapsamındaki haklarınızı [doğrulanmış başvuru kanalı] üzerinden kullanabilirsiniz. Talebin yanıt süresi ve istisnalar hukuk incelemesiyle doğrulanacaktır.

## 3. Gizlilik politikası — taslak

DriveIt, aktif sürüşü kaydetmek için konuma erişebilir; rota ve sürüş bilgileri cihazınızda saklanabilir. Ekran kapalıyken veya uygulama arka plandayken, siz sürüşü bitirene ya da Android hizmeti durdurana kadar kayıt devam edebilir. Harita görüntüleme ve sizin istediğiniz yol eşleme işlemlerinde sağlayıcılara teknik veriler ve ilgili koordinatlar iletilebilir. [Sağlayıcılar, aktarım kapsamı ve ülkeleri — ONAY BEKLİYOR.] Hesap, kişisel bulut, Planet ve Group Drive için kullanılacak veriler, ilgili özellikler etkinleştirilip ayrıca kabul edildiklerinde nihai metne eklenecektir; R1'de bu özelliklerin kullanılabilir olduğu varsayılmaz. Cihaz yedekleme dışlaması nedeniyle yerel geçmiş yeni cihaza kendiliğinden dönmeyebilir. [Veri sorumlusu, saklama, kullanıcı hakları ve başvuru yolu — ONAY BEKLİYOR.]

## 4. Kullanım koşulları — taslak

DriveIt sürüş bilgilerini yaklaşık ölçümlerle sunar. Kullanıcı trafik kurallarına uymalı ve sürüş sırasında cihazı güvenli olmayan şekilde kullanmamalıdır. GPS, cihaz, bağlantı veya sistem kısıtları nedeniyle kayıt kesilebilir veya ölçüm hatalı olabilir. [Hizmet sağlayan kişi/şirket, yaş koşulları, sorumluluk, içerik kuralları, fikrî haklar, değişiklik ve uyuşmazlık hükümleri — ONAY BEKLİYOR.] Planet ve grup özelliklerine ilişkin kurallar bunlar gerçekten etkinleştirilmeden nihai metne eklenmez.

## 5. Olası ayrı açık rızalar — taslak

Hangi işlemin açık rıza gerektirdiği, her işlem için bağımsız hukuki sebep ve reddin sonuçları **ONAY BEKLİYOR**. Konum izni veya hizmet kullanımı tek başına KVKK açık rızası olarak sunulmaz. Hukuken gerekli olduğu belirlenirse [işlem/amaç/alıcı/aktarım/geri alma yöntemi] için ayrı, özgür ve geri alınabilir seçim hazırlanacaktır. Planet'e herkese açık yayın için ürün gereği ayrı kullanıcı onayı korunur; bu onay otomatik olarak hukuki açık rızanın yerine geçtiği varsayılmaz.

## 6. Arka plan konumu açıklaması — taslak

“DriveIt, yalnız sizin başlattığınız aktif sürüş sırasında konumunuzu kullanarak rotayı, mesafeyi ve hızı kaydeder. Sürüşü bitirene veya Android kayıt hizmetini durdurana kadar ekran kapalıyken ya da uygulama arka plandayken kayıt sürebilir. İzni reddedebilir ve daha sonra cihaz ayarlarından değiştirebilirsiniz. [Veri alıcıları ve gerçekten etkin paylaşım — ONAY BEKLİYOR.]” Gerçek izin sırası ve foreground service davranışı, [mevcut açıklama](../../lib/features/onboarding/screens/permissions_onboarding_page.dart) ve fiziksel cihaz testleriyle karşılaştırılmalıdır; Google Play'in belirgin açıklama ve arka plan konumu şartları ayrıca uygulanır.

## 7. Hesap ve veri silme — taslak

Hesap özelliği gerçekten sunulursa kullanıcı [uygulama içi yol] veya [yayınlanmış web başvuru yolu] üzerinden silme talebi iletebilmelidir. Doğrulanmış destek kanalı henüz seçilmedi ve mevcut Gmail hesabı devre dışıdır. Kimlik doğrulama ve operatör süreci üretim kabulü almamıştır. Hesap sahibinin doğrulanması sonrasında [Auth, profil, kişisel bulut, Storage kaynakları, Planet ve yerel cihaz verisi için ayrı silme davranışları — ONAY/TEKNİK KABUL BEKLİYOR] uygulanır. `blocked_planet` veya başarısız işlem tamamlandı diye bildirilmez. [Yedeklerden silme takvimi ve varsa zorunlu saklama istisnaları — ONAY BEKLİYOR.] Yerel sürüşler hesap silmeyle otomatik silinir diye söz verilmez.

## 8. Google Play Data Safety — ön envanter

Bu tablo nihai beyan değildir; mağazaya yüklenen artefakt, SDK ağ trafiği ve sağlayıcı veri kullanımı doğrulanmadan “toplanmıyor/paylaşılmıyor” seçilmez. Google Play kapsamındaki toplama ve paylaşma tanımları yerel cihazda kalan verilerden farklıdır.

| Kategori | R1 yerel / olası ağ akışı | Beyan kararı |
| --- | --- | --- |
| Kesin konum | GPS/rota yerelde; harita veya Mapbox eşlemede koordinatların sağlayıcıya aktarımı olası | SDK ve çağrı trafiği, amaç, zorunlu/seçimli ve sağlayıcı paylaşımı **DOĞRULANACAK**. |
| Ad, e-posta, kullanıcı kimliği | Yerel profil olabilir; hesap bulutu R1'de guard arkasında | Nihai build ve SDK akışları **DOĞRULANACAK**; gelecekteki Auth ayrı beyan değişikliği gerektirir. |
| Kullanıcı tarafından üretilen içerik / sürüşler | Yerel rota, puan, görsel ve geçmiş; Planet/personal cloud R1'de kapalı | Gerçek network erişimi ve Play kategori eşlemesi **DOĞRULANACAK**. |
| Uygulama etkinliği, tanılama ve cihaz tanımlayıcıları | SDK/işletim sistemi ve sağlayıcı logları mümkün | SDK sürüm bazlı tedarikçi belgeleri ve trafik **DOĞRULANACAK**; yok varsayılmaz. |
| Aktarım şifreleme, veri silme ve hesap silme | HTTPS kullanılan yollar kodda var; tüm SDK/operasyon yolları ve PROD silme kabulü eksik | Her Play sorusu için ayrı kanıt ve yayınlanmış erişilebilir silme URL'si **BEKLİYOR**. |

## 9. Kaynaklar ve kararlar

- [KVKK imha yönetmeliği](https://www.kvkk.gov.tr/Icerik/5441/KISISEL-VERILERIN-SILINMESI-YOK-EDILMESI-VEYA-ANONIM-HALE-GETIRILMESI-HAKKINDA-YONETMELIK): imha işlemlerinin kaydı için en az üç yıl; talep ve diğer süreler somut duruma göre hukukçu tarafından değerlendirilecek.
- [Google Play kullanıcı verileri](https://support.google.com/googleplay/android-developer/answer/10144311), [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469), [hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111), [hassas izinler](https://support.google.com/googleplay/android-developer/answer/16558241): nihai beyan ve erişilebilir politika/silme kaynakları gerçek release'e göre doğrulanmalı.
- Mevcut GitHub Pages paketi `site/README.md` içinde manuel yayın kapısına bağlıdır; bu incelemede URL'nin yayımlandığı veya erişilebilir olduğu doğrulanmadı. Site URL ayarı değiştirilmedi.

1. **Veri sorumlusu ve iletişim:** kimlik, adres ve başvuru kanalı nedir? Aydınlatma ve Play politika sayfası bunlar olmadan tamamlanamaz.
2. **Amaçlar ve hukuki sebepler:** konum, hesap, bulut ve her aktarım için hangi dayanak ve ayrı rıza gerekiyor? Onboarding metinlerini ve seçimlerini belirler.
3. **Yurt dışı alıcıları:** Supabase, Google, Mapbox, e-posta ve alt işleyenler için hukuki aktarım mekanizması nedir? Politika ve sözleşmeler buna bağlıdır.
4. **Planet ve profil görünürlüğü:** ortak yol katkısı saklama/silme ve authenticated profillerin görünürlüğü onaylanıyor mu? Şema, silme worker'ı ve beyanı etkiler.
5. **Saklama ve yedek:** cihaz, DB, Storage, log, operatör ve yedek süreleri ve restore sonrası silme nasıl işletilecek? İmha beyanı ve operasyon kabulünü belirler.
6. **Hesap silme kanalı:** yetkili operatör, kimlik doğrulama, bildirim ve kamuya açık web adresi nedir? Play hesap silme kabulünü belirler.
7. **İlk Play kapsamı:** hangi harita/SDK akışları ve izinler gerçekten açık olacak? Data Safety, konum açıklaması ve arka plan konumu beyanı gerçek artefaktla eşleşmelidir.

## 10. Teknik yayın engelleri

Onaylanmış hukuki katalog ve erişilebilir yayımlanmış politika/silme sayfaları; arka plan konumu ve Play beyanı kabulü; R1 bulut guard'larının güvenli PROD aktivasyonuna ilişkin ayrı karar/test; hesap silme ve yedek operasyonu; SDK veri aktarım kanıtları ve gerçek cihazda uçtan uca kabul bekliyor. Bu taslak hiçbir gate'i açmaz.
