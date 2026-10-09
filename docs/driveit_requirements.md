# DriveIt — Kesinleşen Kurallar ve Uygulama Planı

**Amaç:** DriveIt'in normal sürüş, GPS kurtarma, Drive Score, Benim Dünyam, DriveIt Gezegeni, Kariyer, hesap/yerel kayıt, çoklu cihaz ve Grup Sürüşü davranışlarını mevcut uygulamayı bozmadan geliştirmek. Bu metin ürün gereksinimleridir; repoda hâlihazırda uygulanmış oldukları varsayılmaz.

**Uygulama ilkesi:** Önce tüm sunucudan bağımsız kod, veri modeli, ekranlar, servis dayanıklılığı ve otomatik testler tamamlanacak. **Yeni bulut/Supabase veritabanı, Storage, RLS, Edge Function, Realtime ve sunucu senkronizasyonu entegrasyonları EN SON FAZDA** yapılacak. Repoda zaten bulunan Supabase Auth veya Gezegen taslakları bozulmayacak; eksik sunucu işlevleri önceden varmış gibi gösterilmeyecek. Bulut aşamasına kadar API'ler arayüz/adapter ve test doubles üzerinden hazırlanabilir; gerçek çok-kullanıcılı ve çapraz-cihaz güvenlik garantileri ancak sunucu entegre edilince doğrulanabilir.

## A. Güvenlik, sürümleme ve uygulama standardı

1. Önce repo, aktif branch, HEAD, değişmiş dosyalar, Hive box/schema, GPS foreground task/servis, Drive Score, World, Planet, Supabase/Auth, Android manifest ve test envanteri denetlensin. Yapılmış iş yeniden yazılmasın.
2. Her faz küçük değişikliklerle yürüsün; mevcut sürüşler, kariyer ve dünya kayıtları hiçbir zaman temizlenmesin. Kalıcı veri formatı değişiyorsa idempotent, sürümlü, başarısızlıktan toparlanabilen migrasyon ve rollback/backup stratejisi olsun.
3. Sürüş veri doğruluğu estetikten üstündür. Eksik GPS verilerinden mesafe, yol şekli, hız, hareket/Drive Score uydurulmasın. Özel/kişisel ve ortak/gezegen verileri karıştırılmasın.
4. Her faz sonunda değişen dosyalar, teknik kararlar, olası riskler, test sonuçları ve manuel cihaz test talimatları raporlansın. Yeni bulut kaynakları son fazdan önce oluşturulmasın; repository secrets ve gerçek kullanıcı verileri raporda sızdırılmasın.
5. Ana ürün kararları kesinleşmiştir; ufak teknik ayrıntılar makul varsayılanlarla çözülür. Ürün mahremiyeti, geri döndürülemez kayıp veya ana işleyişi etkileyen çelişki varsa ayrıca bildirilir.

## B. Normal sürüş ve güvenli GPS kurtarma

