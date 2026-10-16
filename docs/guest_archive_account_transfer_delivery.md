# Misafir ve Cihaz Arşivi → Hesap aktarımı

Tarih: 16 Ekim 2026. Dal: `feature/gps-refactor`.
Kaynak HEAD: `c2e68bffd67e442bf9e1261666d5f9bb3da078f9` + korunmuş yerel değişiklikler.
Commit/push yapılmadı.

## Normal uygulamadaki akış

- Hesap Home ekranı, aktarılabilir Misafir kaydı varsa bir kez aktarım sorusu gösterir. “Şimdi Değil” sürüşleri değiştirmez; aynı kaynak envanteri için soru tekrar gösterilmez.
- Hesap Profilinde “Sürüşleri Hesabıma Aktar” girişi vardır. Aktarım ekranı sayıları, sonucu ve eski kayıtların uyumsuzluk nedenlerini gösterir. Kaynak kayıt kalmayınca Profil girişi gizlenir; kalan eski kayıtların yönetimi bu ekran üzerinden sürer.
- Misafirden aktarım ayrıca onaylanır. Hedef gerçek Auth UID'sine bağlı mevcut owner deposudur. Başka bir hesabın yarım aktarımı devralmasına izin verilmez.
- Eski arşiv incelemesi gerçek Android cihaz doğrulaması ister. Salt okunur arşiv grant'i yazma izni değildir; aktarım ayrı amaçla alınmış cihaz grant'i gerektirir. Home, kilit/arka plan, owner/epoch değişimi ve süre dolması mevcut grant'i geçersizleştirir.
- Yalnız seçilmiş, okunabilir ve fingerprint'i aynı kalan uyumsuz eski kayıtlar ayrı silme onayıyla temizlenebilir. Kimliği/içeriği doğrulanamayan bozuk kayıtlar otomatik silinmez.

## Dayanıklılık ve veri koruma

`AccountDriveTransfer`, yeni depolama mimarisi yerine mevcut Guest `profile` deposunda `account_transfer_v1:` işlem kayıtlarını kullanır. Kaynak kimliği, hedef hesap, içerik hash'i, dondurulmuş kaynak, sürüş adı ve deterministik hedef ID yazılıp doğrulanır. Sürüşün Hive adapter baytları da saklanır; `RoutePoint.legacyHiveFields` dahil eski alanlar yorumlanmadan korunur. Mikro-saniye tarih düzeltmesi artık sürüşü manifestten yeniden oluşturarak bu alanları düşürmez.

Hedefte önce pending finalization yazılır. History/rota/telemetri/güvenilir skor read-back'i, bağımsız kaynak hazırlığı ve uygun Career/World işleri tamamlandıktan sonra completed işareti yazılır. Buluta uygun kayıt için mevcut M1 outbox satırı ayrıca reflush/read-back edilir. Ancak bundan sonra Guest History kaydı veya yetkili legacy kaynak satırı kaldırılır. Guest'in bağımsız World/Career kaynakları topluca silinmez; mevcut History silme ayrımı korunur.

Kesinti sonrası aynı işlem kaydı tekrar kullanılır. Hem kapanıp açıldıktan sonra hem aynı süreçte başarısız flush sonrası retry test edilmiştir. Owner değişimi eski işlemi durdurur; diğer hesabın deposuna yönlendirme yapılmaz. Yerel M2 tombstone varsa kayıt yeniden oluşturulmaz.

## Yerel / bulut / World / Career ayrımı

Geçerli eski metadata ve rota, telemetri olmadan yerel hesap History'sine alınır. 5 km altı kayıtlar korunur. Eksik GPS, hız, telemetri, provenance veya skor üretilmez. Eski `drives.hive` tek başına yeni M1 proven kaynak kanıtı sayılmaz; bu kayıtlar yerel kalır ve History'de buluta uygun olmadıkları belirtilir.

Proven Guest kaynağında gerçek source UUID korunur, açık aktarım onayıyla hedef owner scope'una bağlanır; yerel ID ve ilişkili referanslar birlikte eşlenir. Güvenilir skor korunur. Career mevcut sourceIdentity tekilleştirmesini kullanır. Mevcut v6 şartlarını sağlayan sürüş için idempotent World doğrulama işi kuyruğa alınır; provider/worker tamamlanmadan World başarısı iddia edilmez. Yetersiz kaynak için katkı uydurulmaz.

