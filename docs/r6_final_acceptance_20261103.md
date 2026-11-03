# DriveIt R6 son kabul ve Play aday hazırlığı — 2026-11-03

Başlangıç checkpoint'i `fbfa9fd` (`feature/gps-refactor`). Bu rapor DEV'de yeni migration/Function dağıtımı veya PROD işlemi yapmaz. R6-A/B kapsamındaki mevcut migration, yedek, restore ve Function kabulleri yeniden uygulanmamıştır.

## Durum özeti

| İş | Durum | Kanıt / sınır |
|---|---|---|
| DEV signup kapatma | **PASS** | Yalnız DEV `viqngnjfgknpxtoapzcg` Auth config'inde `disable_signup=true`. Read-only sonrası kontrol: email provider açık, anonymous users kapalı, mailer autoconfirm ve redirect allowlist aynen kaldı. Mevcut hesap/oturum/veri silinmedi. PROD'a dokunulmadı. |
| DEV gerçek hesap/servis kabulü | **BLOCKED** | Yetkili Auth/test kullanıcısı veya onaylı istemci bağlantısı yok. Management token test kullanıcısı kimlik bilgisi değildir. Anahtar değerlerini almak/alternatif yerlerden çıkarmak denenmedi. A/B, gerçek delete-account receipt/purge, Storage temizliği, Planet read/publish/schema2 için kullanıcı tarafından onaylı test erişimi gerekir. Önceki otomatik güvenlik reddi DEV API key'lerini reveal etmeye yönelikti; bu yol kullanılmadı. |
| Emulator process-death / session restore-refresh | **PASS (sentetik HTTP)** | Ayrı paket `com.example.driveit_project.isolated_test`, emulator `emulator-5554`, user 10. Gerçek Android secure storage/Keystore ve uygulama bootstrap'ı. `force-stop` sonrası aynı paketi yeniden açınca `RESTORED owner=A`; önceki süreçte refresh endpoint'i çağrılarak `ROTATED owner=A`. Supabase HTTP cevabı sentetik `example.invalid`; gerçek DEV Auth kabulü değildir. A55 mevcut değil. |
| Android GPS owner / local data | **PASS (emülatör/yerel)** | İzole Android integration tests: `gps_ownership_android_test.dart` (GPS journal/sidecar version 3) + `owner_scoped_storage_android_test.dart`; **2 passed** on `emulator-5554`. Fiziksel GPS sensörü veya gerçek cloud kullanımı değil. A55 bağlı değildi. |
| Flutter Auth/owner/GPS/cloud hedefli regresyon | **PASS** | `flutter test --no-pub` üzerinde 13 hedefli test dosyası; **125 passed, 0 failed**. Kapsam owner session restore/refresh, SDK mutation sırası, callback, GPS sahipliği/restart, password recovery, upload/download lifecycle, sync causality ve Play Auth policy. HTTP/provider davranışları bu set içinde sentetik/lokal testtir. |
| Web privacy/deletion taslakları | **PASS (statik test)** | Kapalı Gmail ve `mailto:` kaldırıldı; hesap silme sayfası açıkça çalışan talep kanalı sunmadığını söylüyor. Deno: `site/tests/deletion_pages_test.ts` — 3 passed. Sayfalar yayımlanmadı. |
| R1 Play Gradle / release guard | **PASS (guardlar)** | `tool/test_play_release_guards.ps1` exit 0: normal package/location permissions, isolated package identity, unconfigured AAB refusal, missing signing refusal, DEV Supabase rejection ve Play mode debug rejection. Kaynak adayı `com.osaracx.driveit`, target SDK 36, `1.0.1+2`; imzalı AAB üretilmedi. Play Console versionCode/uygulama kaydı salt okunur doğrulanmadı. |
| Yeni imzalı AAB / 16 KB | **BLOCKED** | Repo dışında mevcut upload keystore dosyası var; dosyaya dokunulmadı. Bu build oturumunda gerekli alias/parolalar ve bundletool yolu güvenli process inputs olarak yoktu. Keystore ile Play Console upload certificate eşleşmesi bu görevde doğrulanmadı. Eski `1.0.0+1` AAB yeni kaynak için build kanıtı sayılamaz. |
| Hukuki / yayın gereklilikleri | **BLOCKED** | Gizlilik/KVKK/kullanım/hesap silme metinleri ve Data Safety taslağı güncel; onaylı veya yayımlanmış değil. Doğrulanmış iletişim adresi/silme kanalı yok. Veri sorumlusu bilgileri, amaç/hukuki sebep/aktarım/saklama kararları, Play Data Safety formu, account deletion URL ve background location açıklama/onboarding kabulü açık engel. Play Console'a yükleme yapılmadı. |

## R1 kaynak değişikliği

- Play applicationId yalnız açık release lane ile `com.osaracx.driveit`; normal ve `.isolated_test` kimlikleri ayrıdır.
- Play AAB, external upload signing ister; debug signing ile bundle üretilmesini reddeder. DEV Supabase config ve doğrulanmamış feature opt-in'leri reddedilir. Signup/Group Drive/owner activation/sync/deletion kapıları açılmamıştır.
- Aday version `1.0.1+2`; Play Console kullanılabilirlik kontrolü şarttır.
- `http` runtime dependency ve lockfile tutarlılığı; private signing dosya ignore kuralları seçici R1 kapsamındadır.
- Yerel AAB üretimi bilinçli şekilde denenmedi; kullanıcı/anahtar sahibinden güvenli build oturumunda signing inputs ve Play certificate eşleşme teyidi bekleniyor.

## Bu görevde kullanıcıdan gereken dış girdiler

1. DEV testleri için onaylı geçici test erişim yöntemi veya önceden sağlanmış sınırlı istemci credential akışı. Token/secret chat'e veya dosyaya yazılmamalı.
2. Play Console'da `com.osaracx.driveit` kayıt ve son versionCode doğrulaması, upload certificate fingerprint eşleşmesi.
3. Repo dışı upload keystore'u kullanmak için alias/parolaları yalnız etkileşimli, güvenli build prompt'una girmek; bu değerlere ajan logu veya repository erişimi verilmemeli.
4. Yetkili destek/hesap silme başvuru kanalı, hukuki metin onayı ve gerekli politika/Data Safety kararları.
