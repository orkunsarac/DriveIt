// Offline, allowlisted DDL extraction. Never reads a data.sql dump.
const source = 'tmp/diagnostic_acceptance/planet-m2-fix-20261015/schema.sql';
const text = await Deno.readTextFile(source);
const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))).map(x=>x.toString(16).padStart(2,'0')).join('');
// File hash is checked separately because decoding normalizes neither BOM nor bytes.
const rawHash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',await Deno.readFile(source)))).map(x=>x.toString(16).padStart(2,'0')).join('');
if(rawHash !== 'bdbdcac292e9ce2116db82e33325fdfd2e343bc158896fde8c69c48e538ab687') throw Error('Unapproved schema archive');
const statements:string[]=[];
let start=0, quote='', dollar='', comment=false;
for(let i=0;i<text.length;i++) {
  const c=text[i],next=text[i+1];
  if(comment){if(c==='\n')comment=false;continue;}
  if(dollar){if(text.startsWith(dollar,i)){i+=dollar.length-1;dollar='';}continue;}
  if(quote){if(c===quote){if(next===quote)i++;else quote='';}continue;}
  if(c==='-'&&next==='-'){comment=true;i++;continue;}
  if(c==='/'&&next==='*')throw Error('Unsupported block comment in archive');
  if(c==="'"||c==='"'){quote=c;continue;}
  if(c==='$'){const m=text.slice(i).match(/^\$(?:[a-zA-Z_][\w]*)?\$/);if(m){dollar=m[0];i+=dollar.length-1;continue;}}
  if(c===';'){statements.push(text.slice(start,i+1).trim());start=i+1;}
}
if(quote||dollar)throw Error('Unterminated SQL');
const tables='(?:profiles|world_publishes|world_validated_roads|world_validated_road_sections)';
const functions='(?:attach_world_publish_source|handle_new_user|is_username_available|set_updated_at)';
const tableRef=new RegExp('"public"\\."'+tables+'"');
const functionRef=new RegExp('"public"\\."'+functions+'"');
const groups:string[][]=[[],[],[],[],[]];
for(const s of statements){
  if(new RegExp('^CREATE TABLE IF NOT EXISTS "public"\\."'+tables+'"').test(s)) groups[0].push(s);
  else if(/^CREATE OR REPLACE FUNCTION/.test(s)&&functionRef.test(s.split(' RETURNS ')[0]))groups[1].push(s);
  else if(/^ALTER TABLE/.test(s)&&tableRef.test(s.split(/\n/)[0]))groups[2].push(s);
  else if(/^CREATE (?:UNIQUE )?INDEX/.test(s)&&tableRef.test(s))groups[2].push(s);
  else if(/^CREATE OR REPLACE TRIGGER/.test(s)&&(tableRef.test(s)||s.includes('"public"."handle_new_user"()')))groups[3].push(s);
  else if(/^CREATE POLICY/.test(s)&&(tableRef.test(s)||s.includes("'world-drive-sources'")))groups[3].push(s);
  else if(/^(?:GRANT|REVOKE|ALTER FUNCTION)/.test(s)&&((s.includes(' ON TABLE ')&&tableRef.test(s))||(s.includes('FUNCTION ')&&functionRef.test(s))))groups[4].push(s);
}
if(groups[0].length!==4||groups[1].length!==4)throw Error('Missing canonical objects');
const live=JSON.parse(await Deno.readTextFile('tmp/diagnostic_acceptance/pgr2b-schema-metadata.json'));
const meta=(Array.isArray(live)?live[0]:live).schema_metadata;
for(const f of meta.functions){const s=groups[1].find(s=>s.includes('"public"."'+f.name+'"('));if(!s||!s.includes(f.source))throw Error('Archive/live function drift: '+f.name);}
const reset='revoke all on table public.profiles, public.world_publishes, public.world_validated_roads, public.world_validated_road_sections from public, anon, authenticated, service_role;';
const ddl='-- Canonical Planet DEV schema-only archive SHA256: '+rawHash+'\n-- Live function bodies verified; no data dump used.\nbegin;\ncreate extension if not exists postgis with schema extensions;\n'+groups.slice(0,4).flat().join('\n\n')+'\n'+reset+'\n'+groups[4].join('\n\n')+'\ncommit;\n';
if(/-----BEGIN.*PRIVATE KEY|eyJ[\w-]{20,}\.[\w-]+\.[\w-]+|\bCOPY\b/.test(ddl))throw Error('Unexpected payload');
await Deno.mkdir('supabase/prod/bootstrap',{recursive:true});
await Deno.writeTextFile('supabase/prod/bootstrap/202609220001_canonical_planet_base.sql',ddl);
await Deno.writeTextFile('supabase/prod/bootstrap/storage_buckets.json',JSON.stringify(meta.bucket,null,2)+'\n');
console.log('Extracted allowlisted canonical DDL:',groups.map(x=>x.length).join('/'));
