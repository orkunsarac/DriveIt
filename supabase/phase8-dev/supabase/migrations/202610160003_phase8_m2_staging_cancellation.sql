-- Candidate: LOCAL ONLY until separately approved for Planet DEV.
-- Cancellation has a real intent/hash and its own server change sequence;
-- it never fabricates a finalized manifest or an observed manifest sequence.
begin;
create table public.phase8_drive_cancellations (
 owner_id uuid not null references auth.users(id) on delete restrict,
 source_identity uuid not null,
 intent_id uuid not null references public.phase8_drive_upload_intents(id),
 deletion_id uuid not null,
 mutation jsonb not null,
 change_sequence bigint not null check(change_sequence>0),
 accepted_at timestamptz not null default now(),
 primary key(owner_id,source_identity), unique(owner_id,deletion_id),
 unique(owner_id,change_sequence),
 foreign key(owner_id,source_identity) references public.phase8_drive_upload_intents(owner_id,source_identity)
);
alter table public.phase8_drive_cancellations enable row level security;
revoke all on public.phase8_drive_cancellations from public,anon,authenticated,service_role;
grant select,insert on public.phase8_drive_cancellations to service_role;
create trigger phase8_cancellation_immutable before update or delete on public.phase8_drive_cancellations
 for each row execute function public.phase8_reject_immutable_mutation();

-- All existing begin/finalize/lease/delete RPCs already enter this lock.
create or replace function public.phase8_m2_lock(p_owner uuid,p_source uuid) returns void
language plpgsql set search_path='' as $$
begin
 if p_owner is null or p_source is null then raise exception 'identity_missing'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase8_m2:'||p_owner::text||':'||p_source::text,0));
 if exists(select 1 from public.phase8_drive_cancellations where owner_id=p_owner and source_identity=p_source)
 then raise exception using errcode='PT409',message='source_cancelled'; end if;
end; $$;

create function public.phase8_cancel_staged_drive(p_owner_id uuid,p_source_identity uuid,p_intent_id uuid,
 p_deletion_id uuid,p_payload_fingerprint text,p_mutation jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare i public.phase8_drive_upload_intents%rowtype; c public.phase8_drive_cancellations%rowtype; seq bigint;
begin
 if p_owner_id is null or p_source_identity is null then raise exception 'identity_missing'; end if;
 -- Same source lock, but without the already-cancelled rejection: retry must work.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('phase8_m2:'||p_owner_id::text||':'||p_source_identity::text,0));
 select * into c from public.phase8_drive_cancellations where owner_id=p_owner_id and source_identity=p_source_identity;
 if found then
  if c.intent_id=p_intent_id and c.deletion_id=p_deletion_id and c.mutation=p_mutation
     and c.mutation->'payload'->>'cancelledPayloadFingerprint'=p_payload_fingerprint
  then return jsonb_build_object('mutation',c.mutation,'sequence',c.change_sequence); end if;
  raise exception using errcode='PT409',message='cancellation_conflict';
 end if;
 if exists(select 1 from public.phase8_drive_manifests where owner_id=p_owner_id and source_identity=p_source_identity)
 then raise exception using errcode='PT409',message='source_already_finalized'; end if;
 select * into i from public.phase8_drive_upload_intents where id=p_intent_id and owner_id=p_owner_id and source_identity=p_source_identity for update;
 if not found then raise exception using errcode='P0002',message='source_unavailable'; end if;
 if i.state='finalized' or p_payload_fingerprint is distinct from i.payload_fingerprint
 or p_deletion_id is null or substring(p_deletion_id::text from 15 for 1)<>'4'
 or p_mutation is null or p_mutation->>'version' is distinct from '2'
 or p_mutation->>'kind' is distinct from 'driveTombstone'
 or p_mutation->>'ownerId' is distinct from p_owner_id::text
 or p_mutation->>'ownerScope' is distinct from '["local_account_store_v1","account","'||p_owner_id::text||'"]'
 or p_mutation->>'sourceIdentity' is distinct from p_source_identity::text
 or p_mutation->'payload'->>'causalVersion' is distinct from '2'
 or p_mutation->'payload'->>'intentId' is distinct from p_intent_id::text
 or p_mutation->'payload'->>'cancelledPayloadFingerprint' is distinct from i.payload_fingerprint
 or p_mutation->'payload'->>'deletionId' is distinct from p_deletion_id::text
 or p_mutation->'payload'->>'deletedAt' is null
 or p_mutation->'payload' ? 'observedRemoteSequence'
 or coalesce(p_mutation->>'payloadFingerprint','') !~ '^[0-9a-f]{64}$'
 or coalesce(p_mutation->>'idempotencyKey','') !~ '^owner-sync-v2:[0-9a-f]{64}$'
 then raise exception using errcode='22023',message='cancellation_claim_invalid'; end if;
 perform (p_mutation->'payload'->>'deletedAt')::timestamptz;
 insert into public.phase8_drive_owner_sequences(owner_id,high_water) values(p_owner_id,0) on conflict(owner_id) do nothing;
 update public.phase8_drive_owner_sequences set high_water=high_water+1,updated_at=now() where owner_id=p_owner_id returning high_water into seq;
 insert into public.phase8_drive_cancellations(owner_id,source_identity,intent_id,deletion_id,mutation,change_sequence)
 values(p_owner_id,p_source_identity,p_intent_id,p_deletion_id,p_mutation,seq);
 update public.phase8_drive_upload_intents set state='expired',updated_at=now() where id=i.id;
 return jsonb_build_object('mutation',p_mutation,'sequence',seq);
