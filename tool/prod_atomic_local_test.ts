import {build} from './build_prod_transaction.ts';
const container='supabase-pgr4a-atomic-pgr4a-atomic-20261031-database-55b03b1db227';
function check(v:unknown,m:string){if(!v)throw Error(m);}
async function sql(text:string){const r=await new Deno.Command('docker',{args:['exec',container,'psql','-U','postgres','-d','postgres','-X','-At','-v','ON_ERROR_STOP=1','-c',text],stdout:'piped',stderr:'piped'}).output();check(r.success,'local SQL failed');return new TextDecoder().decode(r.stdout).trim();}
Deno.test('25 migrations stay invisible before gate, validate FALSE, and rollback cleanly',async()=>{
 const inspect=await new Deno.Command('docker',{args:['inspect','--format','{{range .HostConfig.Mounts}}{{if eq .Target "/var/lib/postgresql/data"}}{{.VolumeOptions.Subpath}}{{end}}{{end}}',container],stdout:'piped'}).output();
 check(inspect.success&&new TextDecoder().decode(inspect.stdout).trim()==='instance-0527455996a5a2c0295e371a39519b3e5e54b6d2e65ce98628e97e84db16793f-83de82a7-3c4a-4cda-8bac-c80ba124bbc0/data','wrong physical subpath');
 check(await sql('select system_identifier from pg_control_system();')==='7702852553093967913','wrong system identifier');
 let bundle=await build();
 bundle=bundle.replace('-- migration: 202610310001',"SELECT 'ATOMIC_WINDOW'; SELECT pg_sleep(8);\n-- migration: 202610310001");
 bundle=bundle.replace(/COMMIT;\n$/,'ROLLBACK;\n');
 check(bundle.endsWith('ROLLBACK;\n'),'rollback test required');
 const child=new Deno.Command('docker',{args:['exec','-i',container,'psql','-U','postgres','-d','postgres','-X','-At','-v','ON_ERROR_STOP=1'],stdin:'piped',stdout:'piped',stderr:'piped'}).spawn();
 const errors=new Response(child.stderr).text();const writer=child.stdin.getWriter();const feeding=writer.write(new TextEncoder().encode(bundle)).then(()=>writer.close());
 const reader=child.stdout.getReader();let output='',observed=false;
 try {
   while(true){const r=await reader.read();if(r.done)break;output+=new TextDecoder().decode(r.value);if(!observed&&output.includes('ATOMIC_WINDOW')){
     observed=true;check(await sql("select to_regprocedure('public.phase8_group_command(text,uuid,text,uuid,boolean)') is null;")==='t','unguarded M4 visible to second session');
   }}
   await feeding;const status=await child.status;const stderr=await errors;
   check(status.success,'atomic bundle SQL failed: '+stderr);check(observed,'concurrency checkpoint missing');
 }finally{reader.releaseLock();}
 check(await sql("select count(*) from pg_class where relnamespace='public'::regnamespace and relkind in ('r','p');")==='0','rollback left application tables');
 check(await sql("select to_regclass('supabase_migrations.schema_migrations') is null;")==='t','rollback left history');
});