1. Normal sürüş kaydı, Grup Sürüşü'nden bağımsızdır; ikisi aynı anda çalışabilir. Mümkünse altta aynı fiziksel GPS sağlayıcısını kullanırlar; mantıksal işleme, tamponlar, kayıt ve veri sahipliği ayrı tutulur.
2. UI yeniden oluşturulup foreground servis devam ediyorsa aynı aktif sürüş sürer; ikinci sürüş açılmaz. Servis gerçekten durmuşsa o ana kadar kalıcı kaydedilmiş GPS noktaları, süre ve istatistikler korunur. Kullanıcıya **Sürüşe Devam Et** veya **Kaydet ve Bitir** sunulur; kesintiyi aşan sahte noktalar oluşturulmaz.
3. Önceki incelemede şüphelenilen risk: yeni `DriveTaskHandler` boş `_route` ile başladığında eski `driveit_background_route` verisi geri yüklenmeden ilk GPS noktasında tampon üzerine yazılabilir. Bu olası neden **kanıtlanmış kök neden gibi sunulamaz**; repo ve testle doğrulanmalıdır. Durable checkpoint/journal, yeniden başlatmada yeniden yükleme ve eski verinin üzerine yazılmaması kritik kabul testidir.
4. GPS kesintisinin öncesi ve sonrasındaki güvenilir izler gerçek geometri olarak ayrı segmentlerde saklanır. Haritada arada yalnızca **görsel kesikli çizgi** çizilebilir. Kesikli bağlantı hiçbir gerçek rota/geometri, mesafe, hız, Drive Score veya keşif hesabına dahil edilmez; veri boşluğu tek uçta kalıyorsa hayali bağlantı çizilmez.
5. **Toplam geçen sürüş süresi** ile **güvenilir GPS ile ölçülmüş süre** ayrı gösterilir. GPS kesintisindeki ölçülemeyen zaman hareket süresine, ortalama hıza, mesafeye veya Drive Score hesabına katılmaz. Ortalama hızın paydası güvenilir ve süre hesabına uygun GPS aralıklarıdır; veri boşlukları hariçtir.
6. Kuyruk ve işlem geri denemeleri aynı sürüşü ikinci kez kaydetmez veya kariyere tekrar işlemez. Recovery hem app/process/foreground service ölümü hem OS koşulları için test edilir; Android reboot sonrası kesin otomatik devam vaat edilmez.

## C. Drive Score ve veri yeterliliği

1. Mevcut Drive Score v1'in kategorileri, ağırlıkları ve N/A davranışları korunur; uygulamadaki gerçek formül denetlenmeden değiştirilmez.
2. Nihai Drive Score ancak **güvenilir GPS veri kapsaması >= %80** VE **yeterli güvenilir hareket örneği** koşulları birlikte sağlandığında üretilir. Kapsama için başlangıç tanımı: güvenilir GPS ile ölçülen süre / toplam geçen süre. Hareket örnek sayısal eşikleri mevcut koda ve test verilerine göre belirlenmeli, ayarlanabilir ve test edilebilir olmalıdır.
3. GPS kaybı anlamlı olduğu halde yeterlilik sağlanıyorsa score **kısmi veri uyarısıyla** gösterilir. Yetersizse nihai score **Puanlanamadı / N/A** olur; sıfır puan yazılmaz, puan sıralamalarına alınmaz.
4. Kesinti sınırlarında yapay frenleme/hızlanma/viraj/akıcılık olayları oluşmaz. Bağımsız Gezegen segmentlerinin puanları, aynı segmentin gerçek güvenilir verisinden **ayrı** hesaplanır; tüm orijinal sürüşün puanı kopyalanmaz.

## D. Benim Dünyam — kişisel harita

1. GPS kesintisi olan normal sürüş Benim Dünyam'da tek orijinal sürüş olarak gösterilebilir: güvenilir segmentler + aradaki **görsel kesikli çizgi**. Kesikli çizgi gerçek yol keşfi, overlap/geometri, mesafe veya skora dahil değildir.
2. Orijinal sürüşün toplam mesafesi güvenilir segment mesafelerinin toplamıdır; score orijinal sürüşün veri yeterliliği kurallarına göre hesaplanır.
3. Daha önce kararlaştırılan mevcut Dünya kuralları korunur: minimum 5 km ana uygunluk kuralı; ortak yol algısı için var olan eşik ve yön bağımsızlığı; ilk geçerli iz korunması, gidiş-dönüş iz ayrımı, kontrollü silme. Mevcut canonical/Map Matching temizleme ve çizim kuralları tespit edilip korunmalıdır; örneğin GPS sıçraması, tekrar noktası ve yön offset sunumunda persisted orijinal geometri değiştirilmez.
4. Kullanıcı Benim Dünyam'dan kendi kişisel izini silebilir; bu Sürüşlerim kayıt silmesinden bağımsızdır. Kişisel iz silmek Kariyer veya sunucuda kabul edilmiş Gezegen yayınlarını etkilemez.

