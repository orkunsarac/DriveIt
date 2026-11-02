# Kapalı beta — R3/R4 hazırlık checkpoint'i

Başlangıç: `84bf5aa366c875bb97c99cf51e8b5bd042c4e8b3`.
Bu belge tüm kapalı beta kabulü değildir. İlk hazırlık checkpoint'inde hosted aktivasyon yapılmamıştı.

Güncelleme: kullanıcı onayıyla R3 backend upgrade ve Function dağıtımı tamamlandı; `r3_deployment_acceptance.md` güncel dağıtım kaydıdır. Aşağıdaki ilk hazırlık bulguları tarihsel checkpoint'i anlatır. Signup, istemci Auth/cloud ve worker/cron aktivasyonu hâlâ kapalıdır.

Hosted kullanıcı kabulü öncesinde road-processing sürüm uyuşmazlığı bulundu ve yerelde düzeltildi; `hosted_acceptance_road_version_correction.md` yeni blokaj ve test kanıtıdır. PROD 50 migration'da ve sıfır kullanıcıyla bekler; iki yeni migration ve delete-account güncellemesi ayrıca onay bekler.

Son güncelleme: bu iki correction ayrıca onaylanıp uygulandı. PROD52 ve kontrollü hosted servis kabulü PASS; `hosted_acceptance_result.md` güncel kayıttır. Site URL localhost, gerçek e-posta/cihaz ve hukuki onay engelleri devam eder.

## Uygulanan değişiklikler

- R3: `upgrade_manifest.json` hesap silme sisteminin mevcut 25 ileri migration'ını LF-normalize SHA-256 ile listeler. `build_prod_upgrade.ts` temel 25 migration'ın hash/sırasını doğrular; mevcut veritabanında tam temel geçmişi, henüz silme şeması bulunmamasını ve Group Drive FALSE şartını arayan ek transaction üretir. 25 yeni geçmiş satırı ve final güvenlik kontrolleri aynı transaction içindedir. Bu artifact boş veritabanına doğrudan uygulanmaz: önce temel `atomic.sql`, sonra `upgrade.sql` gerekir. Tekrar çalıştırma belirsizliğinde geçmiş okunmadan yeniden uygulanamaz.
- R3: offline release paketleyicisi artık ayrı `upgrade.sql` üretir. Upgrade kaynak envanteri de temel hazırlık manifestinin hash kontrolüne dahildir. `deploymentReady=false`, workerSchedulingEnabled=false, signup kapalı şartı ve Group Drive FALSE korunur.
- R4: mevcut kişisel sürüş silme adapter'ındaki Play için genel ret kaldırıldı. Silme halen `deletionEnabled` opt-in ve M2 capability/lease fencing gerektirir. Gerçek factory güvenli gateway'i olan Play adapter'ına mevcut kapalı deletion gate'ini iletir. Her çağrı upload/download ile aynı owner/epoch ve sabit credential sınırından geçer. Gate'ler açılmadı; yerel sürüş veya journal silinmedi.
- R5: `check_aab_native_alignment.ps1` mevcut AAB'yi değiştirmeden bütün 64-bit ELF PT_LOAD segmentlerinde 16 KB hizalama ve offset/vaddr uyumunu kontrol eder. APK ZIP hizalaması ve 16 KB cihaz testi ayrı kabuldür.

## Kritik kontroller

- Deno temel/upgrade builder: 4/4 PASS; exit 0.
- `test_prod_upgrade_local.ps1`: yeni boş `r3-upgrade-*` stack'inde localhost, tam stack-id Docker label, ayrı fiziksel mount ve farklı PostgreSQL system identifier kontrollerinden sonra gerçek temel + upgrade kuruldu. Önce upgrade ROLLBACK ile çalıştırıldı: temel 25 geçmiş satırı kaldı, silme şeması oluşmadı. Sonra COMMIT: 50 geçmiş satırı, worker/audit ACL assertions, gate FALSE ve sıfır kullanıcı PASS; exit 0. Önceki yerel/DEV stack'lerine migration uygulanmadı. Test stack'i sıfırlanmadı/silinmedi.
- Hazırlık self-test: 12/12 PASS. Offline temel ve upgrade paket üretimi: PASS.
- Flutter gerçek SDK/lifecycle cloud observe/delete yarışları ve mevcut sync adapter/download regresyonu: 33/33 PASS; exit 0. A→B, logout ve epoch değişiminde eski destructive yanıt reddedilir ve hiçbir A çağrısı B token'ıyla gönderilmez.
- Tam `flutter analyze --no-pub`: mevcut 3 warning + 4 info baseline'ı korunur; yeni bulgu yok, baseline nedeniyle exit 1.
- Yerel P-GR6A Auth/Edge password/JWT/receipt A/B yetkisi: 1/1 PASS, exit 0 (26 ilgisiz test filtrelendi; tam paket sayılmadı). Yerel worker secret ilk başlangıçta yüklenmediğinden ilk iki deneme 503 `recovery_not_configured` verdi. Sabit stack-id için veri koruyan stop/start sırasında secret environment yüklenerek düzeltildi. PGDATA ve PostgreSQL system identity runner tarafından tekrar doğrulandı. DEV stack'leri değiştirilmedi.
- Mevcut 1 Kasım AAB salt okunur: `com.osaracx.driveit`, versionCode 1, versionName 1.0.0, target API 36, backup=false. 8 adet 64-bit ELF PASS. Bu AAB yeni R3/R4 kodunu içermez; tam özellikli beta adayı sayılmaz. Yeni imzalı build henüz yapılmadı.

