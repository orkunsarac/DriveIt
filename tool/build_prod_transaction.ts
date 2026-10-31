// Offline artifact builder only: no network, credentials or deployment command.
export function statements(sql:string):string[] {
  const out:string[]=[]; let start=0,quote='',dollar='',line=false;
  for(let i=0;i<sql.length;i++) {
    const c=sql[i],n=sql[i+1];
    if(line){if(c==='\n')line=false;continue;}
    if(dollar){if(sql.startsWith(dollar,i)){i+=dollar.length-1;dollar='';}continue;}
    if(quote){if(c===quote){if(n===quote)i++;else quote='';}continue;}
    if(c==='-'&&n==='-'){line=true;i++;continue;}
    if(c==='/'&&n==='*')throw Error('Block comments require parser review');
    if(c==="'"||c==='"'){quote=c;continue;}
    if(c==='$'){const m=sql.slice(i).match(/^\$(?:[a-zA-Z_][\w]*)?\$/);if(m){dollar=m[0];i+=dollar.length-1;continue;}}
    if(c===';'){out.push(sql.slice(start,i+1));start=i+1;}
  }
  if(quote||dollar||sql.slice(start).replace(/--[^\n]*/g,'').trim())throw Error('Incomplete SQL');
  return out;
}
function command(s:string){return s.replace(/^\s*(?:--[^\n]*(?:\n|$)\s*)*/,'').trim();}
export function body(sql:string):string {
  return statements(sql).filter(s=>{
    const c=command(s);
    if(/^(begin|commit)\s*;$/i.test(c))return false;
    if(/^(begin|commit|rollback|savepoint|release|end|start\s+transaction|prepare\s+transaction|vacuum|alter\s+system)\b/i.test(c)||/\bconcurrently\b/i.test(c.split(/\bAS\b/i)[0]))throw Error('Unsupported transaction boundary/operation');
    return true;
  }).join('\n');
}
const versions=['202609220001','202609220002','202609230001','202609300001','202609300002','202609300003','202609300004','202609300005','202610010001','202610060001','202610060002','202610060003','202610060004','202610070001','202610070002','202610120001','202610150001','202610160001','202610160002','202610160003','202610160004','202610160005','202610170001','202610170002','202610310001'];
export async function build():Promise<string> {
  const target=JSON.parse(await Deno.readTextFile('supabase/prod/target.json'));
  if(target.projectRef!=='arwnbogcswisfesayosy'||target.region!=='eu-central-1'||target.groupDriveRequiredDefault!==false)throw Error('Wrong approved PROD target');
  const manifest=JSON.parse(await Deno.readTextFile('supabase/prod/preparation_manifest.json'));
  if(manifest.hashMode!=='utf8-lf'||manifest.groupDriveDefault!=='FALSE')throw Error('Unsafe manifest');
  const files=manifest.files.filter((f:{kind:string})=>f.kind==='migration');
  if(JSON.stringify(files.map((f:{path:string})=>f.path.split('/').pop()!.split('_')[0]))!==JSON.stringify(versions))throw Error('Exact migration order mismatch');
  let result=`-- Approved target: ${target.projectRef}. This artifact does not authenticate its destination.\nBEGIN;\nDO $$ BEGIN
    IF EXISTS(select 1 from auth.users) OR EXISTS(select 1 from storage.objects)
      OR EXISTS(select 1 from pg_class where relnamespace='public'::regnamespace and relkind in ('r','p'))
      OR to_regclass('supabase_migrations.schema_migrations') is not null
    THEN RAISE EXCEPTION 'Expected empty, undeployed application database'; END IF;
  END $$;
  CREATE SCHEMA IF NOT EXISTS supabase_migrations;
  CREATE TABLE supabase_migrations.schema_migrations(version text primary key, statements text[], name text);
  REVOKE ALL ON supabase_migrations.schema_migrations FROM public,anon,authenticated,service_role;\n`;
  for(let i=0;i<files.length;i++) {
    const f=files[i];if(!/^(supabase\/prod\/bootstrap|supabase\/migrations|supabase\/phase8-dev\/supabase\/migrations)\/[a-z0-9_]+\.sql$/.test(f.path))throw Error('Unexpected migration path');
    const sql=(await Deno.readTextFile(f.path)).replaceAll('\r\n','\n');
    const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(sql)))).map(v=>v.toString(16).padStart(2,'0')).join('').toUpperCase();
    if(hash!==f.sha256)throw Error('Migration hash mismatch: '+f.path);
    const tag='$driveit_history_'+versions[i]+'$';if(sql.includes(tag))throw Error('History delimiter collision');
    result+='\n-- migration: '+versions[i]+'\n'+body(sql)+'\n';
    const name=f.path.split('/').pop()!.replace(/^\d+_/,'').replace(/\.sql$/,'');
    result+=`INSERT INTO supabase_migrations.schema_migrations VALUES ('${versions[i]}',ARRAY[${tag}${sql}${tag}],'${name}');\n`;
  }
  result+=`DO $$ BEGIN
    IF public.phase8_group_enabled() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Group gate must be FALSE'; END IF;
    IF (select count(*) from public.phase8_group_rollout where singleton and enabled=false)<>1 THEN RAISE EXCEPTION 'Missing closed rollout row'; END IF;
    IF (select count(*) from supabase_migrations.schema_migrations)<>25 THEN RAISE EXCEPTION 'Incomplete history'; END IF;
    IF has_table_privilege('authenticated','public.phase8_group_rollout','UPDATE')
      OR has_table_privilege('service_role','public.phase8_group_rollout','UPDATE')
    THEN RAISE EXCEPTION 'Unsafe rollout ACL'; END IF;
  END $$;\nCOMMIT;\n`;
  return result;
}
if(import.meta.main){
  if(Deno.args.length!==1||!/^tmp\/[a-z0-9_-]+\.sql$/.test(Deno.args[0]))throw Error('Output must be an explicit tmp/*.sql artifact');
  const sql=await build();await Deno.writeTextFile(Deno.args[0],sql);console.log('Built 25-migration atomic transaction; no deployment performed.');
}
