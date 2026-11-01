/**
 * Repository-local consistency guard for the P-GR6G legal-review packet.
 * Lexical/source-presence check only; it is not legal approval or semantic proof.
 */
const files = [
  "docs/privacy_review/pgr6g_data_inventory.md",
  "docs/privacy_review/privacy_policy_draft_tr.md",
  "docs/privacy_review/kvkk_information_notice_draft_tr.md",
  "docs/privacy_review/account_deletion_and_retention_draft_tr.md",
  "docs/privacy_review/retention_destruction_matrix.md",
  "docs/privacy_review/google_play_data_safety_inventory.md",
  "docs/privacy_review/legal_decisions_pending.md",
];

const checks: Array<[string, string, string]> = [
  ["Android background permission", "android/app/src/main/AndroidManifest.xml", "ACCESS_BACKGROUND_LOCATION"],
  ["Android backup exclusions", "android/app/src/main/res/xml/account_deletion_backup_rules.xml", "FlutterSecureStorage.xml"],
  ["Android transfer backup exclusions", "android/app/src/main/res/xml/account_deletion_extraction_rules.xml", "device-transfer"],
  ["Local GPS SQLite", "lib/services/gps_session_store.dart", "driveit_gps_sessions.db"],
  ["Owner-scoped local data", "lib/services/owner_scoped_local_store.dart", "owner_sync_outbox_v1"],
  ["Mapbox route transfer", "lib/features/my_world/providers/mapbox/mapbox_road_matching_provider.dart", "matching/v5/mapbox/driving"],
  ["Planet profile broad read policy", "supabase/prod/bootstrap/202609220001_canonical_planet_base.sql", "Authenticated users can read profiles"],
  ["Planet private source bucket", "lib/features/world_publish/services/world_publish_source_upload_service.dart", "world-drive-sources"],
  ["Onboarding legal placeholder", "lib/features/onboarding/screens/legal_safety_onboarding_page.dart", "placeholder içerik"],
  ["Account deletion 24h candidate pruning", "supabase/account-deletion/migrations/202611010002_account_deletion_audit.sql", "interval '24 hours'"],
  ["Transient subject email candidate", "supabase/account-deletion/migrations/202611010009_account_deletion_auth_lifecycle.sql", "owner_email"],
];

const lawUrls = [
  "https://www.kvkk.gov.tr/Icerik/5441/KISISEL-VERILERIN-SILINMESI-YOK-EDILMESI-VEYA-ANONIM-HALE-GETIRILMESI-HAKKINDA-YONETMELIK",
  "https://www.kvkk.gov.tr/Icerik/9024/ilgili-kisilerin-basvurularina-verilecek-cevabin-bildirim-usulune-iliskin-kamuoyu-duyurusu",
  "https://support.google.com/googleplay/android-developer/answer/10787469?hl=en",
];

let failures = 0;
for (const relative of files) {
  try {
    const body = await Deno.readTextFile(relative);
    if (!body.includes("ONAY BEKLİYOR")) {
      console.error(`FAIL: legal review marker missing: ${relative}`);
      failures++;
    }
    if (body.trim().length < 300) {
      console.error(`FAIL: unexpectedly short document: ${relative}`);
      failures++;
    }
  } catch {
    console.error(`FAIL: required document missing: ${relative}`);
    failures++;
  }
}

for (const [label, path, needle] of checks) {
  try {
    const source = await Deno.readTextFile(path);
    if (!source.includes(needle)) {
      console.error(`FAIL: evidence anchor missing (${label}): ${path}`);
      failures++;
    }
  } catch {
    console.error(`FAIL: evidence source missing (${label}): ${path}`);
    failures++;
  }
}

for (const url of lawUrls) {
  const corpus = await Promise.all(files.map((f) => Deno.readTextFile(f)));
  if (!corpus.some((doc) => doc.includes(url))) {
    console.error(`FAIL: source URL absent from packet: ${url}`);
    failures++;
  }
}

if (failures) {
  console.error(`P-GR6G consistency check: FAIL (${failures} finding(s))`);
  Deno.exit(1);
}
console.log(`P-GR6G consistency check: PASS (${files.length} docs, ${checks.length} evidence anchors, ${lawUrls.length} cited source URLs)`);
console.log("Scope: lexical presence only; legal and runtime validation remain pending.");
