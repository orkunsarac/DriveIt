// Offline additive release artifact. Never connects to a database.
import {body,build as buildBase} from './build_prod_transaction.ts';
export async function buildUpgrade():Promise<string>{
 await buildBase(); // Validate the original 25 source hashes and exact order.
 const root=JSON.parse(await Deno.readTextFile('supabase/prod/preparation_manifest.json'));
 const upgrade=JSON.parse(await Deno.readTextFile('supabase/prod/upgrade_manifest.json'));
 if(root.deploymentReady!==false||upgrade.deploymentReady!==false||upgrade.projectRef!=='arwnbogcswisfesayosy'||upgrade.groupDriveEnabled!==false)throw Error('Release must remain locked');
 const base=root.files.filter((f:{kind:string})=>f.kind==='migration').map((f:{path:string})=>f.path.split('/').pop()!.split('_')[0]);
 if(base.length!==25||base.at(-1)!=='202610310001')throw Error('Base history mismatch');
 if(upgrade.files.length!==25)throw Error('Incomplete deletion migration chain');
 let result=`-- Offline upgrade; approved PROD ref arwnbogcswisfesayosy. Destination must be independently verified.\nBEGIN;\nDO $$ BEGIN
 IF (SELECT array_agg(version::text ORDER BY version) FROM supabase_migrations.schema_migrations) IS DISTINCT FROM ARRAY[${base.map((v:string)=>`'${v}'`).join(',')}]::text[] THEN RAISE EXCEPTION 'Unexpected base migration history'; END IF;
 IF public.phase8_group_enabled() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Group Drive must remain closed'; END IF;
 IF to_regclass('public.account_deletion_jobs') IS NOT NULL THEN RAISE EXCEPTION 'Deletion schema already exists; reconcile history before retry'; END IF;
 END $$;\n`;
 for(let i=0;i<upgrade.files.length;i++){
  const f=upgrade.files[i],version='2026110100'+String(i+1).padStart(2,'0');
  if(!f.path.startsWith(`supabase/account-deletion/migrations/${version}_`)||!/^supabase\/account-deletion\/migrations\/[a-z0-9_]+\.sql$/.test(f.path))throw Error('Upgrade order/path mismatch');
  const sql=(await Deno.readTextFile(f.path)).replaceAll('\r\n','\n');
  const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(sql)))].map(b=>b.toString(16).padStart(2,'0')).join('').toUpperCase();
  if(hash!==f.sha256)throw Error('Upgrade source hash mismatch: '+f.path);
  const tag='$upgrade_'+version+'$';if(sql.includes(tag))throw Error('History delimiter collision');
  result+=`\n-- upgrade: ${version}\n${body(sql)}\nINSERT INTO supabase_migrations.schema_migrations(version,statements,name) VALUES ('${version}',ARRAY[${tag}${sql}${tag}],'${f.path.split('/').pop()!.slice(13,-4)}');\n`;
 }
 result+=`DO $$ BEGIN
 IF public.phase8_group_enabled() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Group gate changed'; END IF;
 IF (SELECT count(*) FROM supabase_migrations.schema_migrations)<>50 THEN RAISE EXCEPTION 'Incomplete upgrade history'; END IF;
 IF to_regclass('public.account_deletion_erasure_audit') IS NULL OR to_regprocedure('public.account_deletion_worker_claim(uuid)') IS NULL THEN RAISE EXCEPTION 'Missing deletion prerequisites'; END IF;
 IF has_table_privilege('authenticated','public.account_deletion_jobs','SELECT') OR has_table_privilege('anon','public.account_deletion_jobs','SELECT') THEN RAISE EXCEPTION 'Unsafe deletion access'; END IF;
 END $$;\nCOMMIT;\n`;
 return result;
}
if(import.meta.main){
 if(Deno.args.length!==1||!/^tmp\/[a-z0-9_-]+\.sql$/.test(Deno.args[0]))throw Error('Explicit new tmp SQL artifact required');
 try{await Deno.stat(Deno.args[0]);throw Error('Output already exists');}catch(e){if(!(e instanceof Deno.errors.NotFound))throw e;}
 await Deno.writeTextFile(Deno.args[0],await buildUpgrade());console.log('Prepared offline 25-migration additive upgrade; no network or deployment.');
}
