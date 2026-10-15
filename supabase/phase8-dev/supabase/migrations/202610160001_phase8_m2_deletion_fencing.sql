-- M2 candidate. LOCAL ONLY until separately approved for Planet DEV.
-- M1 files/history remain immutable. Logical History deletion retains private
-- content and independent World/Career evidence; it never deletes Auth/Planet.
begin;
create table public.phase8_drive_tombstones (
  owner_id uuid not null references auth.users(id) on delete restrict,
  source_identity uuid not null,
  deletion_id uuid not null,
  mutation jsonb not null,
  observed_sequence bigint not null check (observed_sequence > 0),
  change_sequence bigint not null check (change_sequence > observed_sequence),
  deleted_at timestamptz not null,
  accepted_at timestamptz not null default now(),
  primary key(owner_id, source_identity), unique(owner_id, deletion_id),
  foreign key(owner_id, source_identity) references public.phase8_drive_manifests(owner_id, source_identity)
);
create table public.phase8_drive_leases (
  owner_id uuid not null references auth.users(id) on delete restrict,
  source_identity uuid not null,
  device_id uuid not null,
  session_id text not null check (length(session_id) between 1 and 128),
  fencing_token bigint not null check (fencing_token > 0),
  heartbeat_at timestamptz not null,
  expires_at timestamptz not null,
  primary key(owner_id, source_identity),
  check (expires_at = heartbeat_at + interval '3 minutes')
);
alter table public.phase8_drive_tombstones enable row level security;
alter table public.phase8_drive_leases enable row level security;
revoke all on public.phase8_drive_tombstones, public.phase8_drive_leases from public,anon,authenticated;
grant select,insert on public.phase8_drive_tombstones to service_role;
grant select,insert,update on public.phase8_drive_leases to service_role;
create trigger phase8_tombstone_immutable before update or delete on public.phase8_drive_tombstones
 for each row execute function public.phase8_reject_immutable_mutation();
alter table public.phase8_drive_changes drop constraint phase8_drive_changes_operation_check;
alter table public.phase8_drive_changes add constraint phase8_drive_changes_operation_check
 check(operation in ('drive_upsert','drive_tombstone'));

-- One per-source lock orders begin/finalize/delete/lease. Owner sequence lock
-- is always acquired AFTER source lock; no inversion with M1 intent locks.
create function public.phase8_m2_lock(p_owner uuid,p_source uuid) returns void
language plpgsql set search_path='' as $$
begin
 if p_owner is null or p_source is null then raise exception 'identity_missing'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase8_m2:'||p_owner::text||':'||p_source::text,0));
end; $$;

alter function public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer)
 rename to phase8_m1_begin_drive_upload;
revoke all on function public.phase8_m1_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer) from public,anon,authenticated,service_role;
create function public.phase8_begin_drive_upload(p_owner_id uuid,p_owner_scope text,p_source_identity uuid,
 p_idempotency_key text,p_contract_version smallint,p_payload_fingerprint text,p_object_sha256 text,p_object_bytes integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb; seq bigint;
begin
 perform public.phase8_m2_lock(p_owner_id,p_source_identity);
 if exists(select 1 from public.phase8_drive_tombstones where owner_id=p_owner_id and source_identity=p_source_identity)
 then raise exception using errcode='55000',message='source_deleted'; end if;
 r:=public.phase8_m1_begin_drive_upload(p_owner_id,p_owner_scope,p_source_identity,p_idempotency_key,
 p_contract_version,p_payload_fingerprint,p_object_sha256,p_object_bytes);
 if r->>'state'='finalized' then
  select change_sequence into seq from public.phase8_drive_manifests where owner_id=p_owner_id and source_identity=p_source_identity;
  r:=jsonb_set(r,'{receipt}',(r->'receipt')||jsonb_build_object('changeSequence',seq));
 end if;
 return r;
end; $$;

alter function public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer)
 rename to phase8_m1_finalize_drive_upload;
