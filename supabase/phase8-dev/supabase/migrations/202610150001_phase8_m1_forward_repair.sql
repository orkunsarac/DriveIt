-- Forward-only repair for installations that already recorded 202610120001.
-- Keep the original migration unchanged. Reinstall the reviewed RPC bodies and
-- grants explicitly; preserve every existing intent/manifest/object/receipt.
-- The begin RPC remains server-only: Edge verifies Auth before passing UID.
begin;

create or replace function public.phase8_reject_immutable_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception using errcode='55000',message='phase8_row_immutable';
end;
$$;

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
  -- Serialize concurrent begin retries before a missing row can race INSERT.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'phase8_begin:' || p_owner_id::text || ':' || p_idempotency_key, 0));
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

revoke all on function public.phase8_reject_immutable_mutation() from public,anon,authenticated,service_role;
revoke all on function public.phase8_can_access_staging_object(text) from public, anon;
grant execute on function public.phase8_can_access_staging_object(text) to authenticated;
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

create or replace function public.phase8_drive_sync_capabilities(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_owner_id is null then
    raise exception using errcode='42501', message='owner_mismatch';
  end if;
  return jsonb_build_object(
    'contractVersion', 2, 'schemaRevision', '202610150001',
    'ownerScope', '["local_account_store_v1","account","' || p_owner_id::text || '"]',
    'driveUpload', true, 'driveDownload', true,
    'deleteSync', false, 'leaseFencing', false,
    'worldProjection', false, 'groupRealtime', false);
end;
$$;
revoke all on function public.phase8_drive_sync_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.phase8_drive_sync_capabilities(uuid) to service_role;

commit;
