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
export async function buildRoadCorrection():Promise<string>{
 await buildUpgrade();
 const base=JSON.parse(await Deno.readTextFile('supabase/prod/preparation_manifest.json')).files.filter((f:{kind:string})=>f.kind==='migration');
 const upgrades=JSON.parse(await Deno.readTextFile('supabase/prod/upgrade_manifest.json')).files;
 const correction=JSON.parse(await Deno.readTextFile('supabase/prod/correction_manifest.json'));
 if(correction.deploymentReady!==false||correction.projectRef!=='arwnbogcswisfesayosy'||correction.files.length!==2)throw Error('Unsafe correction manifest');
 const paths=['supabase/account-deletion/migrations/202611020001_account_deletion_road_version.sql','supabase/account-deletion/migrations/202611020002_account_deletion_generation_version.sql'];
 let corrections='';
 for(let i=0;i<2;i++){
  const file=correction.files[i];if(file.path!==paths[i])throw Error('Unexpected correction order');
  const sql=(await Deno.readTextFile(file.path)).replaceAll('\r\n','\n');
  const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(sql)))].map(b=>b.toString(16).padStart(2,'0')).join('').toUpperCase();
  if(hash!==file.sha256)throw Error('Correction hash mismatch');
  const version=file.path.split('/').pop()!.split('_')[0],tag='$road_correction_'+i+'$';
  if(sql.includes(tag))throw Error('Correction delimiter collision');
  corrections+=body(sql)+`\nINSERT INTO supabase_migrations.schema_migrations(version,statements,name) VALUES ('${version}',ARRAY[${tag}${sql}${tag}],'${file.path.split('/').pop()!.slice(13,-4)}');\n`;
 }
 const versions=[...base,...upgrades].map((f:{path:string})=>f.path.split('/').pop()!.split('_')[0]);
 return `-- Explicitly approved road-version correction only.\nBEGIN;\nDO $$ BEGIN
 IF (select array_agg(version::text order by version) from supabase_migrations.schema_migrations) IS DISTINCT FROM ARRAY[${versions.map((v:string)=>`'${v}'`).join(',')}]::text[] THEN RAISE EXCEPTION 'Expected exact 50-migration history'; END IF;
 IF public.phase8_group_enabled() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Group gate must stay FALSE'; END IF;
 END $$;\n${corrections}
 DO $$ BEGIN
 IF position('r.processing_version<>3' in pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure))=0 OR position('''accountDeletion'',1,3,jsonb_array_length' in pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure))=0 OR (select count(*) from supabase_migrations.schema_migrations)<>52 OR public.phase8_group_enabled() IS DISTINCT FROM false THEN RAISE EXCEPTION 'Correction postcondition failed'; END IF;
 END $$;\nCOMMIT;\n`;
}
if(import.meta.main){
 if(![1,2].includes(Deno.args.length)||(Deno.args.length===2&&Deno.args[1]!=='--road-version-correction')||!/^tmp\/[a-z0-9_-]+\.sql$/.test(Deno.args[0]))throw Error('Explicit new tmp SQL artifact required');
 try{await Deno.stat(Deno.args[0]);throw Error('Output already exists');}catch(e){if(!(e instanceof Deno.errors.NotFound))throw e;}
 await Deno.writeTextFile(Deno.args[0],Deno.args.length===2?await buildRoadCorrection():await buildUpgrade());console.log('Prepared verified offline migration artifact; no network or deployment.');
}
