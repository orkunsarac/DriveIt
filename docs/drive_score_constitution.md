# DriveIt — Drive Score Anayasası v1.0

## 1. Amaç

Drive Score, bir sürüşü **0–1000 puan** arasında değerlendiren DriveIt sürüş performansı sistemidir.

Sistemin amacı yalnızca hızlı veya yalnızca sakin sürüşü ödüllendirmek değildir.

DriveIt;

**hızlı, öngörülü, kontrollü, akıcı ve bu kaliteyi uzun süre koruyabilen sürüşü ödüllendirir.**

Toplam puan:

* Frenleme & Öngörü: **350**
* Tempo & Performans: **150**
* Viraj Performansı: **150**
* Sürüş Dayanıklılığı: **150**
* Sürüş Akıcılığı: **100**
* Hızlanma & Gaz Performansı: **50**
* Geçiş Kontrolü: **50**

**TOPLAM: 1000**

---

# 2. Evrensel Puanlama Kuralları

## 2.1 Bağlam davranıştan önce gelir

Bir hız değişimi tek başına iyi veya kötü kabul edilemez.

Sistem mümkün olduğunca sürüşün içinde bulunduğu rejimi anlamalıdır:

* serbest akış,
* yoğunlaşan trafik,
* dur-kalk trafik,
* duruş,
* hızlanma,
* normal seyir,
* yavaşlama,
* viraj,
* viraj çıkışı.

Sürüş boyunca rejim değişebilir.

Tüm sürüşün tek bir "şehir içi", "trafik" veya "otoban" etiketiyle değerlendirilmesi yasaktır.

---

## 2.2 Zorunlu davranış cezalandırılmaz

Kırmızı ışıkta durmak, trafik nedeniyle yavaşlamak, dur-kalk yapmak veya yol koşullarının gerektirdiği hız değişiklikleri kendi başlarına kötü sürüş değildir.

Temel prensip:

**DriveIt zorunlu hız değişimini değil, sürücünün bu değişimi nasıl yönettiğini değerlendirir.**

---

## 2.3 Tek davranış = tek ana kategori

Aynı sürüş hatasının birden fazla kategoriden tekrar tekrar puan götürmesi engellenmelidir.

Örneğin:

* sert fren → Frenleme,
* kötü viraj → Viraj Performansı,
* kötü hızlanma → Hızlanma & Gaz Performansı.

Bu olaylar aynı sebeple Akıcılık veya başka bir kategoriden yeniden cezalandırılmamalıdır.

---

## 2.4 Tek GPS örneği karar veremez

Tek bir GPS/telemetri örneğinden ağır ceza üretilemez.

Davranışlar zaman pencereleri, olaylar ve tekrar eden paternler üzerinden değerlendirilmelidir.

GPS gürültüsü filtrelenmeden puanlamaya sokulmamalıdır.

---

# 3. Frenleme & Öngörü — 350 Puan

Frenleme sistemi Drive Score'un merkezidir.

Ana prensip:

**DriveIt fren kullanımını cezalandırmaz; gereksiz, geç ve kontrolsüz frenlemeyi cezalandırır.**

Dağılım:

* Öngörülü Frenleme: **150**
* Fren Şiddeti: **100**
* Fren–Gaz Kararsızlığı: **60**
* Duruş Kalitesi: **40**

---

## 3.1 Öngörülü Frenleme — 150

Amaç sürücünün hız kaybını ne kadar erken, kademeli ve kontrollü yönettiğini ölçmektir.

Her geçerli fren olayı için 0–100 kalite değeri oluşturulabilir:

* Erkenlik: **%40**
* Yavaşlama düzgünlüğü: **%30**
* Son-yığılma: **%20**
* Duruş kalitesi: **%10**

Sürüş puanı geçerli olayların ağırlıklı sonucundan üretilir.

Büyük hız kayıpları küçük yavaşlamalardan daha fazla ağırlık taşıyabilir.

