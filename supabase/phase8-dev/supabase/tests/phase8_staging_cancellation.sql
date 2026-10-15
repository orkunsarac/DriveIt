begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(22);
insert into auth.users(id,aud,role,email) values
 ('71717171-7171-4171-8171-717171717171','authenticated','authenticated','cancel-a@example.invalid'),
 ('72727272-7272-4272-8272-727272727272','authenticated','authenticated','cancel-b@example.invalid');
create temporary table cancel_fixture as select
 '71717171-7171-4171-8171-717171717171'::uuid owner_id,
 '73737373-7373-4373-8373-737373737373'::uuid source_id,
 '74747474-7474-4474-8474-747474747474'::uuid deletion_id;
select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]',source_id,
 'owner-sync-v2:'||repeat('1',64),2::smallint,repeat('2',64),repeat('3',64),100) from cancel_fixture;
alter table cancel_fixture add column intent_id uuid;
update cancel_fixture f set intent_id=(select id from public.phase8_drive_upload_intents where owner_id=f.owner_id and source_identity=f.source_id);
create temporary table cancel_mutation as select jsonb_build_object('version',2,'kind','driveTombstone',
 'ownerId',owner_id,'ownerScope','["local_account_store_v1","account","'||owner_id::text||'"]','sourceIdentity',source_id,
 'payloadFingerprint',repeat('4',64),'idempotencyKey','owner-sync-v2:'||repeat('5',64),
 'payload',jsonb_build_object('causalVersion',2,'deletionId',deletion_id,'deletedAt','2026-10-15T00:00:00Z',
 'intentId',intent_id,'cancelledPayloadFingerprint',repeat('2',64))) m from cancel_fixture;
select ok((select relrowsecurity from pg_class where oid='public.phase8_drive_cancellations'::regclass),'cancellation RLS');
select ok(not has_table_privilege('anon','public.phase8_drive_cancellations','SELECT'),'anon no cancellation access');
select ok(not has_table_privilege('authenticated','public.phase8_drive_cancellations','SELECT'),'authenticated no cancellation table access');
select ok(not has_function_privilege('anon','public.phase8_cancel_staged_drive(uuid,uuid,uuid,uuid,text,jsonb)','EXECUTE'),'anon cancellation RPC denied');
select ok(not has_function_privilege('authenticated','public.phase8_cancel_staged_drive(uuid,uuid,uuid,uuid,text,jsonb)','EXECUTE'),'forged owner RPC denied');
select ok(not has_function_privilege('service_role','public.phase8_m2_lock(uuid,uuid)','EXECUTE'),'no direct lock bypass');
select is((public.phase8_cancel_staged_drive(owner_id,source_id,intent_id,deletion_id,repeat('2',64),m)->>'sequence')::int,1,'cancel allocates actual owner sequence') from cancel_fixture,cancel_mutation;
select is((public.phase8_cancel_staged_drive(owner_id,source_id,intent_id,deletion_id,repeat('2',64),m)->>'sequence')::int,1,'cancel replay same receipt') from cancel_fixture,cancel_mutation;
select is((select count(*)::int from public.phase8_drive_cancellations where owner_id=f.owner_id),1,'one permanent cancellation') from cancel_fixture f;
select is((select state from public.phase8_drive_upload_intents where id=f.intent_id),'expired','staging permission revoked atomically') from cancel_fixture f;
select is((select count(*)::int from public.phase8_drive_manifests where owner_id=f.owner_id),0,'no invented manifest') from cancel_fixture f;
select throws_ok($q$select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]',source_id,
 'owner-sync-v2:'||repeat('1',64),2::smallint,repeat('2',64),repeat('3',64),100) from cancel_fixture$q$,'PT409','source_cancelled','old begin denied');
select throws_ok($q$select public.phase8_finalize_drive_upload(owner_id,intent_id,'local',repeat('2',64),repeat('3',64),100) from cancel_fixture$q$,'PT409','source_cancelled','delayed finalizer denied');
select throws_ok($q$select public.phase8_drive_lease(owner_id,source_id,'75757575-7575-4575-8575-757575757575','session','acquire') from cancel_fixture$q$,'PT409','source_cancelled','cancelled source lease denied');
select throws_ok($q$select public.phase8_cancel_staged_drive('72727272-7272-4272-8272-727272727272',source_id,intent_id,deletion_id,repeat('2',64),m) from cancel_fixture,cancel_mutation$q$,'P0002','source_unavailable','B cannot cancel A source');
select throws_ok($q$select public.phase8_cancel_staged_drive(owner_id,source_id,intent_id,deletion_id,repeat('2',64),jsonb_set(m,'{payload,deletedAt}','"2026-10-16T00:00:00Z"')) from cancel_fixture,cancel_mutation$q$,'PT409','cancellation_conflict','changed consent conflicts');
select throws_ok($q$update public.phase8_drive_cancellations set accepted_at=now() where owner_id=(select owner_id from cancel_fixture)$q$,'55000','phase8_row_immutable','cancellation immutable');
create temporary table cancel_snapshot as select (public.phase8_begin_drive_snapshot(owner_id)->>'snapshot_id')::uuid id from cancel_fixture;
select is((public.phase8_read_drive_snapshot_page(owner_id,s.id,0,1)->'changes'->0->'mutation'->'payload'->>'causalVersion')::int,2,'cursor emits real cancellation receipt') from cancel_fixture,cancel_snapshot s;
select is((public.phase8_read_drive_snapshot_page(owner_id,s.id,0,1)->>'next')::int,1,'cursor advances after complete cancellation page') from cancel_fixture,cancel_snapshot s;
select set_config('request.jwt.claim.sub','71717171-7171-4171-8171-717171717171',true);
select is(public.phase8_can_access_staging_object((select staging_path from public.phase8_drive_upload_intents where id=f.intent_id)),false,'storage access revoked without physical delete') from cancel_fixture f;
select public.phase8_begin_drive_upload(owner_id,'["local_account_store_v1","account","'||owner_id::text||'"]','76767676-7676-4676-8676-767676767676',
 'owner-sync-v2:'||repeat('6',64),2::smallint,repeat('2',64),repeat('3',64),100) from cancel_fixture;
create temporary table winner as select owner_id,id intent_id,source_identity from public.phase8_drive_upload_intents where source_identity='76767676-7676-4676-8676-767676767676';
select public.phase8_finalize_drive_upload(owner_id,intent_id,'winner',repeat('2',64),repeat('3',64),100) from winner;
select throws_ok($q$select public.phase8_cancel_staged_drive(owner_id,source_identity,intent_id,'77777777-7777-4777-8777-777777777777',repeat('2',64),(select m from cancel_mutation)) from winner$q$,'PT409','source_already_finalized','finalization winner requires normal tombstone');
select is((select count(*)::int from public.phase8_drive_manifests where drive_id='winner'),1,'M1 finalized winner preserved');
select * from finish();
rollback;
