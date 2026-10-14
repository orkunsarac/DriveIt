-- Phase 8 DEV only. Additive owner-drive sync schema; never run from the
-- repository-root Supabase workspace. The first deployment requires explicit
-- approval and a verified isolated Project Ref.
create table if not exists public.phase8_drive_upload_intents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null check (idempotency_key ~ '^owner-sync-v2:[0-9a-f]{64}$'),
  source_identity uuid not null check (
    substring(source_identity::text from 15 for 1) = '4'
    and substring(source_identity::text from 20 for 1) in ('8','9','a','b')
  ),
  owner_scope text not null,
  contract_version smallint not null check (contract_version = 2),
  payload_fingerprint text not null check (payload_fingerprint ~ '^[0-9a-f]{64}$'),
  object_sha256 text not null check (object_sha256 ~ '^[0-9a-f]{64}$'),
  object_bytes integer not null check (object_bytes between 1 and 10485760),
  staging_path text not null unique,
  state text not null default 'staging'
    check (state in ('staging','finalized','cleanup_pending','expired')),
  receipt jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  finalized_at timestamptz,
  unique (owner_id, idempotency_key),
  unique (owner_id, source_identity),
  check (owner_scope = '["local_account_store_v1","account","' || owner_id::text || '"]'),
  check (staging_path = owner_id::text || '/' || id::text || '/envelope.json'),
  check ((state = 'finalized') = (receipt is not null and finalized_at is not null))
);