Önemli prensip:

**Öngörü fren pedalına ne zaman basıldığıyla değil, hız kaybının ne kadar erken başlatıldığıyla ölçülür.**

Gazdan erken çıkıp motor freniyle kontrollü yavaşlamak iyi davranıştır.

---

## 3.2 Fren olayı tanımı

Başlangıç kalibrasyonu olarak:

Araç yaklaşık **15 km/s üzerindeyken**, negatif ivmenin yaklaşık **−0.7 m/s² veya daha güçlü** şekilde yaklaşık **1–1.5 saniye** devam etmesi fren/yavaşlama olayının başlangıç adayını oluşturabilir.

Olay;

* araç yeniden stabil seyire geçtiğinde,
* hızlanmaya başladığında,
* veya durduğunda

sonlandırılabilir.

Analiz yalnızca olay anına değil yaklaşık:

**olay öncesi 5 saniye + olay + olay sonrası 3 saniye**

penceresine bakmalıdır.

Bu değerler kalibrasyon parametreleridir; anayasanın değişmez fiziksel sabitleri değildir.

---

## 3.3 Fren Şiddeti — 100

Başlangıç sınıflandırması:

* 0 → −1.5 m/s²: yumuşak/normal
* −1.5 → −2.5: belirgin fakat normal
* −2.5 → −3.5: güçlü, bağlam değerlendirilir
* −3.5 → −5.0: sert
* −5.0 ve altı: çok sert/acil fren adayı

Eşikler keskin uçurumlar oluşturmamalıdır. Ceza mümkün olduğunca kademeli olmalıdır.

Tek bir çok sert fren sürücünün tüm sürüşünü mahvetmemelidir.

Çünkü GPS verisi;

* önüne araç çıkmasını,
* hayvan çıkmasını,
* ani trafik durmasını,
* diğer dış tehlikeleri

kesin olarak bilemez.

Bu nedenle tekrar eden kötü fren paterni tek olaydan daha güçlü kanıttır.

---

## 3.4 Trafik bağlamı

Son yaklaşık **30–60 saniyelik hareketli pencere** kullanılarak trafik güveni/olasılığı üretilebilir.

Trafik ihtimalini artıran örüntüler:

* düşük/orta ortalama hız,
* sık fakat çoğunlukla kontrollü yavaşlama,
* kısa duruşlar,
* tekrar hareket,
* düşük hız bandında tekrarlanan hız değişimleri.

Trafik güveni yükseldikçe fren-gaz kararsızlığı cezası ciddi şekilde azaltılabilir.

Ancak trafik, kötü fren tekniğini tamamen dokunulmaz yapmaz.

**Neden fren yaptığı** ve **nasıl fren yaptığı** ayrı değerlendirilmelidir.

---

## 3.5 Fren–Gaz Kararsızlığı — 60

Amaç normal trafik davranışını değil, gereksiz şekilde:

**hızlan → fren → hızlan → fren**

paternini tespit etmektir.

Dağılım:

* Gereksiz hızlanıp yeniden frenleme: **30**
* Tekrar sıklığı: **20**
* Davranış şiddeti: **10**

Tek döngü ağır ceza üretmemelidir.

Tekrarlayan patern aranmalıdır.

Dinamik gözlem penceresi başlangıç olarak:

* 30–50 km/s: **12–15 sn**
* 50–90 km/s: **9–12 sn**
* 90+ km/s: **6–9 sn**

olarak düşünülebilir.

Ana prensip:

**DriveIt hız değişimini değil, kısa süre sonra geri alınacağı öngörülebilirken yapılan gereksiz hızlanmayı cezalandırır.**

Trafik güveni yüksek olduğunda bu ceza yaklaşık **%80–100'e kadar bastırılabilir.**

---

## 3.6 Duruş Kalitesi — 40

Normal duruşlarda yaklaşık son **15 km/s → 0 km/s** bölümü incelenir.