## E. DriveIt Gezegeni — yayın hazırlığı ve kural seti

1. Gezegene yayınlamak istenen GPS kesintili sürüşten **eksik bölümler tamamen kaldırılır**. Kalan kesintisiz, güvenilir GPS parçaları bağımsız aday alt sürüşler olarak değerlendirilir; her biri en az **5 km** ve mevcut rota doğrulama kurallarını karşılamalıdır. Orijinal sürüş ile parça kimliği/indeksi ilişkisi korunur.
2. Her parçanın mesafesi ve mümkünse Drive Score'u kendi verisinden hesaplanır. **Rota geçerli fakat score veri yetersiz** ise parça yine yayınlanabilir; **Puanlanamadı** gösterilir ve puan sıralamasına alınmaz.
3. Kullanıcıya önizlemede bütün parçalar, uygun/uygun değil durumu, ayrı mesafe ve varsa ayrı puan gösterilir; **tek onayla uygun parçalar bağımsız yayın istekleri** olarak gönderilir.
4. Çoklu yayında **kısmi başarı** kabul edilir: kabul edilen parçalar kalır, başarısız parçalar tekrar denenir. Her gönderim belirlenmiş idempotency kimliğiyle eşsizdir; sunucu yanıtı kaybolursa durum sorgulanıp çift kayıt oluşmaz.
5. Sunucu doğrulaması sürerken parçalar **Gezegen haritasında görünmez**; yalnızca **Yayın Durumları** ekranında Beklemede / Doğrulanıyor / Yayınlandı / Reddedildi / Tekrar Dene durumları görünür. Yalnızca sunucu kabul edince Gezegen haritasına eklenir. Haritada sahte bekleyen iz/yerel yayına kabul simülasyonu yapılmaz.
6. Kişisel **benzersiz keşfedilen yol uzunluğu** ile **kabul edilmiş yayınların toplam sürüş uzunluğu** ayrı istatistiklerdir. Aynı kişinin aynı yolu tekrar sürmesi yeni benzersiz keşif eklemez; doğrulanmış sürüş mesafesi toplamına katkı sağlar. Küresel benzersiz Gezegen yolu da tekrarlı kayıtlarla artmaz. Başka kullanıcı aynı yolu sürerse kendi kişisel benzersiz mesafesi ve kendi sürüş/score verileri bağımsızdır. Yön ayrımı ve mevcut ortak yol/eşleşme kuralları korunur.
7. Gezegene **sunucu tarafından kabul edilmiş yayınlar** normal kullanıcı silmeleriyle geri alınamaz; Sürüşlerim/Benim Dünyam'dan kaynağı silinse bile Gezegendeki kabul edilmiş kayıt/iz korunur. Gerekli hukuk, güvenlik ve moderasyon işlemleri ayrı istisnalardır.
8. Gerçek sunucu doğrulama, PostGIS, Storage, submission, Realtime/RLS entegrasyonu **en son bulut fazında** yapılır. Önce sadece domain modelleri, önizleme, uygunluk testleri, yayın durum UI ve sahte servis adaptörleri hazırlanır. Repoda mevcut yayın altyapısı kırılmadan korunur.

## F. Kariyer — kalıcı, birikimli istatistikler

