import {buildUpgrade} from './build_prod_upgrade.ts';
import {statements} from './build_prod_transaction.ts';
Deno.test('additive deletion chain is atomic, history-fenced and closed',async()=>{
 const sql=await buildUpgrade();
 const commands=statements(sql).map(s=>s.replace(/^\s*(?:--[^\n]*(?:\n|$)\s*)*/,'').trim());
 for(const [pattern,count] of [[/^BEGIN;$/i,1],[/^COMMIT;$/i,1],[/^INSERT INTO supabase_migrations.schema_migrations/,25]] as const){if(commands.filter(c=>pattern.test(c)).length!==count)throw Error('Transaction/history invariant');}
 for(const proof of ['Unexpected base migration history','Group Drive must remain closed','Deletion schema already exists','account_deletion_erasure_audit','Unsafe deletion access'])if(!sql.includes(proof))throw Error('Missing safety proof');
});
