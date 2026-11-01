import {DeletionSupportOperator} from '../../../tool/account_deletion_support.ts';
function check(v:unknown,m:string):asserts v{if(!v)throw Error(m);}
function same(a:unknown,b:unknown,m:string){check(a===b,`${m}: ${String(a)} != ${String(b)}`);}
const url=Deno.env.get('PGR6_LOCAL_URL')??'',anon=Deno.env.get('PGR6_ANON')??'',service=Deno.env.get('PGR6_SERVICE')??'',worker=Deno.env.get('PGR6_WORKER_TOKEN')??'',mailpit=Deno.env.get('PGR6F_MAILPIT_URL')??'';
check(/^http:\/\/127\.0\.0\.1:\d+$/.test(url),'local Supabase API must be loopback');
check(mailpit==='http://127.0.0.1:63124','Mailpit must be the dedicated local test instance');
type U={id:string;email:string};
async function mailFor(email:string,subject:string){
 const end=Date.now()+10000;
 while(Date.now()<end){const r=await fetch(`${mailpit}/api/v1/messages?start=0&limit=100`);check(r.ok,'Mailpit list available');const data=await r.json();const m=(data.messages as Array<{ID:string;Subject:string;To:Array<{Address:string}>}>).find(x=>x.Subject===subject&&x.To.some(t=>t.Address.toLowerCase()===email.toLowerCase()));if(m){const d=await fetch(`${mailpit}/api/v1/message/${encodeURIComponent(m.ID)}`);check(d.ok,'Mailpit detail available');return await d.json() as {Text:string;ID:string};}await new Promise(r=>setTimeout(r,100));}
 throw Error('expected local challenge email missing');
}
function codeFrom(text:string){const m=text.match(/(?:doğrulama kodu:|DELETE MY DRIVEIT ACCOUNT)\s*([0-9a-f]{64})/i);check(m,'challenge token present in local Mailpit only');return m[1];}
async function countMessages(){const r=await fetch(`${mailpit}/api/v1/messages?start=0&limit=100`);check(r.ok,'Mailpit list');return ((await r.json()).messages as unknown[]).length;}
async function adminCall(path:string,method='GET',body?:unknown){return await fetch(`${url}${path}`,{method,headers:{apikey:service,authorization:`Bearer ${service}`,'content-type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(15000)});}
async function makeUser(email:string):Promise<U>{const r=await adminCall('/auth/v1/admin/users','POST',{email,password:`Pgr6f-${crypto.randomUUID()}!`,email_confirm:true});check(r.ok,'synthetic confirmed user');const data=await r.json();const user=data.user??data;check(typeof user.id==='string','synthetic user id');return{id:user.id,email};}
async function cleanup(u:U,skipDelete=false){
 if(!skipDelete){const r=await adminCall(`/auth/v1/admin/users/${encodeURIComponent(u.id)}`,'DELETE');if(!r.ok){const checkUser=await adminCall(`/auth/v1/admin/users/${encodeURIComponent(u.id)}`);check(!checkUser.ok,'synthetic user removed');}}
 const list=await fetch(`${mailpit}/api/v1/messages?start=0&limit=100`);if(!list.ok)return;const data=await list.json();const ids=(data.messages as Array<{ID:string;To:Array<{Address:string}>}>).filter(m=>m.To.some(t=>t.Address.toLowerCase()===u.email.toLowerCase())).map(m=>m.ID);if(ids.length){const r=await fetch(`${mailpit}/api/v1/messages`,{method:'DELETE',headers:{'content-type':'application/json'},body:JSON.stringify({IDs:ids})});check(r.ok,'only fixture Mailpit messages removed');}
}

Deno.test('support operator: authorized two-step challenge, wrong account, expiry, replay, duplicate and worker retry',async()=>{
 const suffix=crypto.randomUUID(),a=await makeUser(`pgr6f-a-${suffix}@example.com`),b=await makeUser(`pgr6f-b-${suffix}@example.com`),c=await makeUser(`pgr6f-c-${suffix}@example.com`);
 const operatorToken=[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join(''),fingerprintKey=[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('');
 let now=Date.now(),failWorkerOnce=true,failMailOnce=true;
 const fetcher:typeof fetch=async(input,init)=>{
  if(failMailOnce&&String(input)===`${mailpit}/api/v1/send`){failMailOnce=false;return new Response('',{status:503});}
  const requestUrl=String(input);if(failWorkerOnce&&requestUrl===`${url}/functions/v1/delete-account`){failWorkerOnce=false;return new Response(JSON.stringify({error:'worker_unavailable'}),{status:503,headers:{'content-type':'application/json'}});}
  return await fetch(input,init);
 };
 const flow=new DeletionSupportOperator({apiUrl:url,serviceKey:service,anonKey:anon,operatorToken,fingerprintKey,workerToken:worker,mailpitUrl:mailpit,dbPath:':memory:',now:()=>now,fetcher});
 let accountDeleted=false;
 try{
  const before=await countMessages();let denied=false;try{await flow.openRequest(a.email,'0'.repeat(64));}catch(e){denied=e instanceof Error&&e.message==='operator_unauthorized';}check(denied,'unauthorized operator rejected');same(await countMessages(),before,'unauthorized operator sends no email');
  const opened=await flow.openRequest(a.email,operatorToken);check(opened.accepted&&opened.caseId&&opened.state==='delivery_failed','mail outage leaves recoverable case');
  const duplicate=await flow.openRequest(a.email,operatorToken);check(duplicate.duplicate&&duplicate.caseId===opened.caseId,'duplicate request reuses active case');same(await countMessages(),before,'duplicate does not send another challenge');
  same((await flow.retryChallenge(opened.caseId,operatorToken)).state,'verification_pending','operator can safely resend a failed challenge');same(await countMessages(),before+1,'controlled resend sends one challenge');
  const unknown=await flow.openRequest(`missing-${suffix}@example.com`,operatorToken);check(unknown.accepted&&unknown.caseId===null,'unknown account gets generic acknowledgement');same(await countMessages(),before+1,'unknown address does not get a challenge');
  const openedB=await flow.openRequest(b.email,operatorToken);check(openedB.caseId,'B case opened');const codeB=codeFrom((await mailFor(b.email,'DriveIt başvuru e-posta doğrulaması')).Text);
  const wrong=await flow.verifyOwnership(opened.caseId,codeB,operatorToken);check(!wrong.verified,'B challenge cannot verify A case');
  const codeA=codeFrom((await mailFor(a.email,'DriveIt başvuru e-posta doğrulaması')).Text);
  const verified=await flow.verifyOwnership(opened.caseId,codeA,operatorToken);same(verified.state,'consent_pending','correct verified Auth address reaches explicit consent');
  const replay=await flow.verifyOwnership(opened.caseId,codeA,operatorToken);check(!replay.verified,'ownership challenge is one-time');
  const consentCode=codeFrom((await mailFor(a.email,'DriveIt hesap silme için açık onay')).Text);
  const noConsent=await flow.consent(opened.caseId,consentCode,'NO',operatorToken);check('accepted' in noConsent&&!noConsent.accepted,'missing explicit consent cannot queue deletion');
  const accepted=await flow.consent(opened.caseId,consentCode,'DELETE MY DRIVEIT ACCOUNT',operatorToken);same(accepted.state,'retry_pending','worker outage is not reported completed');
  const retry=await flow.retry(opened.caseId,operatorToken);same(retry.state,'completed','same consented case resumes and completes');
  check(!(await adminCall(`/auth/v1/admin/users/${encodeURIComponent(a.id)}`)).ok,'A deleted only after both challenges and explicit consent');accountDeleted=true;
  check((await adminCall(`/auth/v1/admin/users/${encodeURIComponent(b.id)}`)).ok,'B remains untouched');
  const status=flow.status(opened.caseId,operatorToken);same(status?.state,'completed','terminal status retained without owner identifiers');
  const cCase=await flow.openRequest(c.email,operatorToken);check(cCase.caseId,'C case opened');const cCode=codeFrom((await mailFor(c.email,'DriveIt başvuru e-posta doğrulaması')).Text);now+=901000;
  const expired=await flow.verifyOwnership(cCase.caseId,cCode,operatorToken);same(expired.state,'expired','expired challenge safely stops');
  const blocked=await flow.retry(cCase.caseId,operatorToken);same(blocked.state,'expired','expired verification has no deletion action');
  const events=flow.status(opened.caseId,operatorToken)?.events.map(e=>e.action)??[];check(events.includes('worker_retry_pending')&&events.includes('operator_retry')&&events.includes('deletion_completed'),'audit trail records safe retry and terminal evidence');
  console.log('PASS local operator auth/ownership/consent/idempotency/replay/expiry/worker retry');
 }finally{
  flow.close();await cleanup(a,accountDeleted);await cleanup(b);await cleanup(c);
 }
});