1. Kariyer, Sürüşlerim'de halen bulunan kayıtları her ekran açılışında toplayan bir görünüm olmamalıdır: sürüş bitip geçerli katkı oluştuğunda ayrı **idempotent append-only katkı günlüğü / aggregate** güncellenir.
2. Sürüş sayısı, güvenilir ölçülmüş mesafe/süre ve diğer doğru istatistikler bir kere eklenir; yerel sürüş veya Benim Dünyam izi sonradan silinse de **Kariyer asla azalmaz**. Sürüş kurtarma, migrasyon, senkronizasyon, Gezegene yayınlama ya da yeniden işleme aynı katkıyı tekrar saymaz.
3. GPS kesinti aralıkları kariyere sahte hareket/mesafe/puan eklemez. N/A puan yanlışlıkla 0 skor gibi işlenmez.
4. Hesapsız misafir Kariyer yereldir. Hesaba girişte aktarım **ancak kullanıcının açık onayıyla** yapılır ve aynı katkılar ikinci kez sayılmaz. Giriş yapmış kullanıcının çevrimdışı tamamlanan sürüşleri Kariyer'de anında görünür; sunucu senkronizasyonu bekleyen katkılar ayrıca gösterilir.
5. Kariyer kalıcı hesabî bulut eşlemesi son fazda; öncesinde yerel güvenli, sahip hesap kimliğiyle ayrılmış defter ve outbox hazırlanır.

## G. Hesap izolasyonu, eski kayıtlar ve özel bulut yedeği davranışı

1. Cihazdaki Sürüşlerim, Benim Dünyam ve bekleyen Kariyer katkıları **hesap bazında ayrılır**. A hesabı çıkış yaptığında verileri silinmez; B hesabı A'nın özel kayıtlarını görmez. Misafir alanı ayrıdır.
2. Hesap sahipliği bulunmayan **eski Hive kayıtları**, mevcut veriler kaybolmadan ve otomatik hesap tahsisi yapılmadan **misafir alanında** korunur. Kullanıcı seçtiği hesaba açık onay verirse aktarılır; migrasyon idempotent/yarıda kesintiye dayanıklıdır. Daha önce işlenmiş kariyer veya Gezegen yayını etkilenmez.
3. Kullanıcı DriveIt hesabıyla giriş yapmışsa **özel Sürüşlerim ve Benim Dünyam verilerinin buluta kaydı OTOMATİK** olmalıdır; yedekleme aç/kapat tercihi **yoktur**. Konum geçmişinin hesaba senkronize edildiği hesap açma/giriş sırasında şeffaf belirtilir. Hesapsız/misafir verileri açık onay olmadan hesaba/buluta aktarılmaz.
4. Yeni cihazda aynı hesaba girildiğinde hesap bulutundaki özel kayıtlar **ayrı geri yükleme sorusu olmadan** otomatik geri getirilip mevcut aynı hesap yerel kayıtlarıyla kimlik bazında birleştirilir; çift sürüş/dünya izi/kariyer katkısı yaratılmaz.
5. Kullanıcı Sürüşlerim'den sürüş veya Benim Dünyam'dan iz sildiğinde bu işlemler **birbirinden bağımsızdır**. Onaylı silme tüm o hesaba bağlı cihazlara ve özel bulut yedeğine yansır. **Çöp Kutusu, 30 gün geri alma veya normal kurtarma yoktur.** Çevrimdışı silme log/tombstone ile daha sonra senkronize edilir; eskimiş cihaz silinen içeriği geri getiremez. Silinen özel içerik payload'u kalıcı silinir; yalnızca replikasyon tutarlılığı için gerekli en az silme meta-verisi tutulabilir.
6. Kariyer ve kabul edilmiş Gezegen yayınları bu özel veri silmelerinden etkilenmez. Bulut yedekleme ve senkronizasyonun gerçek icrası en son faza aittir.
7. Aynı hesabın farklı cihazlarındaki meşru sürüşler **akıllı birleştirilir**; mükerrer ve silinmiş içerik tekrar yaratılmaz. Çevrimdışı katkı kaynağı olan hesap kimliğine bağlı güvenli saklanır; senkronizasyon bitmeden çıkış yapılabilir, çıkışta uyarı verilir. Hesap A'nın bekleyen katkısı yalnızca A yeniden giriş yaptığında gönderilir; B hesabına karışmaz.
8. Normal sürüş için **hesap başına bir aktif sürüş**: internet varken ikinci cihaz yeni sürüş açamaz. Çevrimdışı başlatılan olası çakışan sürüşler silinmez; senkronizasyonda güvenli, kör otomatik birleştirmeye dayanmayan mükerrerlik incelemesi gerekir; aynı gerçek yolculuk kariyere iki kez eklenmez. Grup Sürüşü bağımsızdır.
9. Sunucu aktif sürüş sahipliği için süreli lease: başlangıç yapılandırması **30 sn heartbeat, 3 dk zaman aşımı** (sahada ayarlanır). Süre dolunca sunucu kilidi otomatik serbest bırakabilir; bu **eski cihazda hâlen süren çevrimdışı GPS kaydını durdurmaz, silmez veya bitirmez**. Cihaz tekrar bağlandığında lease/sahiplik ve çakışma güvenle uzlaştırılır. Gerçek sunucu lease servisi son bulut fazında kurulur.

