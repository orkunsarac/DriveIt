-- Runs only through `supabase test db --local` from the isolated Phase 8 root.
begin;
create extension if not exists pgtap with schema extensions;
select plan(45);

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111','authenticated','authenticated','phase8-a@test.invalid','',now(),'{}','{}',now(),now()),
  ('22222222-2222-4222-8222-222222222222','authenticated','authenticated','phase8-b@test.invalid','',now(),'{}','{}',now(),now())
on conflict (id) do nothing;

insert into public.phase8_drive_upload_intents(
  id,owner_id,idempotency_key,source_identity,owner_scope,contract_version,
  payload_fingerprint,object_sha256,object_bytes,staging_path
) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','owner-sync-v2:'||repeat('a',64),'33333333-3333-4333-8333-333333333333','["local_account_store_v1","account","11111111-1111-4111-8111-111111111111"]',2,repeat('b',64),repeat('c',64),100,'11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/envelope.json'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','owner-sync-v2:'||repeat('d',64),'44444444-4444-4444-8444-444444444444','["local_account_store_v1","account","22222222-2222-4222-8222-222222222222"]',2,repeat('e',64),repeat('f',64),100,'22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/envelope.json');

select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_upload_intents'::regclass),'upload intents have RLS');
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_owner_sequences'::regclass),'owner sequences have RLS');
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_manifests'::regclass),'manifests have RLS');
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_changes'::regclass),'change feed has RLS');
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_snapshots'::regclass),'snapshots have RLS');
select ok(not has_table_privilege('anon','public.phase8_drive_manifests','SELECT'),'anon cannot read manifests');
select ok(not has_table_privilege('authenticated','public.phase8_drive_manifests','SELECT'),'authenticated cannot bypass download API');
select ok(not has_table_privilege('authenticated','public.phase8_drive_upload_intents','INSERT'),'authenticated cannot forge intents');
select ok(not has_table_privilege('authenticated','public.phase8_drive_changes','SELECT'),'authenticated cannot read change feed directly');
select ok(not has_function_privilege('anon','public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)','EXECUTE'),'anon cannot invoke begin RPC');
select ok(not has_function_privilege('authenticated','public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)','EXECUTE'),'authenticated cannot supply a forged p_owner_id to begin RPC');
select ok(has_function_privilege('service_role','public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)','EXECUTE'),'trusted Edge service can invoke begin RPC');
select ok(not has_function_privilege('authenticated','public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer)','EXECUTE'),'client cannot invoke finalizer RPC');
select ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)'::regprocedure),'begin RPC is security-definer with empty search_path');
select ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer)'::regprocedure),'finalizer is security-definer with empty search_path');
select ok(not has_function_privilege('anon','public.phase8_can_access_staging_object(text)','EXECUTE'),'anon cannot test staging access');
select ok(not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname like 'phase8_%' and prosecdef and not (coalesce(proconfig,'{}') @> array['search_path=""'])),'all Phase 8 security-definer functions pin an empty search_path');
select ok(not exists(select 1 from pg_proc p where p.pronamespace='public'::regnamespace and p.proname like 'phase8_%' and p.prosecdef and has_function_privilege('anon',p.oid,'EXECUTE')),'anon cannot execute any Phase 8 security-definer function');
select ok(not exists(select 1 from pg_proc p where p.pronamespace='public'::regnamespace and p.proname like 'phase8_%' and p.prosecdef and p.proname<>'phase8_can_access_staging_object' and has_function_privilege('authenticated',p.oid,'EXECUTE')),'authenticated can execute only the staging path predicate');
select ok(not exists(select 1 from pg_proc p where p.pronamespace='public'::regnamespace and p.proname like 'phase8_%' and p.proname not like 'phase8_m1_%' and p.prosecdef and not has_function_privilege('service_role',p.oid,'EXECUTE')),'service role can execute public RPCs, not retired M1 bypasses');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select is(public.phase8_can_access_staging_object('11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/envelope.json'),true,'Owner A can authorize only its staging intent');
select is(public.phase8_can_access_staging_object('22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/envelope.json'),false,'Owner A cannot authorize Owner B staging path');
select throws_ok($$select public.phase8_begin_drive_upload('22222222-2222-4222-8222-222222222222'::uuid,'["local_account_store_v1","account","22222222-2222-4222-8222-222222222222"]'::text,'55555555-5555-4555-8555-555555555555'::uuid,'owner-sync-v2:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'::text,2::smallint,repeat('a',64),repeat('b',64),100)$$,'42501','permission denied for function phase8_begin_drive_upload','authenticated cannot call service-only RPC with a forged owner');
select throws_ok($$select * from public.phase8_drive_manifests$$,'42501','permission denied for table phase8_drive_manifests','authenticated cannot directly read another owner manifest table');
reset role;