end; $$;
revoke all on function public.phase8_cancel_staged_drive(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.phase8_cancel_staged_drive(uuid,uuid,uuid,uuid,text,jsonb) to service_role;

-- Merge cancellation events into the EXISTING owner sequence/snapshot protocol.
-- The old manifest FK and immutable change table are not weakened.
create or replace function public.phase8_read_drive_snapshot_page(p_owner_id uuid,p_snapshot_id uuid,p_after_sequence bigint,p_limit integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.phase8_drive_snapshots%rowtype; rows jsonb; nxt bigint; first_seq bigint; n integer;
begin
 if p_limit is null or p_after_sequence is null or p_limit not between 1 and 100 or p_after_sequence<0
 then raise exception using errcode='22023',message='page_invalid'; end if;
 select * into s from public.phase8_drive_snapshots where id=p_snapshot_id and owner_id=p_owner_id and expires_at>now();
 if not found or p_after_sequence>s.high_water then raise exception using errcode='42501',message='snapshot_invalid'; end if;
 select coalesce(jsonb_agg(q.row order by q.sequence),'[]'::jsonb),coalesce(max(q.sequence),p_after_sequence),min(q.sequence),count(*)::int
 into rows,nxt,first_seq,n from (
  select sequence,row from (
   select ch.sequence,to_jsonb(ch)||case when t.source_identity is null then '{}'::jsonb
     else jsonb_build_object('operation','drive_tombstone','mutation',t.mutation) end as row
   from public.phase8_drive_changes ch left join public.phase8_drive_tombstones t
     on t.owner_id=ch.owner_id and t.source_identity=ch.source_identity where ch.owner_id=p_owner_id
   union all
   select c.change_sequence,jsonb_build_object('sequence',c.change_sequence,'operation','drive_tombstone',
     'source_identity',c.source_identity,'mutation',c.mutation) from public.phase8_drive_cancellations c where c.owner_id=p_owner_id
  ) events where sequence>p_after_sequence and sequence<=s.high_water order by sequence limit p_limit
 ) q;
 if (n>0 and (first_seq<>p_after_sequence+1 or nxt<>first_seq+n-1)) or (nxt=p_after_sequence and p_after_sequence<s.high_water)
 then raise exception using errcode='55000',message='page_sequence_gap'; end if;
 return jsonb_build_object('snapshot_id',s.id,'from',p_after_sequence,'next',nxt,'high_water',s.high_water,'changes',rows);
end; $$;
commit;