create table if not exists public.phase8_drive_owner_sequences (
  owner_id uuid primary key references auth.users(id) on delete restrict,
  high_water bigint not null default 0 check (high_water >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.phase8_drive_manifests (
  owner_id uuid not null references auth.users(id) on delete restrict,
  source_identity uuid not null,
  drive_id text not null check (length(drive_id) between 1 and 128),
  idempotency_key text not null,
  contract_version smallint not null check (contract_version = 2),
  payload_fingerprint text not null check (payload_fingerprint ~ '^[0-9a-f]{64}$'),
  object_sha256 text not null check (object_sha256 ~ '^[0-9a-f]{64}$'),
  object_bytes integer not null check (object_bytes between 1 and 10485760),
  object_path text not null,
  change_sequence bigint not null check (change_sequence > 0),
  finalized_at timestamptz not null default now(),
  primary key (owner_id, source_identity),
  unique (owner_id, idempotency_key),
  unique (owner_id, change_sequence),
  foreign key (owner_id, idempotency_key)
    references public.phase8_drive_upload_intents(owner_id, idempotency_key)
    on delete restrict
);

create table if not exists public.phase8_drive_changes (
  owner_id uuid not null references auth.users(id) on delete restrict,
  sequence bigint not null check (sequence > 0),
  source_identity uuid not null,
  operation text not null check (operation = 'drive_upsert'),
  idempotency_key text not null,
  payload_fingerprint text not null check (payload_fingerprint ~ '^[0-9a-f]{64}$'),
  object_sha256 text not null check (object_sha256 ~ '^[0-9a-f]{64}$'),
  object_path text not null,
  created_at timestamptz not null default now(),
  primary key (owner_id, sequence),
  unique (owner_id, idempotency_key),
  foreign key (owner_id, source_identity)
    references public.phase8_drive_manifests(owner_id, source_identity)
    on delete restrict
);

create table if not exists public.phase8_drive_snapshots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  high_water bigint not null check (high_water >= 0),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists phase8_drive_snapshots_expiry_idx
  on public.phase8_drive_snapshots(expires_at);

create or replace function public.phase8_reject_immutable_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception using errcode='55000',message='phase8_row_immutable';
end;
$$;
revoke all on function public.phase8_reject_immutable_mutation() from public,anon,authenticated,service_role;
drop trigger if exists phase8_drive_manifests_immutable on public.phase8_drive_manifests;
create trigger phase8_drive_manifests_immutable before update or delete
  on public.phase8_drive_manifests for each row execute function public.phase8_reject_immutable_mutation();
drop trigger if exists phase8_drive_changes_immutable on public.phase8_drive_changes;
create trigger phase8_drive_changes_immutable before update or delete
  on public.phase8_drive_changes for each row execute function public.phase8_reject_immutable_mutation();

alter table public.phase8_drive_upload_intents enable row level security;
alter table public.phase8_drive_owner_sequences enable row level security;
alter table public.phase8_drive_manifests enable row level security;
alter table public.phase8_drive_changes enable row level security;
alter table public.phase8_drive_snapshots enable row level security;

revoke all on public.phase8_drive_upload_intents,
  public.phase8_drive_owner_sequences, public.phase8_drive_manifests,
  public.phase8_drive_changes, public.phase8_drive_snapshots from public, anon, authenticated;
grant all on public.phase8_drive_upload_intents,
  public.phase8_drive_owner_sequences, public.phase8_drive_manifests,
  public.phase8_drive_changes, public.phase8_drive_snapshots to service_role;

-- No direct client table access: Authenticated Edge handlers verify the JWT,
-- derive auth.uid(), and call narrowly granted service-role RPCs.
-- Storage stays private; this policy allows access only to the caller's exact
-- still-staging intent object. No list/final-object/delete policy is provided.
create or replace function public.phase8_can_access_staging_object(p_name text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.phase8_drive_upload_intents i
    where i.owner_id = auth.uid()
      and i.state = 'staging'
      and i.staging_path = p_name
  );
$$;
revoke all on function public.phase8_can_access_staging_object(text) from public, anon;
grant execute on function public.phase8_can_access_staging_object(text) to authenticated;

drop policy if exists phase8_drive_stage_insert on storage.objects;
create policy phase8_drive_stage_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'phase8-drive-staging'
  and public.phase8_can_access_staging_object(name));

-- No SELECT/list, UPDATE/upsert, or DELETE policy is provided. A retry that
-- encounters an existing object must call finalize; the server validates its
-- exact size/hash before returning the durable receipt. A conflicting object
-- therefore cannot be silently replaced or exposed before finalization.

create or replace function public.phase8_begin_drive_upload(
  p_owner_id uuid,
  p_owner_scope text,
  p_source_identity uuid,
  p_idempotency_key text,
  p_contract_version smallint,
  p_payload_fingerprint text,
  p_object_sha256 text,
  p_object_bytes integer
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_intent public.phase8_drive_upload_intents%rowtype;
  v_id uuid;
begin
  -- This RPC is service-role-only. Its caller is the Edge handler, which
  -- validates the bearer JWT with Auth and passes that verified UID.
  if p_owner_id is null then raise exception using errcode='42501',message='owner_mismatch'; end if;
  if p_owner_scope is distinct from '["local_account_store_v1","account","' || p_owner_id::text || '"]'
     or p_source_identity is null
     or substring(p_source_identity::text from 15 for 1) <> '4'
     or substring(p_source_identity::text from 20 for 1) not in ('8','9','a','b')
     or p_idempotency_key is null
     or p_idempotency_key !~ '^owner-sync-v2:[0-9a-f]{64}$'
     or p_contract_version is distinct from 2
     or p_payload_fingerprint is null
     or p_payload_fingerprint !~ '^[0-9a-f]{64}$'
     or p_object_sha256 is null
     or p_object_sha256 !~ '^[0-9a-f]{64}$'
     or p_object_bytes is null
     or p_object_bytes not between 1 and 10485760 then
    raise exception using errcode = '22023', message = 'upload_claim_invalid';
  end if;
  select * into v_intent from public.phase8_drive_upload_intents
    where owner_id=p_owner_id and idempotency_key=p_idempotency_key for update;
  if found then
    if v_intent.source_identity <> p_source_identity
       or v_intent.owner_scope <> p_owner_scope
       or v_intent.contract_version <> p_contract_version
       or v_intent.payload_fingerprint <> p_payload_fingerprint
       or v_intent.object_sha256 <> p_object_sha256
       or v_intent.object_bytes <> p_object_bytes then
      raise exception using errcode = '23505', message = 'idempotency_claim_conflict';
    end if;
    if v_intent.state = 'expired' or v_intent.state = 'cleanup_pending' then
      raise exception using errcode = '55000', message = 'intent_not_retryable';
    end if;
    update public.phase8_drive_upload_intents set
      updated_at=now(), last_activity_at=now()
      where id=v_intent.id and state='staging';
    return jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'receipt',v_intent.receipt);
  end if;
  if exists (select 1 from public.phase8_drive_upload_intents
      where owner_id=p_owner_id and source_identity=p_source_identity) then
    raise exception using errcode = '23505', message = 'source_identity_conflict';
  end if;
  v_id := gen_random_uuid();
  insert into public.phase8_drive_upload_intents(
    id,owner_id,idempotency_key,source_identity,owner_scope,contract_version,
    payload_fingerprint,object_sha256,object_bytes,staging_path
  ) values (
    v_id,p_owner_id,p_idempotency_key,p_source_identity,p_owner_scope,p_contract_version,
    p_payload_fingerprint,p_object_sha256,p_object_bytes,
    p_owner_id::text || '/' || v_id::text || '/envelope.json'
  ) returning * into v_intent;
  return jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'receipt',null);
end;
$$;