Dağılım:

* Son metrelerde yumuşaklık: **20**
* Son anda sertleşme/sarsıntı: **10**
* Duruşların genel tutarlılığı: **10**

Yaklaşık son 2 saniyedeki ani negatif ivme artışı dikkate alınabilir.

Çok düşük hızlı trafik sürünmeleri gerçek duruş olayı sayılmamalıdır.

Örneğin:

3 → 0 → 4 → 0

gibi hareketler sistemi kirletmemelidir.

Acil fren zaten Fren Şiddeti bölümünde değerlendirilmişse aynı olay Duruş Kalitesinden tekrar cezalandırılmamalıdır.

---

# 4. Tempo & Performans — 150 Puan

Dağılım:

* Ortalama Seyir Hızı: **60**
* Maksimum Hız: **30**
* Mesafe / Süre Performansı: **60**

---

## 4.1 Ortalama Seyir Hızı — 60

Klasik ortalama hız kullanılmaz.

Araç dururken geçen süre seyir ortalamasından çıkarılır.

Başlangıç olarak **5 km/s altındaki hızlar duruş kabul edilebilir.**

Bu eşik GPS gürültüsüne karşı kalibre edilebilir.

Kırmızı ışıkta veya trafikte tamamen durmak kullanıcının ortalama seyir hızını düşürmemelidir.

---

## 4.2 Maksimum Hız — 30

Sürüş içerisinde ulaşılan doğrulanmış maksimum hız performans bileşenidir.

Tek bir GPS sıçraması maksimum hız kabul edilemez.

Maksimum hız toplam skor üzerinde sınırlı ağırlığa sahiptir; tek başına yüksek Drive Score oluşturamaz.

---

## 4.3 Mesafe / Süre Performansı — 60

Sürüşün gerçek başlangıcından gerçek bitişine kadar geçen toplam süre kullanılır.

Burada duruşlar **çıkarılmaz**.

Bu kategori:

**A noktasından B noktasına gerçek koşullarda ne kadar sürede ulaşıldığını**

ölçer.

Mümkün olduğunda aynı yol, benzer segment veya geçmiş sürüş performanslarıyla bağlamsal kıyas tercih edilmelidir.

---

# 5. Viraj Performansı — 150 Puan

Dağılım:

* Hız Koruma: **60**
* Giriş Kalitesi: **35**
* Çıkış Kalitesi: **35**
* Viraj İçi Stabilite: **20**

Viraj performansı mutlak hız üzerinden değerlendirilmez.

Viraj geometrisi ve keskinliği hesaba katılmalıdır.

GPS noktaları, heading değişimi, mesafe ve uygun olduğunda tahmini viraj yarıçapı kullanılabilir.

---

## 5.1 Hız Koruma

Viraj giriş hızına kıyasla viraj boyunca ne kadar momentum korunabildiği değerlendirilir.

Keskin bir virajda gerekli hız kaybı kötü sürüş sayılmaz.

---

## 5.2 Giriş Kalitesi

Sürücünün viraja kontrollü ve uygun hızla girip girmediği değerlendirilir.

Frenleme kalitesinin kendisi burada yeniden cezalandırılmaz.

---

## 5.3 Çıkış Kalitesi

Viraj sonrasında hızın kontrollü ve etkili şekilde geri kazanılması değerlendirilir.

---

## 5.4 Viraj İçi Stabilite

Viraj boyunca gereksiz büyük hız değişimleri ve kararsızlık değerlendirilir.

**Yüksek lateral G doğrudan ödüllendirilmez.**

Lateral G, virajın zorluğunu ve bağlamını anlamak için kullanılabilir.

Ana prensip:

**DriveIt virajda mutlak hızı değil, viraj geometrisine göre momentumu kontrollü koruyabilme becerisini ödüllendirir.**

---

# 6. Sürüş Dayanıklılığı — 150 Puan

