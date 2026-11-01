# P-GR6G — Hukuki ve ürün kararları

Tüm maddeler **ONAY BEKLİYOR**; bu liste hukuki görüş değildir.

1. **Veri sorumlusu kimliği:** şirket/gerçek kişi, adres, iletişim, yetkili başvuru kanalı ve gerekiyorsa VERBİS/KVKK kayıt durumu.
2. **Amaç ve hukuki sebep:** GPS, arka plan konumu, hesap/e-posta, yerel sürüş, hesap bulutu, Planet, Mapbox, Google Maps, destek ve güvenlik loglarının her biri için ayrı hukuki dayanak; açık rıza gerekiyorsa isteğe bağlı ve hizmetten ayrıştırılmış akış.
3. **Background location:** sürüş kaydı uygulama arka plandayken/ekran kapalıyken sürüyor mu, hangi feature gerektiriyor, foreground service açıklaması ve Android 11+ arka plan izni eğitim ekranı. Şu an manifestte background izni var; onboarding bu davranışı açıklamıyor.
4. **Profil görünürlüğü:** authenticated kullanıcıların tüm profile satırlarını okuyabilmesi beklenen ürün davranışı mı? Username/display_name/avatar alanları public-ish kabul edilecek mi; e-posta hiçbir profile response'a sızmamalı; alan bazlı erişim ve enumeration önlemi.
5. **Planet kapsamı:** kullanıcıya hangi rota/telemetri alanları aktarılır; yayın kimlikle mi gösterilir; yayın geri alma; ortak yol bölümünde diğer kullanıcı katkılarının korunması; kaynak GPS'in, derived geometry'nin ve yedeklerin silme/recompute modeli. `blocked_planet` güvenli kilidi ve genel Planet yazı kilidi.
6. **İmha audit:** KVKK Yönetmeliği m.7/3 en az 3 yıl kayıt şartının hangi DriveIt imha işlemlerine uygulanacağı; kayıt için minimum alanlar; `account_deletion_prune_receipts` adayındaki 24h pruning'in çatışması. Ham email/UID/GPS yerine pseudonymous vaka numarası, timestamp, işlem sonucu; tekrar tanımlama anahtarının gerekip gerekmediği.
7. **Yanıt süresi/başvuru:** 30 günlük üst sınır için vaka alım, kimlik doğrulama, eksik başvuru ve ret gerekçesi prosedürü; `driveit.osaracx@gmail.com` yetkili ve güvenli başvuru kanalı olacak mı.
8. **Yerel cihaz ve Android backup:** SQLite/Hive sürüşleri cloud backup/device transfer'e dahil mi; hesap silme yerel veriyi kapsıyor mu; UI'da kullanıcıya ayrı temizleme adımı verilecek mi. Şu an rules sürüş DB/box'larını exclude etmiyor.
9. **Retention ve backup:** Supabase log retention, backup aralığı/expire, Storage kopyası, restore sonrası silme replay, Gmail case retention, yerel cihaz verisi için süre. Her süre için teknik kontrol sahibi atanmalı; mevzuatta belirtilmeyen süre uydurulmamalı.
10. **Yurt dışına aktarım/alt işleyen:** Supabase Frankfurt, Supabase alt işleyenleri, Mapbox, Google Maps/Gmail konumları; KVKK m.9 uygun mekanizma, DPA, SCC/taahhüt ve bildirim gereksinimi.
11. **Play beyanı ve yayın kapıları:** exact release build flags/SDK listesi, Data Safety form answers, background location declaration, gizlilik policy URL ve account deletion URL. Placeholder onboarding metinleri değiştirilmeden/gerçek metinler gösterilmeden kabul verilmemeli.
12. **Silme worker operasyonu:** kimlik challenge, operator MFA/role, başarısız/blocked işlemin kullanıcıya bildirimi, idempotent retry, terminal ACK ve backup purge kanıtı.
13. **Üçüncü taraf sağlayıcı:** Google Maps SDK ve Mapbox'ın veri alanları, amaçları, saklama süresi ve SDK Data Safety sorumlulukları dokümante edilip sürüm bazında güncellenecek.
