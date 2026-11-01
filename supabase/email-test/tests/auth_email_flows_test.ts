function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
function eq(actual: unknown, expected: unknown, message: string) {
  assert(actual === expected, `${message}: expected ${String(expected)}, got ${String(actual)}`);
}

const api = Deno.env.get('DRIVEIT_EMAIL_TEST_API')!;
const mailpit = Deno.env.get('DRIVEIT_MAILPIT_API')!;
const anon = Deno.env.get('DRIVEIT_EMAIL_TEST_ANON')!;
const service = Deno.env.get('DRIVEIT_EMAIL_TEST_SERVICE')!;
assert(api.startsWith('http://127.0.0.1:'), 'Auth target must be loopback');
assert(mailpit.startsWith('http://127.0.0.1:'), 'Mailpit target must be loopback');
assert(anon.length > 20 && service.length > 20, 'local credentials are required');

async function auth(path: string, body: unknown, token?: string, method = 'POST') {
  return await fetch(`${api}/auth/v1${path}`, {
    method,
    headers: {
      apikey: anon,
      'content-type': 'application/json',
      ...(token ? {authorization: `Bearer ${token}`} : {}),
    },
    ...(method === 'GET' ? {} : {body: JSON.stringify(body)}),
    signal: AbortSignal.timeout(12000),
  });
}

