# P-GR7I 4C — gerçek SDK ve owner lifecycle kabulü

Dar kapsam: owner-scoped profil okuma/güncelleme; Play Auth ve diğer bulut gate'leri kapalı kalır. Testler gerçek Supabase SDK, SupabaseLocalOwnerAuth, LocalOwnerLifecycle, LocalOwnerLease, izole Hive/SQLite GPS journal ve sentetik HTTP kullanır. Gateway testte gerçek owner'ın lease/epoch erişicileriyle oluşturulur; Android composition/bootstrap çalıştırılmaz.

| Kontrol | Sonuç / kanıt |
| --- | --- |
| A profili, A→B, SDK B iken lease A | PASS: senkron SDK olayı sırasında bu pencere ve profil reddi gözlendi. |
| Geç A yanıtı ve credential | PASS: bekletilen A HTTP isteği A token kullandı; B oturumu altında A yanıtı reddedildi. |
| B hazırlanana kadar ve sonrasında | PASS: B hazırlığı bekletildi, profil ve iki güncelleme reddedildi; lease açılınca B profili ve güncellemeler çalıştı. |
| Bildirim ve önbellek | PASS: owner geçişinde görünür A profilinin kapatılması ve B hazır olduğunda otomatik yükleme test edildi. |
| Aktif ve kurtarılabilir GPS | PASS: sentetik SQLite journal/sidecar ile B geçişi blocked, bağlanmış kayıt A'da kaldı. Native servis veya fiziksel GPS test edilmedi. |
| Logout, refresh, restore | PASS: gerçek SDK olayları, guest lease ve aynı UID refresh epoch koruması. |
| Cold start / restart | PASS: yeni SDK ve yeni lifecycle ile sentetik session restore ve A lease yeniden açılması; Android süreç yaşam döngüsü test edilmedi. |
| Hatalı/tekrarlanan callback | PASS: aynı hatalı SDK callback iki kez reddedildi, session ve lease değişmedi. Başarılı PKCE bağlantısının replay davranışı NOT TESTED. |
| Başarısız owner açılması | PASS: gerçek SDK ile B owner deposu hatası, eski lease reddi, profil erişim engeli ve başarılı retry. |

Gerçek lifecycle testinde iki sorun giderildi: in-flight profil yüklemesi owner/epoch değişiminde yeni işlem tarafından yeniden kullanılmaz; owner hazır olduğunda hesap servisi profili yeniden yükler ve geçişte eski profili temizler. UI metadata getter'ı da owner hazır değilken değer göstermez. Test donanım ya da hosted sistemlerde veri değiştirmez.

Gerçek SDK/lifecycle ve ilgili regresyonlar: 58 PASS, exit 0. Bu test Play Auth'un bütününe, gerçek Android callback teslimine veya Planet/Storage/sync erişimlerinin etkinleştirilmesine kabul sağlamaz.