## H. Grup Sürüşü — onaylanan bütün temel davranışlar

1. Gruplar **geçici canlı konvoy** oturumlarıdır; sosyal arkadaşlık/listesi değildir. Hesap sahibi grup oluşturur; link veya kodla katılınır. Kurucu admin. Grup kurulunca veya davetle katılınca **harita hemen açılır**, bekleme odası ve admin 'Başlat' düğmesi yoktur. Geçerli davet için katılım onayı gerekmez fakat **kişisel canlı konumu yayınlamak için ayrıca açık onay** zorunludur.
2. Bir grupta admin dahil en fazla **10 kişi**; her hesap aynı anda en fazla **bir aktif gruba** üye olabilir. Başka gruba geçerken mevcut gruptan ayrılma onayı istenir; yeni grup konum paylaşımı varsayılan olarak **kapalı** başlar.
3. Konum paylaşımı **asimetrik**: duraklatan üyeye diğer üyeler görünmeye devam edebilir; duraklatanın eski konumu/hızı/yönü diğerlerinden kaldırılır, üye listesinde duraklatıldı gösterilir. Paylaşım ancak kişinin açık hareketiyle yeniden başlar; duraklatma restart/reboot sonrası korunur.
4. Her üye mevcut davet kodu/linkini paylaşabilir. **Yalnızca admin** daveti açıp kapatır, kodu yeniler (eskisi geçersiz), üyeyi çıkarır/yasaklar veya yasağı kaldırır. Çıkarılan hesap o spesifik gruba yeniden alınmaz; yasağı kaldırılınca bile yeni geçerli davetle kendisi yeniden katılır. Tam grup, kapalı davet, eski kod, yasaklı hesap katılamaz. Sunucuda üyelik ve ban yetki denetimi gerekir.
5. Admin isteyerek ayrılırsa yetkisi uygun kalan üyeler arasında **ilk katılana** atomik devredilir; bağlantısının geçici kesilmesi otomatik devir yapmaz. Admin ister yalnızca ayrılır, ister grubu herkes için sonlandırır. Son kişi ayrılınca grup kapanır.
6. Grup süresi **12 saat başlangıç**; admin **iki kere +6 saat** uzatabilir; mutlak **24 saat maksimum**. Süre sunucu tarafından uygulanır, bağlantı kesintisi süreyi durdurmaz. Süre sonu grup paylaşım/davetlerini bitirir, normal sürüş kaydını etkilemez.
7. Canlı GPS hedefi hareketli **3 sn**, dururken **8 sn**; Supabase Realtime Broadcast konum, Presence bağlantı için (son faz). Grup üyelerinin tüm ham GPS rota geçmişi kalıcı olarak saklanmaz. Bağlantı geri gelince aradaki tamponlanmış eski konumlar topluca gönderilmez, yalnızca son güvenilir güncel nokta gönderilir.
8. Grup haritasında **Map Matching/yola oturtma yapılmaz**. Filtrelenmiş gerçek GPS ile düzgün animasyon; doğruluk 0–25 m normal, 25–75 m temkinli, >75 m son güvenilir noktayı sabit tut (başlangıç test eşikleri). Geçersiz sıçramalar engellenir. Uzun kesintiden sonra uzak güvenilir yeni konuma marker **sıçrar**; eski-yeni arasında sahte yol animasyonu yoktur. GPS kaybı 'araç durmuş' sayılmaz.
9. Hız/yön akıllı filtrelenir, gereksiz 0/2/4 km/sa titremesi önlenir. Birkaç güvenilir örnekle durma doğrulanınca yön oku **yuvarlak bekleme noktasına** dönüşür, yeniden hareketle ok olur. Güvensiz heading geldiğinde son geçerli yön korunur. Hareket ve ağ durumu ayrı kavramlardır.
10. Üyenin canlı verileri: konum, anlık hız, yön, diğer üyeye **kuş uçuşu mesafe**, son güncelleme zamanı. **Harita üzeri hız etiketleri yoktur**; hız detay kartı ve yukarı kaydırılarak açılan katılımcı alt panelinde gösterilir. Varsayılan katılımcı paneli kompakt. Kendisi belirgin **mavi**, başkaları sabit atanmış ayrı renkler. Yakın zoomda akıllı isim etiketleri, uzak zoom/çakışmada gizleme; seçili üyenin etiketi her zaman görünür. Çakışan *diğer* ikonlar dokunulabilir cluster olur; kendisi ve seçili kişi ayrı kalır.
11. Canlı konum tazeliği için başlangıç bantları: **0–15 sn normal**, **15–30 sn soluk**, **30 sn–5 dk gri**, **>5 dk güvenilir GPS yoksa ikon haritadan kaldırılır** fakat üye listede kalır. Yeni güvenilir noktayla geri döner. Takip edilen arkadaş 5 dk veri kaybederse kamera **kendini takip** moduna geçer; arkadaş geri gelince otomatik geri dönmez.
12. Kamera açılışta kendi arabasını takip eder. Modlar: **Beni Takip Et**, **Tüm Grubu Göster**, **Arkadaşımı Takip Et**. Elle haritayı kaydırma otomatik kamerayı askıya alır. Kendini veya arkadaşı takipte hafif perspektif **3D**, geçerli heading ile heading-up; tüm grupta üstten **2D kuzey-yukarı**. Araç durağan/heading güvensizse son güvenilir kamera yönü korunur.
13. Arka plan/kilit ekranı/uygulama görev listesinden kaldırma sonrasında Android izin verdiği sürece foreground servisle konum paylaşımı devam eder. Reboot sonrası daha önce açık paylaşımı OS/izinler uygunsa yeniden başlatma denenebilir; **duraklatılmış paylaşım hiçbir zaman otomatik açılmaz**. Kesin reboot otomatik başlatma vaat edilmez.
14. Paylaşım denetimleri **yalnızca uygulama içinde**; foreground bildirimi sadece durum gösterir, dokununca grup haritasını açar; bildirime duraklat/başlat düğmeleri konmaz. Hem normal kayıt hem grup paylaşımı aktifse **tek birleşik kalıcı Android bildirimi** kullanılır; bir iş kapanırsa bildirim durumu güncellenir, ikisi de bitince kaldırılır.
15. Normal sürüş haritasıyla grup haritası **ayrı tam sayfalar**; kullanıcı tek dokunuşla geçiş yapabilir, her iki işlem sürer, normal sürüş haritasının üzerine grup araçları bindirilmez. Uygulama tekrar açılırsa aktif oturumlar doğrulanıp **en son kullanılan hâlâ aktif sayfa** geri gelir; sona eren sayfa yerine varsa diğer aktif ekran, yoksa ana ekran. Paylaşım duraklatma, kamera tercihi ve üyelik oturumu güvenli restore edilir.
16. Grup için gerçek çok-kullanıcılı üyelik, kapalı kanal güvenliği, ban, invite, server expiry, Broadcast/Presence ve cihazlar arası canlı görüntüleme **son bulut fazında** etkinleştirilir. Öncesinde sahte/yerel provider ile ekran, davranış ve testler tamamlanır. Ürün olarak çalışıyormuş iddiasında bulunulmaz.