create or replace function public.phase8_finalize_drive_upload(
  p_owner_id uuid,
  p_intent_id uuid,
  p_drive_id text,
  p_payload_fingerprint text,
  p_object_sha256 text,
  p_object_bytes integer
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  i public.phase8_drive_upload_intents%rowtype;
  v_seq bigint;
  v_receipt jsonb;
  v_prior public.phase8_drive_manifests%rowtype;
begin
  -- Reject incomplete claims before either first finalization or ACK replay.
  -- SQL NULL comparisons otherwise evaluate to UNKNOWN and can bypass a
  -- compound IF predicate under three-valued logic.
  if p_owner_id is null or p_intent_id is null or p_drive_id is null
     or length(p_drive_id) not between 1 and 128
     or p_payload_fingerprint is null
     or p_payload_fingerprint !~ '^[0-9a-f]{64}$'
     or p_object_sha256 is null
     or p_object_sha256 !~ '^[0-9a-f]{64}$'
     or p_object_bytes is null
     or p_object_bytes not between 1 and 10485760 then
    raise exception using errcode='22023',message='finalization_claim_invalid';
  end if;
  select * into i from public.phase8_drive_upload_intents
    where id=p_intent_id and owner_id=p_owner_id for update;
  if not found then raise exception using errcode = 'P0002', message='intent_missing'; end if;
  if i.state='finalized' then
    if i.payload_fingerprint<>p_payload_fingerprint or i.object_sha256<>p_object_sha256
       or i.object_bytes<>p_object_bytes then
      raise exception using errcode='23505', message='finalized_claim_conflict';
    end if;
    return i.receipt;
  end if;
  if i.state<>'staging' or i.payload_fingerprint<>p_payload_fingerprint
     or i.object_sha256<>p_object_sha256 or i.object_bytes<>p_object_bytes
     or p_drive_id is null or length(p_drive_id) not between 1 and 128 then
    raise exception using errcode='22023', message='finalization_claim_invalid';
  end if;
  select * into v_prior from public.phase8_drive_manifests
    where owner_id=i.owner_id and source_identity=i.source_identity;
  if found then
    if v_prior.idempotency_key<>i.idempotency_key
       or v_prior.payload_fingerprint<>i.payload_fingerprint
       or v_prior.object_sha256<>i.object_sha256
       or v_prior.object_bytes<>i.object_bytes
       or v_prior.object_path<>i.staging_path
       or v_prior.drive_id<>p_drive_id then
      raise exception using errcode='23505', message='source_identity_conflict';
    end if;
    -- The manifest/change/receipt are committed in one transaction. Finding
    -- a matching manifest while its intent is still staging is database
    -- invariant drift, not a successful ACK or a retryable success.
    raise exception using errcode='55000', message='finalization_receipt_missing';
  end if;
  insert into public.phase8_drive_owner_sequences(owner_id,high_water)
    values(i.owner_id,0) on conflict(owner_id) do nothing;
  select high_water into v_seq from public.phase8_drive_owner_sequences
    where owner_id=i.owner_id for update;
  v_seq := v_seq + 1;
  update public.phase8_drive_owner_sequences set high_water=v_seq,updated_at=now()
    where owner_id=i.owner_id;
  insert into public.phase8_drive_manifests(
    owner_id,source_identity,drive_id,idempotency_key,contract_version,
    payload_fingerprint,object_sha256,object_bytes,object_path,change_sequence
  ) values (
    i.owner_id,i.source_identity,p_drive_id,i.idempotency_key,i.contract_version,
    i.payload_fingerprint,i.object_sha256,i.object_bytes,i.staging_path,v_seq
  );
  insert into public.phase8_drive_changes(
    owner_id,sequence,source_identity,operation,idempotency_key,
    payload_fingerprint,object_sha256,object_path
  ) values (
    i.owner_id,v_seq,i.source_identity,'drive_upsert',i.idempotency_key,
    i.payload_fingerprint,i.object_sha256,i.staging_path
  );
  v_receipt := jsonb_build_object(
    'ownerScope',i.owner_scope,'idempotencyKey',i.idempotency_key,
    'payloadFingerprint',i.payload_fingerprint,
    'remoteId','drive:' || i.source_identity::text
  );
  update public.phase8_drive_upload_intents set state='finalized',receipt=v_receipt,
    finalized_at=now(),updated_at=now(),last_activity_at=now() where id=i.id;
  return v_receipt;
end;
$$;

create or replace function public.phase8_begin_drive_snapshot(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_high bigint;
begin
  insert into public.phase8_drive_owner_sequences(owner_id,high_water)
    values(p_owner_id,0) on conflict(owner_id) do nothing;
  select high_water into v_high from public.phase8_drive_owner_sequences where owner_id=p_owner_id;
  insert into public.phase8_drive_snapshots(owner_id,high_water) values(p_owner_id,v_high) returning id into v_id;
  return jsonb_build_object('snapshot_id',v_id,'high_water',v_high,'expires_at',now()+interval '24 hours');
end;
$$;

create or replace function public.phase8_read_drive_snapshot_page(
  p_owner_id uuid,p_snapshot_id uuid,p_after_sequence bigint,p_limit integer
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare s public.phase8_drive_snapshots%rowtype; v_rows jsonb; v_next bigint; v_first bigint; v_count integer;
begin
  if p_limit is null or p_after_sequence is null
     or p_limit not between 1 and 100 or p_after_sequence<0 then
    raise exception using errcode='22023',message='page_invalid'; end if;
  select * into s from public.phase8_drive_snapshots
    where id=p_snapshot_id and owner_id=p_owner_id and expires_at>now();
  if not found or p_after_sequence>s.high_water then
    raise exception using errcode='42501',message='snapshot_invalid'; end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.sequence),'[]'::jsonb),
    coalesce(max(q.sequence),p_after_sequence), min(q.sequence), count(*)::integer
    into v_rows,v_next,v_first,v_count from (
      select sequence,source_identity,operation,idempotency_key,payload_fingerprint,
        object_sha256,object_path from public.phase8_drive_changes
      where owner_id=p_owner_id and sequence>p_after_sequence and sequence<=s.high_water
      order by sequence limit p_limit
    ) q;
  if v_count > 0 and
     (v_first <> p_after_sequence + 1 or v_next <> v_first + v_count - 1) then
    raise exception using errcode='55000',message='page_sequence_gap';
  end if;
  if v_next = p_after_sequence and p_after_sequence < s.high_water then
    raise exception using errcode='55000',message='page_sequence_gap';
  end if;
  return jsonb_build_object('snapshot_id',s.id,'from',p_after_sequence,
    'next',v_next,'high_water',s.high_water,'changes',v_rows);
end;
$$;

create or replace function public.phase8_claim_drive_orphans(p_limit integer)
returns table(intent_id uuid, staging_path text)
language plpgsql security definer set search_path = '' as $$
begin
  if p_limit is null or p_limit not between 1 and 100 then raise exception using errcode='22023',message='cleanup_limit_invalid'; end if;
  return query
    with candidates as (
      select i.id from public.phase8_drive_upload_intents i
      where i.state='cleanup_pending'
         or (i.state='staging' and i.last_activity_at < now()-interval '7 days')
      order by i.last_activity_at limit p_limit
      for update skip locked
    ), claimed as (
      update public.phase8_drive_upload_intents i set state='cleanup_pending',updated_at=now()
      from candidates c where i.id=c.id and i.state in ('staging','cleanup_pending')
      returning i.id,i.staging_path
    ) select claimed.id,claimed.staging_path from claimed;
end;
$$;

create or replace function public.phase8_expire_drive_orphan(p_intent_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update public.phase8_drive_upload_intents
    set state='expired',updated_at=now()
    where id=p_intent_id and state='cleanup_pending';
  return found;
end;
$$;

revoke all on function public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer) from public,anon,authenticated;
grant execute on function public.phase8_begin_drive_upload(uuid,text,uuid,text,smallint,text,text,integer) to service_role;
revoke all on function public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer) from public,anon,authenticated;
grant execute on function public.phase8_finalize_drive_upload(uuid,uuid,text,text,text,integer) to service_role;
revoke all on function public.phase8_begin_drive_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.phase8_begin_drive_snapshot(uuid) to service_role;
revoke all on function public.phase8_read_drive_snapshot_page(uuid,uuid,bigint,integer) from public,anon,authenticated;
grant execute on function public.phase8_read_drive_snapshot_page(uuid,uuid,bigint,integer) to service_role;
revoke all on function public.phase8_claim_drive_orphans(integer) from public,anon,authenticated;
grant execute on function public.phase8_claim_drive_orphans(integer) to service_role;
revoke all on function public.phase8_expire_drive_orphan(uuid) from public,anon,authenticated;
grant execute on function public.phase8_expire_drive_orphan(uuid) to service_role;

comment on table public.phase8_drive_upload_intents is 'Phase 8 DEV only. Idempotent staging reservations; not visible to downloads until finalized.';
comment on table public.phase8_drive_manifests is 'Phase 8 DEV only. Immutable proven drive manifests; legacy and guest drives excluded.';
comment on table public.phase8_drive_changes is 'Phase 8 DEV only. Append-only per-owner finalized change sequence.';
