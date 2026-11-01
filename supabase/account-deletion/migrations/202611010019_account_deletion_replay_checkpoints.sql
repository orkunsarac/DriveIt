begin;
-- Freeze bounded metadata, not raw GPS. Computation remains at most two roads
-- per invocation and retains the 32-road/500km working-set safety envelope.
do $$declare d text;guard text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure);
 guard:='exists(select 1 from public.account_deletion_jobs j join public.world_publishes p on p.user_id=j.owner_id where j.id<>p_id and j.state<>''completed'')';
 if position(guard in d)=0 or position('user_id<>v)>32' in d)=0 then raise exception 'unexpected_replay_context_contract';end if;
 d:=replace(d,guard,'false');
 d:=replace(d,'user_id<>v)>32','user_id<>v)>128');
 d:=replace(d,'where r.user_id<>v','where r.user_id<>v and not exists(select 1 from public.account_deletion_jobs deleting where deleting.owner_id=r.user_id and deleting.state<>''completed'')');
 execute d;
end;$$;

create table public.account_deletion_replays(
 job_id uuid primary key references public.account_deletion_jobs(id) on delete cascade,
 snapshot jsonb not null,traces jsonb not null default '[]',next_index integer not null default 0,
 version bigint not null default 0,updated_at timestamptz not null default clock_timestamp(),
 check(jsonb_typeof(traces)='array' and jsonb_array_length(traces)<=256),check(octet_length(snapshot::text)<=2200000),check(octet_length(traces::text)<=1048576)
);
alter table public.account_deletion_replays enable row level security;
revoke all on public.account_deletion_replays from public,anon,authenticated,service_role;

