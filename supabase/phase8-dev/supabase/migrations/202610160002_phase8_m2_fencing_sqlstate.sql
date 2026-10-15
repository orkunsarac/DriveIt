-- Forward-only business-error compatibility repair for PostgREST 14.
-- PT409 is HTTP conflict, not a retryable PostgreSQL serialization failure.
-- CREATE OR REPLACE retains signatures, owners and existing EXECUTE ACLs.
begin;
create or replace function public.phase8_finalize_drive_upload_fenced(p_owner_id uuid,p_intent_id uuid,p_drive_id text,
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
 then raise exception using errcode='PT409',message='lease_fenced'; end if;
 if not found and (p_device_id is not null or p_session_id is not null or p_fencing_token is not null)
 then raise exception using errcode='PT409',message='lease_missing'; end if;
 r:=public.phase8_m1_finalize_drive_upload(p_owner_id,p_intent_id,p_drive_id,p_payload_fingerprint,p_object_sha256,p_object_bytes);
 select change_sequence into seq from public.phase8_drive_manifests where owner_id=p_owner_id and source_identity=v_source;
 return r || jsonb_build_object('changeSequence',seq);
end; $$;

create or replace function public.phase8_drive_lease(p_owner_id uuid,p_source_identity uuid,p_device_id uuid,p_session_id text,
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
  then raise exception using errcode='PT409',message='lease_fenced'; end if;
 elsif found and l.expires_at>t and (l.device_id<>p_device_id or l.session_id<>p_session_id) then
  raise exception using errcode='PT409',message='lease_held';
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
commit;