Sürüş uzunluğu performansın zorluğunu artıran bir faktördür.

5 km boyunca kaliteli sürüş ile 150 km boyunca aynı kaliteyi korumak eşit başarı değildir.

Ancak kilometre yapmak tek başına bedava puan oluşturamaz.

Dayanıklılık:

**mesafe × korunabilen sürüş kalitesi**

mantığıyla çalışmalıdır.

Kısa sürüş maksimum dayanıklılık puanına ulaşamamalıdır.

Uzun fakat kötü sürüş de otomatik olarak yüksek dayanıklılık puanı alamamalıdır.

Başlangıç tasarımında örneğin:

* yaklaşık 5 km → düşük dayanıklılık potansiyeli,
* yaklaşık 50 km → yüksek potansiyel,
* yaklaşık 150 km+ → maksimuma yakın potansiyel

şeklinde doygunlaşan bir mesafe eğrisi kullanılabilir.

Kesin eğri gerçek sürüş verileriyle kalibre edilmelidir.

Ana prensip:

**DriveIt yalnızca ne kadar iyi sürdüğünü değil, bu kaliteyi ne kadar uzun süre koruyabildiğini ödüllendirir.**

---

# 7. Sürüş Akıcılığı — 100 Puan

Akıcılık diğer kategorilerdeki fren, gaz veya viraj hatalarını yeniden puanlamaz.

Tek temel soru:

**Sürücü seçtiği seyir hızını yol koşulları izin verdiği sürece ne kadar uzun ve istikrarlı koruyabiliyor?**

Frenleme, belirgin hızlanma, viraj, duruş ve trafik bölümleri akıcılık analizinden çıkarılmalıdır.

---

## 7.1 Seyir periyotları

Sürücü belirli bir hıza yerleştiğinde seyir periyodu başlatılır.

Hız bandı başlangıç kalibrasyonu olarak:

* 30–60 km/s → yaklaşık ±4 km/s
* 60–100 → ±6 km/s
* 100–150 → ±8 km/s
* 150+ → ±10 km/s

olabilir.

Kesintisiz olarak bu bant içerisinde geçirilen süre akıcılık değerini yükseltir.

Örneğin:

* 8 saniye → düşük katkı
* 30 saniye → iyi
* 2 dakika → çok iyi
* 5 dakika+ → çok güçlü

Bu süreler kalibrasyon değerleridir.

Sürücü bilinçli şekilde yeni bir hıza hızlandığında eski seyir periyodu ceza ile sonlandırılmaz.

Eski periyot kapanır.

Hızlanma ayrı kategoride değerlendirilir.

Yeni hıza yerleşildiğinde yeni seyir periyodu açılır.

---

# 8. Hızlanma & Gaz Performansı — 50 Puan

Dağılım:

* Saf Hızlanma Performansı: **25**
* Gaz Uygulama Kalitesi: **15**
* Hızlanma Sonu Kontrolü: **10**

---

## 8.1 Saf Hızlanma

Belirli hız aralıklarında kazanılan hız ve süre değerlendirilir.

Örneğin 30→70 veya 50→100 gibi hareketli hızlanma pencereleri kullanılabilir.

Araç gücü sonucu doğal olarak etkileyebilir ancak kategorinin tamamını domine etmemelidir.

Mümkün olduğunda sürücünün/araç kombinasyonunun kendi geçmiş performansı bağlam olarak kullanılabilir.

---

## 8.2 Gaz Uygulama Kalitesi

Hızlanma boyunca gereksiz gaz kesme, kararsızlık veya hızlanmanın tekrar tekrar bozulması değerlendirilir.

---

## 8.3 Hızlanma Sonu Kontrolü

Hedef seyir hızına ulaşıldıktan sonra aracın temiz şekilde seyire yerleşmesi değerlendirilir.

Ana prensip:

**DriveIt hızlanmanın gücünü ödüllendirir; tam puan için bu gücün temiz ve kontrollü kullanılması gerekir.**