## I. Faz sırası ve tamamlanma ölçütleri

**Faz 0 — Denetim / sözleşme:** Mevcut repoya karşı fark analizi, risk haritası, veri migrasyon planı, test envanteri. Kod değiştirmeden rapor; eksik kararlar teknik varsayılanlar olarak listelenir.

**Faz 1 — Güvenilir normal sürüş çekirdeği:** Foreground servis route/metadata durable persist ve restore, crash/kill/restart/recovery, doğru GPS segmentasyonu; mevcut rotaların korunması ve testler.

**Faz 2 — Sürüş istatistikleri ve Drive Score:** Gerçek/ölçülen süre ayrımı, görsel kesikli boşluk, %80 veri kapsaması, geçerli hareket örnekleri, N/A, bağımsız segment puanı ve regresyon testleri.

**Faz 3 — Benim Dünyam:** Kesintili tek sürüş görünümü, gerçek geometri/keşif ayrımı, overlap/karşı yön/regresyon, bağımsız silme ve testler.

**Faz 4 — Gezegen istemci tarafı:** Segment adayları, >=5km filtre, segment score/N/A, önizleme, tek onay, yayın durumları, kısmi başarı/idempotency için yerel domain ve mock adapter. **Yeni sunucu yayını/DB değiştirilmez.**

