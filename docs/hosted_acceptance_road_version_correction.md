# Hosted kabul öncesi — Planet silme sürüm düzeltmesi

İki sentetik PROD hesabı ile test için kullanıcı onayı alındı. Hesap oluşturmadan yapılan kaynak karşılaştırmasında bir üretim sözleşmesi hatası bulundu. İlk teşhis sırasında PROD değişmedi. Daha sonra ayrı kullanıcı onayıyla iki correction ve yalnız delete-account dağıtıldı; güncel sonuç `hosted_acceptance_result.md` içindedir.

## Kanıt ve etki

- Yayın yolu `world_validation.ts` → `roadPayload` ile `validatedRoadProcessingVersion=3` üretir. World rules sürümü ise ayrı bir alan olarak 6'dır.
- Deployed silme SQL context ve Edge replay yanlışlıkla road processing 6 bekliyordu. Ortak katkı bulunan gerçek sürüm3 yollarda silme `blocked_planet`/unsupported-road durumuna takılabilir. Önceki servis fixture'ları da road/generation/trace alanlarına 6 yazarak bu farkı örtmüş.
- Yeni gerçek sürüm3 Deno testi düzeltme öncesi `planet_rebuild_unsupported_road` ile FAIL oldu. Sürüm6'nın aynı şey olmadığını doğrulayan negatif test de eklendi.
- Replay sonrası generation metadata'sında da 6 yazıldığı bulundu. Bu alan için ikinci ayrı ileri migration hazırlandı; uygulanmış eski migration'lar değiştirilmedi.

## Yerel çözüm

- Edge replay, yayın yolunun aynı `rules.validatedRoadProcessingVersion` sabitini kullanır. Kaynak algoritması, legacy/reliable skor kuralları, sahiplik, lease ve güvenlik limitleri değişmez.
- `202611020001` yalnız context yol-sürüm kontrolünü, `202611020002` yalnız yeni replay generation sürüm metadata'sını düzeltir. İki migration yalnız ayrı açık onayla dağıtılabilir.
- İki correction ayrı manifestte hash'lidir; temel25 ve önceki ek25 migration hash/geçmişi korunur. Birleşik artifact tam50 geçmiş önkoşulu, tek transaction, iki history insert, final52/kapalı gate kontrolleri içerir. Varsayılan araçlar dry-run'dır.
- Servis fixture'ları mevcut gerçek road/generation/trace sürümü3'e geçti. Çelişkili sahiplik testinde yalnız retryable yanıtlar aynı receipt ile en fazla üç kez denenebilir; **her yanıtta** A Auth/çelişkili geometry ve B özel sürüşlerinin korunduğu kontrol edilir. Completed yanıtı kabul edilmez.

## Doğrulama durumu

- Deno replay ve schema2 processing: 14/14 PASS. Transaction builder: 5/5 PASS. Hazırlık: 12/12 PASS.
- Gerçek ayrı PostgreSQL'de birleşik correction rollback ve commit: PASS; history52, canonical road/generation sürümü3 ve gate FALSE. Önceki yerel referans silinmedi/sıfırlanmadı.
- Yerel SQL test çalıştırıcısında Türkçe kültürün case-insensitive COMMIT eşleşmesini etkilemesi tespit edildi. İlk test başarısızlığı saklanmadı; etkilenen referans korundu, yeni fiziksel referansta generated uppercase transaction artifact'ıyla birleşik rollback/commit kabulü tamamlandı.
- Önceki ara servis turu 26/27 kaldı (consent). Tekil tekrar 1/1 geçti; bu tek başına tam kabul sayılmadı. İki ileri düzeltme ve güncel assertion'larla son tam servis paketi **27/27 PASS**, exit 0, 5m47s. Son test sentetik temizlik ve kapalı gate'leri doğruladı. Bu sonuç önceki aralıklı başarısızlıkların tüm kök nedenlerinin çözüldüğü iddiası değildir.

Bu kaydın ardından ayrı deployment onayı alındı ve düzeltme uygulandı. Hosted servis kabulü tamamlandı; `hosted_acceptance_result.md` sonuç ve sınırlamaları gösterir. Signup/Group Drive/worker cron ve hukuki onboarding kapıları korunur.