## Aktivasyon ve uyumluluk koşulları

- PROD temel kurulumunun güncel katalog ve hash geçmişi salt okunur karşılaştırılmalı; ardından yeni upgrade transaction izole temiz Supabase üzerinde uygulanıp rollback ve worker/Planet schema-2 replay kabulü tamamlanmalı. Eski hosted temel paket otomatik yeniden uygulanamaz.
- Schema 1 ↔ 2 ortak yol karşılaştırması açıkça reddedilmeye devam eder; eski skorlar yeniden hesaplanmaz. Aynı mod karşılaştırması korunur. Bu bir uyumluluk politikasıdır; karışık kaynaklar için sessiz downgrade yoktur.
- Worker scheduling/cron etkin değildir. Onaylı PROD secret, sınırlı invocation yöntemi, rate/timeout, retry ve izleme kabul edilmeden cron kurulmaz. Receipt kurtarma scheduling yetkisi yerine geçmez.
- Play Auth sabit kapalı kapısı, local owner aktivasyonu, sync/deletion/Planet gate'leri ve hukuki onboarding korunur. Kullanıcı 2 Kasım'da nihai hukuki onayın henüz bulunmadığını doğruladı. Nihai metin ve sürüm kabulü olmadan gerçek onboarding veya beta açılmaz.
- Hosted signup/SMTP/redirect değişikliği, migration/Function dağıtımı ve worker aktivasyonu için ayrı açık onay gerekir. İlk PAT HTTP 401 verdi. Kullanıcının yeni salt okunur PAT'i maskeli yerel girişle DPAPI kaydına yazıldı; eski şifreli kayıt repository dışında yedeklendi. Yeni PAT ile 2 Kasım salt okunur denetimi PASS: doğru PROD, ACTIVE_HEALTHY, disable_signup=true, auth.users=0, migration=25, public tablo=18, gate=false, deletion şeması yok, 9 Function ACTIVE ve mevcut JWT politikaları beklenen değerlere eşit. Salt okunur rolün service-only `phase8_group_enabled()` EXECUTE yetkisi yoktur; denetim bu fonksiyonu çağırmak yerine rollout tablosundaki değeri okur. Yetki genişletilmedi. Deployment veya veri değişikliği yapılmadı.

## Sıradaki iş ve zorunlu dış kabuller

1. Temiz SQL/rollback ve hosted temel durum karşılaştırması tamamlandı. Sonraki teknik kabul schema-2 hesap silme replay kapsamı ve somut upgrade/Function dağıtımının ayrı onayıdır. Yeni PAT'in yazma yetkisi bulunduğu varsayılmaz.
2. Somut deployment planının kullanıcı onayı; Group Drive kapalı kalacak. Gerçek Auth/e-posta ve iki cihaz bulut kabulü bundan sonra yapılabilir.
3. Hukuki nihai metin, veri sorumlusu bilgileri, yayınlanmış gizlilik/silme URL'leri ve Data Safety onayı. Hukuki süre/dayanak uydurulmaz.
4. Onaylanmış yapılandırmayla yeni imzalı AAB, A55/ikinci cihaz ve 16 KB cihaz kabulü; sonra R6 tam regresyon. Mevcut anahtar değiştirilmez.

Google Play teknik kaynakları: [target API](https://developer.android.com/google/play/requirements/target-sdk), [16 KB desteği](https://developer.android.com/guide/practices/page-sizes). API 36 ve 16 KB gereksinimleri 2 Kasım 2026 tarihinde resmi kaynaklardan kontrol edildi.