Yalnız mevcut M1 canonical şartlarını sağlayan kaynaklar otomatik sync outbox'ına alınır. Kuyruk varlığı cloud ACK değildir. DriveIt Gezegeni'ne otomatik yayın yoktur. M1/M2 sözleşmesi, SQL ve Edge kaynakları bu görevde değiştirilmedi; remote deploy yapılmadı.

## Test kanıtı

- Son kaynaklarla `flutter test --timeout=2m`: **1017 geçti, 2 koşullu atlandı**.
- Aktarım/depo/Profil/arşiv hedefli testleri: **95 geçti**; ardından son kaynaklarla tam regresyon tekrar geçti.
- M1/M2 istemci ve Supabase adapter sözleşme testleri tam regresyona dahildir. Bu, yeni gerçek bulut veya fiziksel aktarım kabulü olarak sunulmaz.
- Gerçek sentetik Hive dosyalarıyla Guest aktarımı, legacy lazy-box okuma/silme, opaque rota alanları, küçük mesafe, eksik telemetri, seçilmiş temizleme, ret, kaynak değişimi, kesinti, tekrar, owner iptali, M2 anti-diriltme ve normal navigator → Profil → aktarım UI akışı doğrulandı.
- Değişen kaynak/test dosyalarında `dart analyze`: **bulgu yok**. Tam `flutter analyze`: görev öncesindeki **3 warning + 4 info**; warning'ler arşiv Android testlerindeki gereksiz `!` kullanımlarıdır.
- Atlananlar: isolated Android build define isteyen backend guard testi; Windows'ta sentetik symlink oluşturulamayan poster testi. Başarılı kabul sayılmadılar.
- `git diff --check`: başarılı.

## APK ve A55

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Paket: `com.example.driveit_project`; versionCode `1`, versionName `1.0.0`.
- Release/AOT arm64 `libapp.so` mevcut; `debuggable=false`.
- Native owner runtime işareti açık; isolated/test runtime işareti kapalı.
- Auth/sync yapılandırması mevcut Planet DEV `viqngnjfgknpxtoapzcg`; yalnız ignore edilmiş public build yapılandırması kullanıldı.
- Sertifika SHA-256: `0b946cfdee1f4c10c2395475b952b4822944e64494d5ffbdeba4ed71f3422e21`; kurulu eski APK ile eşleşti.
- APK SHA-256: `876CE3C4F96CD4720ECB12B29C1210251C4A5DDD01E5576F9BF2AC4E50B3E82E`.
- Boyut: 90,513,818 bayt.
- A55 `R5CX42V8GSJ` device durumundaydı. Kurulumdan hemen önce uygulama süreci ve kayıt foreground servisi yoktu.
- Yalnız `adb install -r` çalıştırıldı: **Success**. Kurulu APK read-back hash'i yukarıdakiyle aynı; kurulum sonrası uygulama süreci yok.
- Uygulama açılmadı; gerçek kullanıcı adına aktarım, silme, upload veya giriş yapılmadı. Uninstall / pm clear kullanılmadı. Gerçek kayıtların içerik/sayı kontrolü manuel kabulde yapılacak.

## Kullanıcının manuel adımları

1. Normal DriveIt'i aç, gerçek hesabına gir. Misafir sorusunda aktarımı seç veya “Şimdi Değil” de.
2. Profil → Sürüşleri Hesabıma Aktar ekranını aç. Misafir sayısını kontrol ederek istediğinde aktarımı onayla.
3. Eski kayıtlar için PIN/biyometri ile arşivi incele; uyumlu/uyumsuz sayılarını ve nedenleri gör. Uyumlu kayıtları aktar. Uyumsuz temizliği isteğe bağlıdır ve yalnız seçilen kayıtları etkiler.
4. Hesap History/rota/skoru kontrol et. Buluta uygun proven kaynakların ACK durumunu Bulut Senkronizasyonu ekranında izle. Eski telemetrisiz rotalar yerel kalır.

Telefon üzerinde gerçek kayıtlarla bu adımlar henüz çalıştırılmadı; kullanıcı onayıyla manuel kabul bekliyor.
