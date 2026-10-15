begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(34);
insert into auth.users(id,aud,role,email) values('10101010-1010-4010-8010-101010101010','authenticated','authenticated','m2-local@example.invalid');
create temporary table m2_fixture as select
 '10101010-1010-4010-8010-101010101010'::uuid owner_id,
 '20202020-2020-4020-8020-202020202020'::uuid source_id;
select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]',source_id,
 'owner-sync-v2:'||repeat('1',64),2::smallint,repeat('2',64),repeat('3',64),100) from m2_fixture;
select public.phase8_finalize_drive_upload(owner_id,(select id from public.phase8_drive_upload_intents where owner_id=f.owner_id),
 'm2-local',repeat('2',64),repeat('3',64),100) from m2_fixture f;
create temporary table m2_snapshot as select (public.phase8_begin_drive_snapshot(owner_id)->>'snapshot_id')::uuid id from m2_fixture;
create temporary table m2_mutation as select jsonb_build_object(
 'version',2,'kind','driveTombstone','ownerId',owner_id::text,
 'ownerScope','["local_account_store_v1","account","'||owner_id::text||'"]',
 'sourceIdentity',source_id::text,'idempotencyKey','owner-sync-v2:'||repeat('4',64),'payloadFingerprint',repeat('5',64),
 'payload',jsonb_build_object('deletionId','30303030-3030-4030-8030-303030303030','deletedAt','2026-10-15T00:00:00Z',
 'observedRemoteSequence',1,'observedPayloadFingerprint',repeat('2',64),'causalVersion',1)) m from m2_fixture;
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_tombstones'::regclass),'tombstone RLS');
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_leases'::regclass),'lease RLS');
select ok(not has_table_privilege('authenticated','public.phase8_drive_tombstones','SELECT'),'no direct tombstone leak');
select ok(not has_table_privilege('anon','public.phase8_drive_leases','SELECT'),'no anonymous lease leak');
select ok(not has_function_privilege('authenticated','public.phase8_delete_drive(uuid,uuid,uuid,bigint,text,jsonb)','EXECUTE'),'forged owner RPC denied');
select ok(not has_function_privilege('service_role','public.phase8_m1_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)','EXECUTE'),'old begin bypass revoked');
select ok(not has_function_privilege('service_role','public.phase8_m1_finalize_drive_upload(uuid,uuid,text,text,text,integer)','EXECUTE'),'old finalize bypass revoked');
select ok(not has_function_privilege('service_role','public.phase8_m1_read_drive_snapshot_page(uuid,uuid,bigint,integer)','EXECUTE'),'old snapshot bypass revoked');
select throws_ok($q$select public.phase8_delete_drive('99999999-9999-4999-8999-999999999999','20202020-2020-4020-8020-202020202020',
 '30303030-3030-4030-8030-303030303030',1,repeat('2',64),(select m from m2_mutation))$q$,'P0002','source_missing','other owner cannot delete');
select throws_ok($q$select public.phase8_delete_drive(owner_id,source_id,'30303030-3030-4030-8030-303030303030',2,repeat('2',64),m)
 from m2_fixture,m2_mutation$q$,'22023','deletion_claim_invalid','wrong observed revision denied');
select lives_ok($q$select public.phase8_delete_drive(owner_id,source_id,'30303030-3030-4030-8030-303030303030',1,repeat('2',64),m)
 from m2_fixture,m2_mutation$q$,'delete commits');
select lives_ok($q$select public.phase8_delete_drive(owner_id,source_id,'30303030-3030-4030-8030-303030303030',1,repeat('2',64),m)
 from m2_fixture,m2_mutation$q$,'lost ACK retry');
select is((select count(*)::int from public.phase8_drive_tombstones where owner_id=(select owner_id from m2_fixture)),1,'one permanent tombstone');
select is((select high_water from public.phase8_drive_owner_sequences where owner_id=(select owner_id from m2_fixture)),2::bigint,'one delete sequence');
select is((select count(*)::int from public.phase8_drive_manifests where owner_id=(select owner_id from m2_fixture)),1,'immutable content not destroyed');
select is((select public.phase8_read_drive_snapshot_page(owner_id,s.id,0,10)->'changes'->0->>'operation'
 from m2_fixture,m2_snapshot s),'drive_tombstone','old snapshot redacted');