set local role anon;
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.phase8_can_access_staging_object('11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/envelope.json')$$,'42501','permission denied for function phase8_can_access_staging_object','anonymous cannot call staging authorization helper');
select throws_ok($$select * from public.phase8_drive_manifests$$,'42501','permission denied for table phase8_drive_manifests','anonymous cannot directly read manifest table');
reset role;

create temporary table phase8_test_begin(result jsonb) on commit drop;
insert into phase8_test_begin select public.phase8_begin_drive_upload(
  '11111111-1111-4111-8111-111111111111',
  '["local_account_store_v1","account","11111111-1111-4111-8111-111111111111"]',
  '66666666-6666-4666-8666-666666666666',
  'owner-sync-v2:'||repeat('1',64),2::smallint,repeat('2',64),repeat('3',64),128);
select is((select result->>'state' from phase8_test_begin),'staging','begin reserves an invisible staging intent');
select is((select count(*)::integer from public.phase8_drive_upload_intents where idempotency_key='owner-sync-v2:'||repeat('1',64)),1,'same begin claims create one intent');

create temporary table phase8_test_receipt(result jsonb) on commit drop;
insert into phase8_test_receipt select public.phase8_finalize_drive_upload(
  '11111111-1111-4111-8111-111111111111',(select (result->>'intent_id')::uuid from phase8_test_begin),
  'synthetic-drive-1',repeat('2',64),repeat('3',64),128);
select is((select count(*)::integer from public.phase8_drive_manifests where source_identity='66666666-6666-4666-8666-666666666666'),1,'finalize atomically creates one manifest');
select is((select count(*)::integer from public.phase8_drive_changes where source_identity='66666666-6666-4666-8666-666666666666'),1,'finalize atomically appends one change');
select is((select count(*)::integer from public.phase8_drive_upload_intents where idempotency_key='owner-sync-v2:'||repeat('1',64) and state='finalized' and receipt is not null),1,'finalize stores durable ACK on intent');
select is(public.phase8_finalize_drive_upload(
  '11111111-1111-4111-8111-111111111111',(select (result->>'intent_id')::uuid from phase8_test_begin),
  'synthetic-drive-1',repeat('2',64),repeat('3',64),128),
  (select result from phase8_test_receipt),'replayed finalize returns the exact ACK');
select is((select count(*)::integer from public.phase8_drive_changes where source_identity='66666666-6666-4666-8666-666666666666'),1,'replayed finalize does not duplicate the change');
select throws_ok($$select public.phase8_finalize_drive_upload('11111111-1111-4111-8111-111111111111',(select (result->>'intent_id')::uuid from phase8_test_begin),'synthetic-drive-1',repeat('4',64),repeat('3',64),128)$$,'23505','finalized_claim_conflict','changed payload claim conflicts after finalization');
select throws_ok($$select public.phase8_finalize_drive_upload('11111111-1111-4111-8111-111111111111',(select (result->>'intent_id')::uuid from phase8_test_begin),'synthetic-drive-1',null,repeat('3',64),128)$$,'22023','finalization_claim_invalid','null finalization fingerprint is rejected even on replay');

