# P-GR7I Aşama 3 — Play Auth runtime güvenlik hazırlığı

**Durum: KISMEN / PROD AUTH ETKİN DEĞİL.** Gerçek Play Auth composition ve hosted Auth kabulü tamamlanmadı. Mevcut Play guard Supabase yapılandırması ve owner activation define'larını reddeder; Android `MainActivity.kt` local production owner marker'ı yalnız eski paket için doğrular. Bunlar bu aşamada değiştirilmedi. Play Auth kaynak gate'i sabit `false` olduğundan sentetik dart-define ile açılamaz.

## Yapılan değişiklik

- `lib/config/play_auth_runtime_policy.dart` ve `supabase_bootstrap.dart`: Play için Auth bootstrap kapalı gate'i denetlenir; mevcut public-key ve paket/proje kontrolleri devam eder. İleride açılması yeni, incelenmiş kod ve release guard/composition çalışması gerektirir.
- `lib/services/supabase_account_service.dart`: Play Auth gelecekte başlatılmış olsa bile explicit signup/login/logout gibi `_identityChange` işlemleri bağlı owner runtime yoksa fail-closed durur. Owner bağlıysa mevcut `authorizeIdentityChange` fencing kullanılır. DEV/legacy yolu korunur.
- Bootstrap, account service ve owner Auth normal uygulama akışında `Supabase.instance.client` kullanır. Bu kod düzeyinde ortak client kanıtıdır; Play için çalışan composition veya hosted kabul kanıtı değildir.

## PASS / NOT TESTED

| Kontrol | Durum / kanıt |
| --- | --- |
| Play Auth varsayılan kapalı; Play owner bağlanmadan explicit identity change reddi | PASS: `test/play_auth_runtime_policy_test.dart`; Play gate kaynakta sabit false. |
| Proje, public key, callback ve PKCE recovery isteği | PASS: sentetik policy ve MockClient testleri. Gerçek hosted callback/token doğrulaması NOT TESTED. |
| Guest/account owner, epoch, logout/switch ve GPS fencing | PASS: sentetik owner lifecycle/GPS testleri; gerçek Play owner composition NOT TESTED. |
| Signup/login ve profil akışı | KISMEN: mevcut widget/gateway mock testleri geçti. Gerçek veya izole Auth sunucusuyla bu turda uçtan uca signup/login/session restore/profile testi yapılmadı. |
| Eski profilin session değişiminde temizlenmesi | KISMEN: mevcut `SupabaseAccountService.startIdentitySync` ve profile testleri; gerçek SDK session değişimiyle Play cihaz testi NOT TESTED. |
| Callback sırasında owner fencing | NOT TESTED / ENGEL: SDK callback session değişimi `_identityChange` wrapper'ından geçmez. Aktif GPS ve A→B koşullarında güvenli sıra kanıtlanmadan Play Auth açılmamalı. |
| Hosted PROD/DEV, gerçek e-posta ve cihaz | NOT TESTED: bu görevde bağlantı/yazma veya cihaz işlemi yapılmadı. |

Hedefli Flutter testleri **92 geçti / exit 0**; son gate değişikliğinden sonra Auth gate ve PKCE testleri ayrıca **3 geçti / exit 0**. `flutter analyze --no-pub` **exit 1**, önceki baseline ile aynı 3 warning + 4 info; yeni bulgu görülmedi. `pending_legal_review`, owner activation, sync, Planet, Group ve deletion worker gate'leri değiştirilmedi.

## Aktivasyon öncesi engeller

1. Callback/session restore dahil bütün kimlik değişimlerini GPS/owner lease ve epoch ile sıralayan, eski profili anında temizleyen güvenli composition tasarlanıp gerçek SDK ile sentetik test edilmeli.
2. Play native marker, owner root ve Supabase client bağlanması kapalı gate altında test edilmeli; yanlış package/project ve eksik config'te fail-closed kanıtlanmalı.
3. R1 release guard ve signing değişiklikleri korunarak gelecekteki ayrı onaylı rollout hazırlanmalı; bu aşamada guard gevşetilmez.
4. Yerel Auth/HTTP signup, login, restore, logout, recovery, profile ve A/B hesap testleri tamamlanmalı; sonra hosted ve cihaz kabulü ayrı yetkiyle yapılmalı.