**Faz 5 — Kariyer ve hesap izolasyonu (yerel):** Append-only idempotent katkılar, hesap sahipli Hive alanları, misafir taşıma ve onaylı bağlama, senkronizasyon outbox arayüzü, silme tombstone modeli ve testler. Eski kayıtlar asla kaybedilmez.

**Faz 6 — Çoklu cihaz/senkronizasyon protokolünün yerel tarafı:** Birleştirme sözleşmesi, conflict/idempotency anahtarları, otomatik restorasyon için client arayüzleri, aktif sürüş lease istemcisi, 30 sn/3 dk varsayılanları; offline/mock test. **Gerçek bulut entegrasyonu yok.**

**Faz 7 — Grup Sürüşü istemci tarafı:** Tam ekran/grup kontrolleri, izin ve pause, GPS filtreleme, katılımcı paneli, map camera, marker/status, Android foreground bildirim birleşimi ve normal sürüşten izolasyon; mock üyelerle ekran/akış testleri. Gerçek davet/ban/real-time henüz sunucu olmadan çalışmaz.

**Faz 8 — SON FAZ: Bulut ve uçtan uca bağlantı:** Mevcut Supabase DEV yapısının denetimi; gerekli schema/migration, RLS, storage, RPC/Edge Functions, PostGIS/verifier, kariyer katkı defteri, özel sürüş yedek/silme/eşleme, multi-device lease, Gezegen kabul/status/idempotency, Grup Sürüşü Realtime/Presence/üyelik/davet/ban/süre. Gerçek iki+ cihazla güvenlik, bağlantı, crash ve geri yükleme kabul testleri. Gizli anahtarlar uygulamaya gömülmez. Sunucu son fazda açılmadan hiçbir sunucu garantisi tamamlandı sayılmaz.

**Her faz için kabul:** `flutter analyze` durumu (önceden var olan notlar ayrı), ilgili unit/widget/integration testleri, Android background/foreground manuel test senaryoları, veri kaybı ve migrasyon kontrolleri, değişen dosyalar listesi, sürüm/commit raporu. Faz bitmeden sonraki faza kendiliğinden geçilmez; sahibi ayrı Codex görevleriyle ilerletir.