---

# 9. Geçiş Kontrolü — 50 Puan

Dağılım:

* Seyir → Yavaşlama → Seyir: **20**
* Seyir → Viraj → Seyir: **20**
* Hızlanma → Seyir Yerleşmesi: **10**

Bu kategori **ceza kategorisi değildir.**

Başarılı sürüş fazı kombinasyonlarına pozitif puan verir.

---

## 9.1 Seyir → Yavaşlama → Seyir

Sürücünün mevcut seyir temposundan kontrollü şekilde farklı bir seyir temposuna yerleşebilmesi değerlendirilir.

Frenin kendisi burada yeniden puanlanmaz.

---

## 9.2 Seyir → Viraj → Seyir

Viraj performansından bağımsız olarak sürücünün seyirden viraj fazına ve ardından yeniden seyire ne kadar temiz bağlandığı değerlendirilir.

---

## 9.3 Hızlanma → Seyir

Hızlanmanın gücü yeniden değerlendirilmez.

Sürücünün hızlanma sonrasında hedef hız çevresinde ileri-geri arama yapmadan kararlı seyire yerleşmesi ödüllendirilir.

Ana prensip:

**Geçiş Kontrolü sürüş fazlarının performansını tekrar değerlendirmez; bu fazların birbirine ne kadar temiz bağlandığını ödüllendirir.**

---

# 10. Nihai Drive Score

Nihai skor:

**Frenleme & Öngörü**

* **Tempo & Performans**
* **Viraj Performansı**
* **Sürüş Dayanıklılığı**
* **Sürüş Akıcılığı**
* **Hızlanma & Gaz Performansı**
* **Geçiş Kontrolü**

sonucunda maksimum **1000 puandır.**

Hiçbir kategori kendi maksimum değerinin üzerine çıkamaz.

---

# 11. Kalibrasyon İlkesi

Bu anayasadaki:

* m/s² eşikleri,
* saniye pencereleri,
* hız toleransları,
* trafik güven eşikleri,
* mesafe eğrileri,
* olay ağırlıkları

ilk implementasyon için başlangıç değerleridir.

Bunlar anayasanın temel felsefesini değiştirmeden gerçek DriveIt sürüş verileriyle kalibre edilebilir.

Ancak aşağıdaki prensipler kalibrasyon adı altında değiştirilemez:

1. Frenleme sistemin ana ağırlığıdır.
2. Zorunlu trafik davranışı doğrudan cezalandırılamaz.
3. Duruşlar Ortalama Seyir Hızından çıkarılır.
4. Duruşlar Mesafe/Süre Performansından çıkarılmaz.
5. Viraj geometrisi dikkate alınır.
6. Yüksek lateral G doğrudan ödüllendirilmez.
7. Mesafe tek başına Dayanıklılık puanı üretmez.
8. Akıcılık yalnızca geçerli seyir periyotlarını değerlendirir.
9. Aynı hata birden fazla kategoride tekrar cezalandırılmaz.
10. Tek GPS örneği ağır puan kararı veremez.
11. Geçiş Kontrolü pozitif başarı kategorisidir.
12. Toplam Drive Score maksimum 1000 puandır.

---

# 12. DriveIt Drive Score Felsefesi

Drive Score'un amacı kullanıcıyı mümkün olan en yüksek hıza teşvik etmek değildir.

Aynı şekilde kullanıcıyı yapay şekilde yavaş sürmeye zorlamak da değildir.

Sistem;

**tempo + öngörü + kontrol + momentum + akıcılık + dayanıklılık**

birleşimini değerlendirmelidir.

En yüksek Drive Score;

**gerektiğinde hızlı, gerektiğinde yavaş; mümkün olduğunca öngörülü, kontrollü ve akıcı sürüş yapan ve bu kaliteyi uzun mesafe boyunca koruyabilen sürücüye ait olmalıdır.**
