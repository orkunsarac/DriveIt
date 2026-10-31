// Installed ONLY in the pinned local workspace by run_pgr5b.ps1.
// Auth/DB/Storage/Edge remain real services. Only the external paid road provider is deterministic.
if (!Deno.env.get('SUPABASE_URL')?.startsWith('http://')) throw Error('Local-only fixture');
const realFetch=globalThis.fetch;
const realEnvGet=Deno.env.get.bind(Deno.env);
Deno.env.get=(name:string)=>name==='MAPBOX_ACCESS_TOKEN'?'local-fixture-no-external-call':realEnvGet(name);
globalThis.fetch=async (input,init)=>{
 const url=typeof input==='string'?input:input instanceof URL?input.href:input.url;
 if(url.startsWith('https://api.mapbox.com/matching/v5/mapbox/driving?')){
  const form=new URLSearchParams(String(init?.body??''));
  const coordinates=(form.get('coordinates')??'').split(';').map(p=>p.split(',').map(Number));
  return new Response(JSON.stringify({code:'Ok',matchings:[{confidence:0.99,geometry:{type:'LineString',coordinates}}]}),{status:200,headers:{'content-type':'application/json'}});
 }
 return realFetch(input,init);
};
// @ts-ignore The production handler is copied beside this entry only in the disposable workspace.
await import('./production.ts');
