# R4 — oturum sonrası hesap silme kurtarma erişimi

Hosted servis kabulü sonrasında gerçek istemci composition'ında bir erişim engeli bulundu: Play deletion runtime'ın hem ekran görünürlüğü hem controller oluşturması canlı account lease istiyordu. Sunucu Auth'u iptal ettiğinde receipt-only transport çalışsa bile kullanıcı kurtarma ekranını açamıyordu.

Yeni destructive istek için mevcut `enabled`, parola/onay ve owner/epoch/gateway kontrolleri korunur. Ayrı `recoveryEnabled`, yalnız zaten initialize edilmiş, doğru PROD/public-key ortamında ve mevcut kapalı feature flag altında kurtarma ekranına erişim sağlar. Controller oluştururken eager lease kontrolü kaldırılır; `request` sırasında gateway factory ve authorize guard yine canlı lease ister. `run` yalnız mevcut endpoint/owner receipt'i kullanır; başka kullanıcının JWT'si taşınmaz.

Profilde guest/logout kurtarma düğmesi bu ayrı recovery kapısına bağlanmıştır. Başka hesap giriş yapmışsa onun bağlamından A receipt'i açılmaz. Feature gate, Play Auth, hukuki onboarding veya hosted ayar açılmadı. Hive/SQLite/GPS journal biçimi ve kayıtlar değiştirilmedi.

Doğrulama: silme controller + gerçek SDK/lifecycle transport 18/18 PASS; mevcut profil ve PlayAuth kapalı gate regresyonları 9/9 PASS. Bunlar tüm gerçek Android ekran/cihaz kabulünü kapsamaz. Tam flutter analyze mevcut 3 warning + 4 info baseline ile eşleşti; yeni bulgu yok, baseline nedeniyle exit 1.

R4'ün kalan aktivasyon kabulü: onaylı gerçek Site URL, gerçek e-posta/callback testi, nihai hukuki metin/sürüm onayı ve kontrollü gerçek cihaz kabulü. Mevcut Site URL localhost; exact Play callback allowlist girdisi vardır. Bu çalışma tüm Play Auth runtime'ını etkinleştirmez.
