function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
function includes(value: string, expected: string, message: string) {
  assert(value.includes(expected), message);
}

Deno.test('Google Play deletion resource identifies DriveIt and provides an external request path', async () => {
  const page = await Deno.readTextFile('site/account-deletion/index.html');
  includes(page, '<title>DriveIt', 'DriveIt app name must be present');
  includes(page, 'Hesap ve verilerin silinmesini isteyin', 'deletion request must be prominent');
  includes(page, 'mailto:driveit.osaracx@gmail.com', 'external request email must be usable');
  includes(page, 'Auth hesabındaki doğrulanmış adrese', 'verification must target registered address');
  includes(page, 'Parola, doğrulama kodu, oturum bağlantısı', 'page must forbid sending secrets');
  includes(page, '../privacy/', 'privacy link must be present');
  assert(!/name=["'](?:password|token|gps|route)["']/i.test(page), 'page must not collect credentials or location data');
});

Deno.test('privacy page is visibly a draft and separates device, private cloud and Planet data', async () => {
  const page = await Deno.readTextFile('site/privacy/index.html');
  includes(page, 'HUKUKİ İNCELEME BEKLİYOR', 'draft must be marked as unapproved');
  includes(page, 'yerel sürüş geçmişi', 'local archive must be distinguished');
  includes(page, 'Kişisel bulut yedeklemesi Gezegen\'e herkese açık yayın anlamına gelmez', 'private sync and public sharing must be distinct');
  includes(page, 'henüz hukuken karara bağlanmamıştır', 'unresolved retention must be disclosed');
});
