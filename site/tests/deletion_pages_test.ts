function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
function includes(value: string, expected: string, message: string) {
  assert(value.includes(expected), message);
}

Deno.test('Google Play deletion resource identifies DriveIt and clearly reports an unavailable request path', async () => {
  const page = await Deno.readTextFile('site/account-deletion/index.html');
  includes(page, '<title>DriveIt', 'DriveIt app name must be present');
  includes(page, 'Hesap silme talebi', 'deletion request page must identify the process');
  includes(page, 'Başvuru kanalı hazır değil', 'unavailable request channel must be explicit');
  assert(!page.includes('mailto:'), 'unverified support email must not be active');
  assert(!page.includes('driveit.osaracx@gmail.com'), 'disabled Gmail must not be shown');
  includes(page, 'Parola, doğrulama kodu, oturum bağlantısı', 'page must forbid sending secrets');
  includes(page, '../privacy/', 'privacy link must be present');
  includes(page, 'kişisel bulutta saklanan sürüş kayıtları', 'cloud drive data category must be disclosed');
  includes(page, 'yerel sürüş arşivini uzaktan silemez', 'local archive limitation must be clear');
  includes(page, 'Saklama sınırları', 'undecided retention limits must be visible');
  includes(page, 'blocked_planet', 'Planet blocked deletion must not claim completion');
  assert(!page.includes('id="copy-email"'), 'unavailable contact address must not have a copy action');
  assert(!page.includes('copy-email.js'), 'disabled contact helper must not be loaded');
  assert(!/name=["'](?:password|token|gps|route)["']/i.test(page), 'page must not collect credentials or location data');
});

Deno.test('account deletion static package has no automatic publication and minimal browser permissions', async () => {
  const script = await Deno.readTextFile('site/account-deletion/copy-email.js');
  assert(script.includes('navigator.clipboard.writeText(address)'), 'copy action should use the clipboard only after user click');
  assert(script.includes("addEventListener('click'"), 'clipboard write must be user initiated');
  assert(!/fetch\s*\(|XMLHttpRequest|sendBeacon|localStorage|sessionStorage/i.test(script), 'copy script must not send or persist user data');
  const workflow = await Deno.readTextFile('.github/workflows/publish-account-deletion-site.yml');
  assert(workflow.includes('workflow_dispatch:'), 'publication must be manual only');
  assert(!/\n\s*(push|pull_request):/.test(workflow), 'push and pull requests must not publish the site');
  assert(workflow.includes('inputs.confirm_publication == true'), 'publication confirmation must be enforced for every job');
  assert(workflow.includes('path: site'), 'only the reviewed site package should be uploaded');
});

Deno.test('privacy page is visibly a draft and separates device, private cloud and Planet data', async () => {
  const page = await Deno.readTextFile('site/privacy/index.html');
  includes(page, 'HUKUKİ İNCELEME BEKLİYOR', 'draft must be marked as unapproved');
  includes(page, 'yerel sürüş geçmişi', 'local archive must be distinguished');
  includes(page, 'Kişisel bulut yedeklemesi Gezegen\'e herkese açık yayın anlamına gelmez', 'private sync and public sharing must be distinct');
  includes(page, 'henüz hukuken karara bağlanmamıştır', 'unresolved retention must be disclosed');
  assert(!page.includes('mailto:'), 'unverified support email must not be active');
  assert(!page.includes('driveit.osaracx@gmail.com'), 'disabled Gmail must not be shown');
  includes(page, 'Doğrulanmış iletişim', 'missing verified contact route must be disclosed');
});