create temporary table phase8_test_snapshot(result jsonb) on commit drop;
insert into phase8_test_snapshot select public.phase8_begin_drive_snapshot('11111111-1111-4111-8111-111111111111');
select is((select (result->>'high_water')::bigint from phase8_test_snapshot),1::bigint,'snapshot captures committed high-water');
select is(jsonb_array_length(public.phase8_read_drive_snapshot_page(
  '11111111-1111-4111-8111-111111111111',(select (result->>'snapshot_id')::uuid from phase8_test_snapshot),0,50)->'changes'),1,'snapshot page returns the finalized change');
insert into public.phase8_drive_snapshots(id,owner_id,high_water,expires_at)
values ('99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111',2,now()+interval '1 hour');
select throws_ok($$select public.phase8_read_drive_snapshot_page(
  '11111111-1111-4111-8111-111111111111',
  '99999999-9999-4999-8999-999999999999',1,50)$$,
  '55000','page_sequence_gap','snapshot refuses a missing sequence instead of returning a non-advancing cursor');
insert into public.phase8_drive_manifests(
  owner_id,source_identity,drive_id,idempotency_key,contract_version,
  payload_fingerprint,object_sha256,object_bytes,object_path,change_sequence
) values (
  '22222222-2222-4222-8222-222222222222','44444444-4444-4444-8444-444444444444',
  'synthetic-drive-gap','owner-sync-v2:'||repeat('d',64),2,repeat('e',64),repeat('f',64),100,
  '22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/envelope.json',2
);
insert into public.phase8_drive_changes(
  owner_id,sequence,source_identity,operation,idempotency_key,payload_fingerprint,object_sha256,object_path
) values (
  '22222222-2222-4222-8222-222222222222',2,'44444444-4444-4444-8444-444444444444',
  'drive_upsert','owner-sync-v2:'||repeat('d',64),repeat('e',64),repeat('f',64),
  '22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/envelope.json'
);
insert into public.phase8_drive_snapshots(id,owner_id,high_water,expires_at)
values ('88888888-8888-4888-8888-888888888888',
  '22222222-2222-4222-8222-222222222222',2,now()+interval '1 hour');
select throws_ok($$select public.phase8_read_drive_snapshot_page(
  '22222222-2222-4222-8222-222222222222',
  '88888888-8888-4888-8888-888888888888',0,50)$$,
  '55000','page_sequence_gap','snapshot rejects a leading gap instead of skipping directly to a later row');
select throws_ok($$select public.phase8_read_drive_snapshot_page(
  '11111111-1111-4111-8111-111111111111',
  (select (result->>'snapshot_id')::uuid from phase8_test_snapshot),null,50)$$,
  '22023','page_invalid','null page cursor is rejected');
select throws_ok($$select * from public.phase8_claim_drive_orphans(null)$$,
  '22023','cleanup_limit_invalid','null cleanup limit is rejected');

select lives_ok($$select public.phase8_begin_drive_upload(
  '11111111-1111-4111-8111-111111111111'::uuid,
  '["local_account_store_v1","account","11111111-1111-4111-8111-111111111111"]'::text,
  '77777777-7777-4777-8777-777777777777'::uuid,
  ('owner-sync-v2:'||repeat('4',64))::text,2::smallint,repeat('5',64),repeat('6',64),128)$$,
  'service reservation creates synthetic stale staging intent');
update public.phase8_drive_upload_intents set last_activity_at=now()-interval '8 days'
  where idempotency_key='owner-sync-v2:'||repeat('4',64);
create temporary table phase8_test_cleanup_claims on commit drop as
  select * from public.phase8_claim_drive_orphans(100);
select is((select count(*)::integer from phase8_test_cleanup_claims),1,'cleanup claims only stale unfinished staging intent');
select is(public.phase8_expire_drive_orphan((select intent_id from phase8_test_cleanup_claims)),true,'cleanup marks claimed orphan expired');
select is((select count(*)::integer from public.phase8_drive_manifests where source_identity='66666666-6666-4666-8666-666666666666'),1,'cleanup leaves finalized drive manifest intact');

select * from finish();
rollback;