revoke all on function public.phase8_m1_finalize_drive_upload(uuid,uuid,text,text,text,integer) from public,anon,authenticated,service_role;
create function public.phase8_finalize_drive_upload_fenced(p_owner_id uuid,p_intent_id uuid,p_drive_id text,
 p_payload_fingerprint text,p_object_sha256 text,p_object_bytes integer,
 p_device_id uuid default null,p_session_id text default null,p_fencing_token bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_source uuid; l public.phase8_drive_leases%rowtype; r jsonb; seq bigint;
begin
 select source_identity into v_source from public.phase8_drive_upload_intents where owner_id=p_owner_id and id=p_intent_id;
 if v_source is null then raise exception using errcode='P0002',message='intent_missing'; end if;
 perform public.phase8_m2_lock(p_owner_id,v_source);
 if exists(select 1 from public.phase8_drive_tombstones where owner_id=p_owner_id and source_identity=v_source)
 then raise exception using errcode='55000',message='source_deleted'; end if;
 select * into l from public.phase8_drive_leases where owner_id=p_owner_id and source_identity=v_source;
 if found and (l.device_id is distinct from p_device_id or l.session_id is distinct from p_session_id
   or l.fencing_token is distinct from p_fencing_token or l.expires_at<=clock_timestamp())
 then raise exception using errcode='40001',message='lease_fenced'; end if;
 if not found and (p_device_id is not null or p_session_id is not null or p_fencing_token is not null)
 then raise exception using errcode='40001',message='lease_missing'; end if;
 r:=public.phase8_m1_finalize_drive_upload(p_owner_id,p_intent_id,p_drive_id,p_payload_fingerprint,p_object_sha256,p_object_bytes);
 select change_sequence into seq from public.phase8_drive_manifests where owner_id=p_owner_id and source_identity=v_source;
 return r || jsonb_build_object('changeSequence',seq);
end; $$;
-- Old callers remain compatible only when no server lease was ever acquired.
create function public.phase8_finalize_drive_upload(p_owner_id uuid,p_intent_id uuid,p_drive_id text,
 p_payload_fingerprint text,p_object_sha256 text,p_object_bytes integer) returns jsonb
language sql security definer set search_path='' as $$
 select public.phase8_finalize_drive_upload_fenced(p_owner_id,p_intent_id,p_drive_id,p_payload_fingerprint,p_object_sha256,p_object_bytes);
$$;

create function public.phase8_drive_lease(p_owner_id uuid,p_source_identity uuid,p_device_id uuid,p_session_id text,
 p_action text,p_fencing_token bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare l public.phase8_drive_leases%rowtype; t timestamptz:=clock_timestamp();
begin
 if p_device_id is null or p_session_id is null or length(p_session_id) not between 1 and 128
 or p_action is null or p_action not in ('acquire','heartbeat') then raise exception 'lease_claim_invalid'; end if;
 perform public.phase8_m2_lock(p_owner_id,p_source_identity);
 if exists(select 1 from public.phase8_drive_tombstones where owner_id=p_owner_id and source_identity=p_source_identity)
 then raise exception 'source_deleted'; end if;
 select * into l from public.phase8_drive_leases where owner_id=p_owner_id and source_identity=p_source_identity;
 if p_action='heartbeat' then
  if not found or l.device_id<>p_device_id or l.session_id<>p_session_id or l.fencing_token is distinct from p_fencing_token or l.expires_at<=t
  then raise exception using errcode='40001',message='lease_fenced'; end if;
 elsif found and l.expires_at>t and (l.device_id<>p_device_id or l.session_id<>p_session_id) then
  raise exception using errcode='40001',message='lease_held';
 elsif found and l.expires_at>t then
  return to_jsonb(l); -- acquire replay never manufactures a new fencing token
 else
  l.fencing_token:=coalesce(l.fencing_token,0)+1;
 end if;
 insert into public.phase8_drive_leases values(p_owner_id,p_source_identity,p_device_id,p_session_id,l.fencing_token,t,t+interval '3 minutes')
 on conflict(owner_id,source_identity) do update set device_id=excluded.device_id,session_id=excluded.session_id,
 fencing_token=excluded.fencing_token,heartbeat_at=excluded.heartbeat_at,expires_at=excluded.expires_at returning * into l;
 return to_jsonb(l);
end; $$;

create function public.phase8_delete_drive(p_owner_id uuid,p_source_identity uuid,p_deletion_id uuid,
 p_observed_sequence bigint,p_observed_fingerprint text,p_mutation jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.phase8_drive_manifests%rowtype; d public.phase8_drive_tombstones%rowtype; seq bigint;
begin
 perform public.phase8_m2_lock(p_owner_id,p_source_identity);
 select * into d from public.phase8_drive_tombstones where owner_id=p_owner_id and source_identity=p_source_identity;
 if found then
  if d.deletion_id=p_deletion_id and d.mutation=p_mutation then return jsonb_build_object('mutation',d.mutation,'sequence',d.change_sequence); end if;
  raise exception using errcode='23505',message='deletion_conflict';
 end if;
 select * into m from public.phase8_drive_manifests where owner_id=p_owner_id and source_identity=p_source_identity;
 if not found then raise exception using errcode='P0002',message='source_missing'; end if;
 if p_deletion_id is null or substring(p_deletion_id::text from 15 for 1)<>'4'
 or p_observed_sequence is distinct from m.change_sequence or p_observed_fingerprint is distinct from m.payload_fingerprint
 or p_mutation is null or p_mutation->>'version' is distinct from '2'
 or p_mutation->>'kind' is distinct from 'driveTombstone'
 or p_mutation->>'ownerId' is distinct from p_owner_id::text
 or p_mutation->>'sourceIdentity' is distinct from p_source_identity::text
 or p_mutation->>'ownerScope' is distinct from '["local_account_store_v1","account","'||p_owner_id::text||'"]'
 or p_mutation->'payload'->>'deletionId' is distinct from p_deletion_id::text
 or p_mutation->'payload'->>'observedRemoteSequence' is distinct from p_observed_sequence::text
 or p_mutation->'payload'->>'observedPayloadFingerprint' is distinct from p_observed_fingerprint
 or p_mutation->'payload'->>'causalVersion' is distinct from '1'
 or p_mutation->'payload'->>'deletedAt' is null
 or coalesce(p_mutation->>'payloadFingerprint','') !~ '^[0-9a-f]{64}$'
 or coalesce(p_mutation->>'idempotencyKey','') !~ '^owner-sync-v2:[0-9a-f]{64}$'
 then raise exception using errcode='22023',message='deletion_claim_invalid'; end if;
 select high_water into seq from public.phase8_drive_owner_sequences where owner_id=p_owner_id for update;
 seq:=seq+1;
 update public.phase8_drive_owner_sequences set high_water=seq,updated_at=now() where owner_id=p_owner_id;
 insert into public.phase8_drive_tombstones values(p_owner_id,p_source_identity,p_deletion_id,p_mutation,p_observed_sequence,seq,
 (p_mutation->'payload'->>'deletedAt')::timestamptz,now());
 insert into public.phase8_drive_changes(owner_id,sequence,source_identity,operation,idempotency_key,payload_fingerprint,object_sha256,object_path)
 values(p_owner_id,seq,p_source_identity,'drive_tombstone',p_mutation->>'idempotencyKey',p_mutation->>'payloadFingerprint',m.object_sha256,m.object_path);
 return jsonb_build_object('mutation',p_mutation,'sequence',seq);
end; $$;

-- Preserve page ordering/high-water, but never hand out an older live payload
-- after its source was deleted, including from pre-deletion snapshots.
alter function public.phase8_read_drive_snapshot_page(uuid,uuid,bigint,integer) rename to phase8_m1_read_drive_snapshot_page;
revoke all on function public.phase8_m1_read_drive_snapshot_page(uuid,uuid,bigint,integer) from public,anon,authenticated,service_role;
create function public.phase8_read_drive_snapshot_page(p_owner_id uuid,p_snapshot_id uuid,p_after_sequence bigint,p_limit integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare page jsonb; rows jsonb;
begin
 page:=public.phase8_m1_read_drive_snapshot_page(p_owner_id,p_snapshot_id,p_after_sequence,p_limit);
 select coalesce(jsonb_agg(case when d.source_identity is null then r else
 r || jsonb_build_object('operation','drive_tombstone','mutation',d.mutation) end order by (r->>'sequence')::bigint),'[]'::jsonb)
 into rows from jsonb_array_elements(page->'changes') r left join public.phase8_drive_tombstones d
 on d.owner_id=p_owner_id and d.source_identity=(r->>'source_identity')::uuid;
 return jsonb_set(page,'{changes}',rows);
end; $$;

create or replace function public.phase8_drive_sync_capabilities(p_owner_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if p_owner_id is null then raise exception 'owner_missing'; end if;
 return jsonb_build_object('contractVersion',2,'schemaRevision','202610160001',
 'ownerScope','["local_account_store_v1","account","'||p_owner_id::text||'"]',
 'driveUpload',true,'driveDownload',true,'deleteSync',true,'leaseFencing',true,'worldProjection',false,'groupRealtime',false);
end; $$;

revoke all on function public.phase8_m2_lock(uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer),
 public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer),
 public.phase8_finalize_drive_upload_fenced(uuid,uuid,text,text,text,integer,uuid,text,bigint),
 public.phase8_drive_lease(uuid,uuid,uuid,text,text,bigint),
 public.phase8_delete_drive(uuid,uuid,uuid,bigint,text,jsonb),
 public.phase8_read_drive_snapshot_page(uuid,uuid,bigint,integer) from public,anon,authenticated;
grant execute on function public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer),
 public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer),
 public.phase8_finalize_drive_upload_fenced(uuid,uuid,text,text,text,integer,uuid,text,bigint),
 public.phase8_drive_lease(uuid,uuid,uuid,text,text,bigint),
 public.phase8_delete_drive(uuid,uuid,uuid,bigint,text,jsonb),
 public.phase8_read_drive_snapshot_page(uuid,uuid,bigint,integer) to service_role;
commit;
