import {body,statements,build} from './build_prod_transaction.ts';
function check(v:unknown){if(!v)throw Error('Atomic bundle assertion failed');}
Deno.test('transaction stripping preserves quoted function bodies',()=>{
 const sql="-- header\nbegin; create function f() returns void as $$ begin perform ';'; end; $$ language plpgsql; commit;";
 const b=body(sql);check(statements(b).length===1);check(b.includes("begin perform ';'; end;"));
});
Deno.test('unexpected boundaries and incomplete SQL fail closed',()=>{
 for(const sql of ['rollback;','start transaction;','begin work;','commit work;','commit and chain;','vacuum;','select \'unterminated','create index concurrently i on t(a);']){let failed=false;try{body(sql)}catch{failed=true}check(failed);}
});
Deno.test('reviewed migration set builds a single outer transaction',async()=>{
 const sql=await build();const commands=statements(sql).map(s=>s.replace(/^\s*(?:--[^\n]*(?:\n|$)\s*)*/,'').trim());
 check(commands.filter(s=>/^begin;$/i.test(s)).length===1);check(commands.filter(s=>/^commit;$/i.test(s)).length===1);
 check(sql.includes('Group gate must be FALSE'));check((sql.match(/INSERT INTO supabase_migrations.schema_migrations/g)||[]).length===25);
 check(sql.includes(",'canonical_planet_base');"));
});
