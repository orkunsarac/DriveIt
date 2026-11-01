# P-GR7I 4C — profil için owner kapsamlı istemci

Bu aşama Play Auth'u veya başka bir bulut özelliğini açmaz. Profil yolu için bağımsız istemci üretim koduna bağlandı; diğer veri yolları bu istemciye taşınmış değildir.

Play profil işlemlerinde `OwnerProfileGateway` onaylı hesap UID'si, lease/epoch, PROD HTTPS hedefi, public anahtar ve SDK oturumunun token'ını birlikte kontrol eder. Her işlem için ayrı istemci ve sabit token kullanılır; istek öncesi ve sonrası bağlam kontrol edilir. Profil servisi sonucu yayımlamadan önce bağlamı tekrar kontrol eder. SDK kimliği veya epoch değiştiğinde eski profil getter üzerinden gösterilmez. Aynı UID token yenilenirse zaten başlayan eski işlem reddedilir; yeni işlem yeni token alır. DEV profil erişimi eski istemcisini kullanır.

Planet harita ve detay, World yayın/işleme/kaynak yükleme, hesap silme, owner sync ve Group servisinin Play kompozisyonunda ortak istemcili yolları ayrıca kapalıdır. Bunlar owner-scoped olarak uygulanmış değildir; uygulama genelinde izolasyon kabulü değildir. Play Auth bootstrap hardcoded kapalı kalır. Server tarafında geçerli kalmış bir A tokenıyla geçişten önce sunucuya ulaşmış işlem geri alınamaz; sonuç yerelde reddedilir.

Gerçek SDK ve sentetik HTTP ile profil A okuması, A isteği sürerken SDK B değişimi, B tokenıyla A isteği başlatılmaması, geç yanıtın reddi, B profili, epoch değişimi, SDK refresh, logout, SDK session restore ve profil güncellemesi sınandı. Test sahibi/epoch kontrolünü enjekte eder; gerçek Android lifecycle, gerçek LocalOwnerLease ile SDK eşzamanlı entegrasyonu, aktif GPS callback/restart ve hosted sunucu testleri bu testin kapsamında değildir. Mevcut owner entegrasyon testleri ayrıca çalıştırıldı.

Üretim aktivasyonu öncesi gerçek owner lifecycle ile callback/soğuk başlangıç testleri ve diğer tüm veri yollarının ayrı entegrasyonu gerekir. Public anahtar biçimi projenin anahtar sahipliğinin kanıtı değildir. Mevcut hukuki onboarding, Play build guard ve diğer feature gate'ler değiştirilmedi.
