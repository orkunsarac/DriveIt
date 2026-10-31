import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.117.2';
const expected='instance-6e5901b4a541135e72ad8a3b2810a754e5e786533c88fe9386c11285b7c86efe-f4223b3e-8b1a-4c2a-bc16-707753a33aca/data';
export async function localSql(query:string) {
 const container=Deno.env.get('PHASE8_TEST_DB_CONTAINER')??'';
 if(!/^supabase-pgr2b-canonical-pgr2b-canonical-20261031-database-[a-f0-9]+$/.test(container))throw Error('Wrong local container');
 const r=await new Deno.Command('docker',{args:['exec',container,'psql','-U','postgres','-d','postgres','-X','-At','-v','ON_ERROR_STOP=1','-c',query],stdout:'piped',stderr:'piped'}).output();
 if(!r.success)throw Error('Local administrative SQL failed');
 return new TextDecoder().decode(r.stdout).trim();
}
export async function assertCanonicalTarget(){
 if(Deno.env.get('PHASE8_REMOTE_PROJECT_REF')!==undefined || Deno.env.get('PHASE8_LOCAL_URL')!=='http://127.0.0.1:27773' || Deno.env.get('PHASE8_TEST_STACK')!=='pgr2b-canonical-20261031')throw Error('Explicit isolated local target required');
 const container=Deno.env.get('PHASE8_TEST_DB_CONTAINER')??'';
 const r=await new Deno.Command('docker',{args:['inspect','--format','{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}',container],stdout:'piped',stderr:'piped'}).output();
 if(!r.success || new TextDecoder().decode(r.stdout).trim()!==expected)throw Error('Physical PGDATA mismatch');
 if(await localSql('select system_identifier from pg_control_system();')!=='7702837359395967017')throw Error('Cluster identity mismatch');
}
export async function cleanupSyntheticOwners(admin:SupabaseClient,ids:string[]){
 await assertCanonicalTarget();
 for(const id of ids){
  if(!/^[0-9a-f-]{36}$/.test(id))throw Error('Invalid synthetic owner');
  const files=await admin.storage.from('phase8-drive-staging').list(id,{limit:1000});
  if(files.error)throw Error('Synthetic storage listing failed');
  for(const folder of files.data){
   const nested=await admin.storage.from('phase8-drive-staging').list(`${id}/${folder.name}`,{limit:1000});
   if(nested.error)throw Error('Synthetic nested listing failed');
   const paths=nested.data.map(x=>`${id}/${folder.name}/${x.name}`);
   if(paths.length && (await admin.storage.from('phase8-drive-staging').remove(paths)).error)throw Error('Synthetic storage cleanup failed');
  }
  // Immutable drive rows are removed only for UUIDs created by this run, in this pinned disposable database.
  await localSql(`begin; set local session_replication_role=replica; do $$declare t record; begin for t in select table_name from information_schema.columns where table_schema='public' and column_name='owner_id' loop execute format('delete from public.%I where owner_id=$1',t.table_name) using '${id}'::uuid; end loop; end$$; commit;`);
  if((await admin.auth.admin.deleteUser(id)).error)throw Error('Synthetic Auth cleanup failed');
  if(await localSql(`select count(*) from auth.users where id='${id}';`)!=='0')throw Error('Synthetic account remains');
 }
}