select throws_ok($q$select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]',source_id,
 'owner-sync-v2:'||repeat('1',64),2::smallint,repeat('2',64),repeat('3',64),100) from m2_fixture$q$,
 '55000','source_deleted','old upload replay denied');
select throws_ok($q$select public.phase8_finalize_drive_upload(owner_id,(select id from public.phase8_drive_upload_intents where owner_id=f.owner_id),
 'm2-local',repeat('2',64),repeat('3',64),100) from m2_fixture f$q$,'55000','source_deleted','old finalization ACK replay denied');
select throws_ok($q$update public.phase8_drive_tombstones set accepted_at=now()$q$,'55000','phase8_row_immutable','tombstone cannot mutate');
select is((public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '50505050-5050-4050-8050-505050505050','session','acquire')->>'fencing_token')::int,1,'first fencing token');
select is((public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '50505050-5050-4050-8050-505050505050','session','heartbeat',1)->>'fencing_token')::int,1,'heartbeat keeps token');
select ok((select expires_at-heartbeat_at=interval '3 minutes' from public.phase8_drive_leases where session_id='session'),'3 minute expiry');
select throws_ok($q$select public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '60606060-6060-4060-8060-606060606060','other','acquire')$q$,'PT409','lease_held','other device cannot steal live lease');
select throws_ok($q$select public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '50505050-5050-4050-8050-505050505050','session','heartbeat',2)$q$,'PT409','lease_fenced','stale token denied');
select ok(not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname like 'phase8_%' and prosecdef
 and not(coalesce(proconfig,'{}') @> array['search_path=""'])),'all definers pin search_path');
set local role authenticated;
select throws_ok($q$select public.phase8_delete_drive('10101010-1010-4010-8010-101010101010','20202020-2020-4020-8020-202020202020',
 '30303030-3030-4030-8030-303030303030',1,repeat('2',64),'{}'::jsonb)$q$,'42501',null,'actual forged owner RPC denied');
select throws_ok('select * from public.phase8_drive_tombstones','42501',null,'actual authenticated table read denied');
reset role;
set local role anon;
select throws_ok('select * from public.phase8_drive_leases','42501',null,'actual anonymous lease read denied');
reset role;
select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]',
 '40404040-4040-4040-8040-404040404040','owner-sync-v2:'||repeat('6',64),2::smallint,repeat('2',64),repeat('3',64),100) from m2_fixture;
select throws_ok($q$select public.phase8_finalize_drive_upload(owner_id,(select id from public.phase8_drive_upload_intents where source_identity='40404040-4040-4040-8040-404040404040'),
 'leased',repeat('2',64),repeat('3',64),100) from m2_fixture$q$,'PT409','lease_fenced','old unfenced finalization denied');
select lives_ok($q$select public.phase8_finalize_drive_upload_fenced(owner_id,(select id from public.phase8_drive_upload_intents where source_identity='40404040-4040-4040-8040-404040404040'),
 'leased',repeat('2',64),repeat('3',64),100,'50505050-5050-4050-8050-505050505050','session',1) from m2_fixture$q$,'current fencing token finalizes');
update public.phase8_drive_leases set heartbeat_at=now()-interval '4 minutes',expires_at=now()-interval '1 minute' where session_id='session';
select throws_ok($q$select public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '50505050-5050-4050-8050-505050505050','session','heartbeat',1)$q$,'PT409','lease_fenced','expired heartbeat cannot revive old token');
select is((public.phase8_drive_lease('10101010-1010-4010-8010-101010101010','40404040-4040-4040-8040-404040404040',
 '60606060-6060-4060-8060-606060606060','other','acquire')->>'fencing_token')::int,2,'expired lease acquisition increments token');
select throws_ok($q$select public.phase8_finalize_drive_upload_fenced(owner_id,(select id from public.phase8_drive_upload_intents where source_identity='40404040-4040-4040-8040-404040404040'),
 'leased',repeat('2',64),repeat('3',64),100,'50505050-5050-4050-8050-505050505050','session',1) from m2_fixture$q$,'PT409','lease_fenced','old token cannot replay finalized ACK');
select is((select count(*)::int from public.phase8_drive_changes where source_identity='40404040-4040-4040-8040-404040404040'),1,'fenced retry does not create duplicates');
select * from finish();
rollback;