-- Reuse the existing final commit's canonical interval/provenance validation
-- for every private checkpoint too. No client can submit checkpoint plans.
do $$declare d text;body text;a integer;b integer;begin
 d:=pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 a:=position('if jsonb_typeof(p_traces)' in d);b:=position('-- One transaction:' in d);
 if a=0 or b<=a then raise exception 'unexpected_plan_validation_contract';end if;
 body:=substring(d from a for b-a);
 execute 'create function public.account_deletion_replay_validate(p_id uuid,c jsonb,p_traces jsonb) returns void language plpgsql security definer set search_path='''''||' as $validate$
 declare v uuid;g bigint;t jsonb;r public.world_validated_roads%rowtype;s public.world_validated_road_sections%rowtype;
 prefix float8;finish float8;a float8;b float8;part record;begin '||body||' end;$validate$';
end;$$;
revoke all on function public.account_deletion_replay_validate(uuid,jsonb,jsonb) from public,anon,authenticated,service_role;

create function public.account_deletion_replay_load(p_id uuid,p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;r public.account_deletion_replays%rowtype;
begin
 c:=public.account_deletion_planet_context(p_id,p_lease);
 if c->>'state'<>'rebuild' then return jsonb_build_object('context',c);end if;
 select * into r from public.account_deletion_replays where job_id=p_id for update;
 if not found then
  insert into public.account_deletion_replays(job_id,snapshot) values(p_id,c) returning * into r;
 elsif r.snapshot->>'fingerprint' is distinct from c->>'fingerprint' then
  update public.account_deletion_replays set snapshot=c,traces='[]',next_index=0,version=version+1,updated_at=clock_timestamp() where job_id=p_id returning * into r;
  insert into public.account_deletion_events(job_id,state) values(p_id,'replay_invalidated');
 end if;
 update public.account_deletion_jobs set phase='planet',processed_units=r.next_index,total_units=jsonb_array_length(c->'sources') where id=p_id;
 return jsonb_build_object('context',r.snapshot,'next',r.next_index,'version',r.version::text,'traces',r.traces);
end;$$;
revoke all on function public.account_deletion_replay_load(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_replay_load(uuid,uuid) to service_role;

create function public.account_deletion_replay_save(p_id uuid,p_lease uuid,p_fingerprint text,p_version bigint,p_next integer,p_traces jsonb) returns text
language plpgsql security definer set search_path='' as $$
declare c jsonb;r public.account_deletion_replays%rowtype;
begin
 c:=public.account_deletion_planet_context(p_id,p_lease);
 if c->>'state'<>'rebuild' or c->>'fingerprint' is distinct from p_fingerprint then raise exception 'replay_snapshot_changed';end if;
 select * into strict r from public.account_deletion_replays where job_id=p_id for update;
 if r.snapshot->>'fingerprint' is distinct from p_fingerprint then raise exception 'replay_snapshot_changed';end if;
 if r.version=p_version+1 and r.next_index=p_next and r.traces=p_traces then return 'already_saved';end if;
 if r.version<>p_version or p_next<=r.next_index or p_next>r.next_index+2 or p_next>jsonb_array_length(c->'sources')
 or p_traces is null or jsonb_typeof(p_traces)<>'array' or jsonb_array_length(p_traces)>256 or octet_length(p_traces::text)>1048576
 then raise exception 'replay_checkpoint_conflict';end if;
 perform public.account_deletion_replay_validate(p_id,c,p_traces);
 if exists(select 1 from jsonb_array_elements(p_traces) t where not exists(select 1 from jsonb_array_elements(c->'sources') with ordinality e(source,ord)
 where ord<=p_next and source->'source'->>'id'=t->>'sourcePublishId')) then raise exception 'replay_future_source';end if;
 update public.account_deletion_replays set next_index=p_next,traces=p_traces,version=version+1,updated_at=clock_timestamp() where job_id=p_id;
 update public.account_deletion_jobs set processed_units=p_next,total_units=jsonb_array_length(c->'sources'),phase='planet',review_required=false,failures=0,next_attempt_at=clock_timestamp()+interval '1 second' where id=p_id;
 insert into public.account_deletion_events(job_id,state) values(p_id,'replay_checkpoint');return 'saved';
end;$$;
revoke all on function public.account_deletion_replay_save(uuid,uuid,text,bigint,integer,jsonb) from public,anon,authenticated;
grant execute on function public.account_deletion_replay_save(uuid,uuid,text,bigint,integer,jsonb) to service_role;

create function public.account_deletion_replay_finish(p_id uuid,p_lease uuid) returns text
language plpgsql security definer set search_path='' as $$
declare c jsonb;r public.account_deletion_replays%rowtype;
begin
 c:=public.account_deletion_planet_context(p_id,p_lease);
 if c->>'state' in('ready','not_required') then return c->>'state';end if;
 select * into strict r from public.account_deletion_replays where job_id=p_id for update;
 if r.snapshot->>'fingerprint' is distinct from c->>'fingerprint' or r.next_index<>jsonb_array_length(c->'sources') then raise exception 'replay_incomplete';end if;
 return public.account_deletion_planet_commit(p_id,p_lease,c->>'fingerprint',r.traces);
end;$$;
revoke all on function public.account_deletion_replay_finish(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_replay_finish(uuid,uuid) to service_role;

create function public.account_deletion_replay_cleanup() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state='completed' then delete from public.account_deletion_replays where job_id=new.id;end if;return new;
end;$$;
revoke all on function public.account_deletion_replay_cleanup() from public,anon,authenticated,service_role;
create trigger account_deletion_replay_cleanup after update of state on public.account_deletion_jobs for each row execute function public.account_deletion_replay_cleanup();

create function public.account_deletion_phase_complete() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.state='completed' then new.phase:='completed';new.review_required:=false;
 elsif new.state='purged' then new.phase:='auth';end if;return new;
end;$$;
revoke all on function public.account_deletion_phase_complete() from public,anon,authenticated,service_role;
create trigger account_deletion_phase_complete before update of state on public.account_deletion_jobs for each row execute function public.account_deletion_phase_complete();
commit;