interface MailSummary { ID: string; Subject: string; To: Array<{Address: string}> }
interface Mail { ID: string; Subject: string; HTML: string; Text: string }
async function messages(): Promise<MailSummary[]> {
  const response = await fetch(`${mailpit}/api/v1/messages?start=0&limit=100`);
  eq(response.status, 200, 'Mailpit message list status');
  const data = await response.json();
  return data.messages as MailSummary[];
}
async function mailFor(address: string, subjectPart: string): Promise<Mail> {
  const until = Date.now() + 15000;
  while (Date.now() < until) {
    const summary = (await messages()).find(m =>
      m.Subject?.toLowerCase().includes(subjectPart.toLowerCase()) &&
      m.To?.some(to => to.Address?.toLowerCase() === address.toLowerCase())
    );
    if (summary) {
      const response = await fetch(`${mailpit}/api/v1/message/${encodeURIComponent(summary.ID)}`);
      eq(response.status, 200, 'Mailpit message detail status');
      return await response.json() as Mail;
    }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error(`Expected local email not received (${subjectPart})`);
}
function confirmationLink(message: Mail): URL {
  const html = message.HTML.replaceAll('&amp;', '&').replaceAll('&#x3D;', '=');
  const candidate = [...html.matchAll(/href=["']([^"']+)["']/gi)]
    .map(match => match[1])
    .find(value => value.includes('/auth/v1/verify'));
  assert(candidate, 'email must contain Auth verification link');
  const link = new URL(candidate);
  assert(link.hostname === '127.0.0.1', 'email verification must stay local');
  return link;
}
function assertSingleLocalAuthLink(message: Mail, expectedType?: string) {
  const html = message.HTML.replaceAll('&amp;', '&').replaceAll('&#x3D;', '=');
  const hrefs = [...html.matchAll(/href=["']([^"']+)["']/gi)].map(match => match[1]);
  eq(hrefs.length, 1, 'Auth email should contain one action link');
  const link = new URL(hrefs[0]);
  assert(link.hostname === '127.0.0.1' && link.port === '63121', 'Auth link must target local Auth only');
  assert(link.pathname === '/auth/v1/verify', 'Auth link should use the standard verify endpoint');
  if (expectedType) eq(link.searchParams.get('type'), expectedType, 'Auth link type');
  const redirectTo = link.searchParams.get('redirect_to');
  if (redirectTo) {
    const redirect = new URL(redirectTo);
    assert(redirect.hostname === '127.0.0.1' && redirect.port === '63130', 'Auth redirect must remain on the local test callback');
  }
}
async function verify(message: Mail) {
  const response = await fetch(confirmationLink(message), {redirect: 'manual'});
  assert([302, 303].includes(response.status), 'Auth verification should redirect');
  await response.body?.cancel();
}
async function waitForMessageCount(expectedMinimum: number): Promise<MailSummary[]> {
  const until = Date.now() + 15000;
  while (Date.now() < until) {
    const list = await messages();
    if (list.length >= expectedMinimum) return list;
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error('Expected local email notifications were not received');
}

Deno.test('local Auth confirmation, recovery, password/email changes and privacy-safe notifications', async () => {
  const id = crypto.randomUUID();
  const oldEmail = `pgr6d-${id}@example.com`;
  const newEmail = `pgr6d-next-${id}@example.com`;
  const initialPassword = `Drive!${crypto.randomUUID()}`;
  let userId = '';
  try {
    const signup = await auth('/signup', {email: oldEmail, password: initialPassword});
    const created = await signup.json();
    if (signup.status !== 200) {
      const code = typeof created.code === 'string' ? created.code : typeof created.error_code === 'string' ? created.error_code : 'none';
      const safeMessage = typeof created.msg === 'string' ? created.msg.replaceAll(oldEmail, '[synthetic-address]') : 'no-message';
      throw new Error(`synthetic_signup_http_${signup.status}_code_${code}_${safeMessage}`);
    }
    userId = created.user?.id ?? created.id ?? '';
    assert(userId, 'synthetic account should be created');

    const confirmation = await mailFor(oldEmail, 'DriveIt e-posta adresi doğrulaması');
    assert(confirmation.HTML.includes('E-posta adresimi doğrula'), 'confirmation template should render');
    assertSingleLocalAuthLink(confirmation, 'signup');
    await verify(confirmation);

    // Recovery is requested through the real Auth endpoint and captured by local Mailpit.
    const recoveryRequest = await auth('/recover', {email: oldEmail, redirect_to: 'http://127.0.0.1:63130/recovery'});
    eq(recoveryRequest.status, 200, 'password recovery request status');
    const recovery = await mailFor(oldEmail, 'DriveIt parola sıfırlama');
    assert(recovery.HTML.includes('Parolamı sıfırla'), 'recovery template should render');
    assertSingleLocalAuthLink(recovery, 'recovery');
    await verify(recovery);
    const login = await auth('/token?grant_type=password', {email: oldEmail, password: initialPassword});
    eq(login.status, 200, 'verified synthetic account password login');
    const session = await login.json();
    assert(typeof session.access_token === 'string', 'verified account session should exist');

    const baseline = (await messages()).length;
    const passwordChange = await auth('/user', {password: `Drive!${crypto.randomUUID()}`}, session.access_token, 'PUT');
    eq(passwordChange.status, 200, 'password change status');
    const passwordNotice = await mailFor(oldEmail, 'parola değiştirildi');
    assert(passwordNotice.HTML.includes('Bu ileti parola veya oturum bağlantısı içermez'), 'password notice must not expose credentials');
    eq([...passwordNotice.HTML.matchAll(/href=["']/gi)].length, 0, 'password-change notice should not contain sign-in links');

    const emailChange = await auth('/user', {email: newEmail}, session.access_token, 'PUT');
    eq(emailChange.status, 200, 'email change request status');
    const afterChange = await waitForMessageCount(baseline + 3);
    const oldConfirmation = await mailFor(oldEmail, 'DriveIt e-posta değişikliği onayı');
    const newConfirmation = await mailFor(newEmail, 'DriveIt e-posta değişikliği onayı');
    assert(oldConfirmation.HTML.includes('E-posta değişikliği isteğini onayla'), 'old verified address should receive neutral confirmation wording');
    assert(newConfirmation.HTML.includes('E-posta değişikliği isteğini onayla'), 'new address should receive neutral confirmation wording');
    assert(!oldConfirmation.HTML.includes(newEmail) && !newConfirmation.HTML.includes(newEmail), 'email-change body should not repeat the new personal address');
    assertSingleLocalAuthLink(oldConfirmation);
    assertSingleLocalAuthLink(newConfirmation);
    assert(afterChange.length >= baseline + 3, 'password and double email change should produce test messages');
    await verify(oldConfirmation);
    await verify(newConfirmation);
    const changedUser = await auth('/user', {}, session.access_token, 'GET');
    eq(changedUser.status, 200, 'verified user lookup status');
    eq((await changedUser.json()).email, newEmail, 'double-confirmed email address');
    const emailChangeNotice = await mailFor(oldEmail, 'e-posta adresi değiştirildi');
    assert(emailChangeNotice.HTML.includes('DriveIt hesabınızın e-posta adresi değiştirildi'), 'email change notification should render');
    eq([...emailChangeNotice.HTML.matchAll(/href=["']/gi)].length, 0, 'email-change notice should not contain sign-in links');
    console.log('PASS local signup confirmation; verified recovery; password-change notice; double-confirmed email change and security notice');
  } finally {
    if (userId) {
      const response = await fetch(`${api}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: 'DELETE', headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
      });
      assert([200, 204].includes(response.status), 'synthetic Auth account cleanup must succeed');
      await response.body?.cancel();
    }
    const ownMessages = (await messages()).filter(m => m.To?.some(to =>
      to.Address?.toLowerCase() === oldEmail.toLowerCase() || to.Address?.toLowerCase() === newEmail.toLowerCase()
    ));
    if (ownMessages.length) {
      const response = await fetch(`${mailpit}/api/v1/messages`, {
        method: 'DELETE', headers: {'content-type': 'application/json'},
        body: JSON.stringify({IDs: ownMessages.map(m => m.ID)}),
      });
      eq(response.status, 200, 'synthetic-only Mailpit message cleanup status');
      await response.body?.cancel();
    }
    const remaining = await fetch(`${api}/auth/v1/admin/users?page=1&per_page=1000`, {
      headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
    });
    eq(remaining.status, 200, 'synthetic-user cleanup verification status');
    const remainingUsers = await remaining.json();
    assert(!(remainingUsers.users as Array<{email?: string}>).some(user =>
      [oldEmail, newEmail].includes(user.email?.toLowerCase() ?? '')
    ), 'synthetic Auth user must be absent after cleanup');
    const leftoverMessages = (await messages()).some(m => m.To?.some(to =>
      to.Address?.toLowerCase() === oldEmail.toLowerCase() || to.Address?.toLowerCase() === newEmail.toLowerCase()
    ));
    assert(!leftoverMessages, 'synthetic Mailpit emails must be absent after cleanup');
  }
});

Deno.test('local Auth invitation uses one local verify link and minimal DriveIt content', async () => {
  const email = `pgr7d-invite-${crypto.randomUUID()}@example.com`;
  let userId = '';
  try {
    const invite = await auth('/invite', {email, redirect_to: 'http://127.0.0.1:63130/invite'}, service);
    eq(invite.status, 200, 'synthetic admin invite request');
    const invited = await invite.json();
    userId = invited.user?.id ?? invited.id ?? '';
    assert(userId, 'synthetic invited user should be created');

    const message = await mailFor(email, 'DriveIt hesap daveti');
    assert(message.HTML.includes('Daveti kabul et'), 'invite template should render');
    assertSingleLocalAuthLink(message, 'invite');
    assert(!/kampanya|indirim|hemen katıl|ücretsiz fırsat/i.test(message.HTML), 'invite template should not contain promotional language');
    await verify(message);
    console.log('PASS invite subject/body; single local invite link; redirect and verification target');
  } finally {
    if (userId) {
      const response = await fetch(`${api}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: 'DELETE', headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
      });
      assert([200, 204].includes(response.status), 'synthetic invited user cleanup must succeed');
      await response.body?.cancel();
    }
    const ownMessages = (await messages()).filter(m => m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase()));
    if (ownMessages.length) {
      const response = await fetch(`${mailpit}/api/v1/messages`, {
        method: 'DELETE', headers: {'content-type': 'application/json'}, body: JSON.stringify({IDs: ownMessages.map(m => m.ID)}),
      });
      eq(response.status, 200, 'synthetic invite Mailpit message cleanup status');
      await response.body?.cancel();
    }
    const remaining = await fetch(`${api}/auth/v1/admin/users?page=1&per_page=1000`, {
      headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
    });
    eq(remaining.status, 200, 'invite synthetic-user cleanup verification status');
    const remainingUsers = await remaining.json();
    assert(!(remainingUsers.users as Array<{email?: string}>).some(user => user.email?.toLowerCase() === email.toLowerCase()), 'synthetic invited user must be absent after cleanup');
    assert(!(await messages()).some(m => m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase())), 'synthetic invite message must be absent after cleanup');
  }
});

Deno.test('local Auth rejects malformed addresses and rate-limits then permits a safe recovery retry', async () => {
  const malformedEmail = 'not-an-email';
  const invalidSignup = await auth('/signup', {email: malformedEmail, password: `Drive!${crypto.randomUUID()}`});
  eq(invalidSignup.status, 400, 'malformed signup address must be rejected');
  await invalidSignup.body?.cancel();

  const invalidRecovery = await auth('/recover', {email: malformedEmail});
  eq(invalidRecovery.status, 400, 'malformed recovery address must be rejected');
  await invalidRecovery.body?.cancel();

  const id = crypto.randomUUID();
  const email = `pgr7a-retry-${id}@example.com`;
  const password = `Drive!${crypto.randomUUID()}`;
  let userId = '';
  try {
    const signup = await auth('/signup', {email, password});
    eq(signup.status, 200, 'synthetic retry account creation');
    const created = await signup.json();
    userId = created.user?.id ?? created.id ?? '';
    assert(userId, 'synthetic retry account should be created');
    const confirmation = await mailFor(email, 'DriveIt e-posta adresi doğrulaması');
    assertSingleLocalAuthLink(confirmation, 'signup');
    await verify(confirmation);

    const first = await auth('/recover', {email, redirect_to: 'http://127.0.0.1:63130/recovery'});
    eq(first.status, 200, 'first recovery request');
    const firstRecovery = await mailFor(email, 'DriveIt parola sıfırlama');
    assertSingleLocalAuthLink(firstRecovery, 'recovery');

    const immediateRetry = await auth('/recover', {email, redirect_to: 'http://127.0.0.1:63130/recovery'});
    eq(immediateRetry.status, 429, 'recovery request inside configured minimum interval');
    const limited = await immediateRetry.json();
    eq(limited.error_code ?? limited.code, 'over_email_send_rate_limit', 'rate-limit error code');
    const afterLimited = (await messages()).filter(m => m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase()));
    eq(afterLimited.filter(m => m.Subject?.toLowerCase().includes('driveit parola sıfırlama')).length, 1, 'rate-limited retry must not enqueue duplicate email');

    await new Promise(resolve => setTimeout(resolve, 1200));
    const delayedRetry = await auth('/recover', {email, redirect_to: 'http://127.0.0.1:63130/recovery'});
    eq(delayedRetry.status, 200, 'recovery retry after configured interval');
    let recovery: Mail | undefined;
    const retryMessageUntil = Date.now() + 15000;
    while (!recovery && Date.now() < retryMessageUntil) {
      const retrySummary = (await messages()).find(m => m.ID !== firstRecovery.ID &&
        m.Subject?.toLowerCase().includes('driveit parola sıfırlama') &&
        m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase())
      );
      if (retrySummary) {
        const response = await fetch(`${mailpit}/api/v1/message/${encodeURIComponent(retrySummary.ID)}`);
        eq(response.status, 200, 'retry recovery email detail status');
        recovery = await response.json() as Mail;
      } else await new Promise(resolve => setTimeout(resolve, 200));
    }
    assert(recovery, 'delayed retry recovery email should arrive');
    const ownedRecoveryMessages = (await messages()).filter(m =>
      m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase()) &&
      m.Subject?.toLowerCase().includes('driveit parola sıfırlama')
    );
    eq(ownedRecoveryMessages.length, 2, 'one original and one delayed recovery message');
    assertSingleLocalAuthLink(recovery, 'recovery');
    await verify(recovery);
    console.log('PASS malformed address rejection; immediate recovery rate limit; delayed retry; no duplicate email');
  } finally {
    if (userId) {
      const response = await fetch(`${api}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: 'DELETE', headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
      });
      assert([200, 204].includes(response.status), 'synthetic retry account cleanup must succeed');
      await response.body?.cancel();
    }
    const ownMessages = (await messages()).filter(m => m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase()));
    if (ownMessages.length) {
      const response = await fetch(`${mailpit}/api/v1/messages`, {
        method: 'DELETE', headers: {'content-type': 'application/json'}, body: JSON.stringify({IDs: ownMessages.map(m => m.ID)}),
      });
      eq(response.status, 200, 'synthetic retry Mailpit message cleanup status');
      await response.body?.cancel();
    }
    const remaining = await fetch(`${api}/auth/v1/admin/users?page=1&per_page=1000`, {
      headers: {apikey: anon, authorization: `Bearer ${service}`}, signal: AbortSignal.timeout(10000),
    });
    eq(remaining.status, 200, 'retry synthetic-user cleanup verification status');
    const remainingUsers = await remaining.json();
    assert(!(remainingUsers.users as Array<{email?: string}>).some(user => user.email?.toLowerCase() === email.toLowerCase()), 'retry synthetic account must be absent after cleanup');
    assert(!(await messages()).some(m => m.To?.some(to => to.Address?.toLowerCase() === email.toLowerCase())), 'retry synthetic messages must be absent after cleanup');
  }
});
