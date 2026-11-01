-- Forward-only candidate. Local acceptance only; requires separate PROD approval.
begin;
create table public.account_deletion_jobs (
 id uuid primary key, owner_id uuid unique, receipt_hash text not null check(receipt_hash ~ '^[0-9a-f]{64}$'),
 state text not null default 'pending' check(state in ('pending','blocked_planet','purged','completed')),
 lease uuid, lease_until timestamptz, created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(), completed_at timestamptz,
 check((state='completed')=(owner_id is null and completed_at is not null))
);
alter table public.account_deletion_jobs enable row level security;
revoke all on public.account_deletion_jobs from public,anon,authenticated,service_role;

create function public.account_deletion_active(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.account_deletion_jobs where owner_id=p_owner and state<>'completed');
$$;
revoke all on function public.account_deletion_active(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_active(uuid) to authenticated,service_role;

create function public.account_deletion_assert_active(p_owner uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_owner is null then raise exception 'identity_required' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock_shared(pg_catalog.hashtextextended('account_delete:'||p_owner::text,0));
 if public.account_deletion_active(p_owner) then raise exception 'account_deletion_pending' using errcode='42501'; end if;
end;$$;
revoke all on function public.account_deletion_assert_active(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_assert_active(uuid) to service_role;

create function public.account_deletion_planet_guard() returns void
language plpgsql security definer set search_path='' as $$
begin
 -- Shared-road recomputation is not assumed safe. No personal Planet output is served while unresolved.
 if exists(select 1 from public.account_deletion_jobs j join public.world_publishes p on p.user_id=j.owner_id where j.state<>'completed')
 then raise exception 'planet_deletion_pending' using errcode='42501'; end if;
 if auth.uid() is not null then perform public.account_deletion_assert_active(auth.uid()); end if;
end;$$;
revoke all on function public.account_deletion_planet_guard() from public,anon,authenticated;
grant execute on function public.account_deletion_planet_guard() to service_role;

-- Preserve function signatures/ACLs and inject account fencing before all existing owner RPC bodies.
do $$declare r record; d text; guard text;
begin
 for r in select p.oid,p.proname,p.proargnames from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and l.lanname='plpgsql' and
 ((p.proname like 'phase8_%' and ('p_owner_id'=any(p.proargnames) or p.proname in ('phase8_group_command','phase8_group_accept_location')))
 or p.proname in ('claim_world_publish_validation','finish_world_publish_validation','fail_world_publish_validation','commit_active_world_mutation','activate_empty_world_publish','read_planet_viewport','attach_world_publish_source')) loop
  guard:=case when 'p_owner_id'=any(r.proargnames) then 'perform public.account_deletion_assert_active(p_owner_id);'
   when r.proname='phase8_group_accept_location' then 'perform public.account_deletion_assert_active(p_actor);'
   when r.proname='phase8_group_command' then 'perform public.account_deletion_assert_active(auth.uid());'
   when r.proname='read_planet_viewport' then 'perform public.account_deletion_planet_guard();'
   else 'perform public.account_deletion_assert_active((select user_id from public.world_publishes where id=p_publish_id));' end;
  d:=pg_get_functiondef(r.oid);
  if d !~* '\mbegin\M' then raise exception 'unsupported_fence_body'; end if;
  execute regexp_replace(d,'\mbegin\M','begin '||guard,'i');
 end loop;
end;$$;

-- SQL helper/topic bodies cannot be injected as PL/pgSQL. Keep their original ACL private.
alter function public.phase8_group_topic_authorized() rename to account_deletion_previous_topic_authorized;
revoke all on function public.account_deletion_previous_topic_authorized() from public,anon,authenticated,service_role;
create function public.phase8_group_topic_authorized() returns boolean language sql stable security definer set search_path='' as $$
 select not public.account_deletion_active(auth.uid()) and public.account_deletion_previous_topic_authorized();
$$;
revoke all on function public.phase8_group_topic_authorized() from public,anon;
grant execute on function public.phase8_group_topic_authorized() to authenticated,service_role;
-- Policies retain function OIDs through rename: explicitly rebind them to the fenced wrapper.
alter policy phase8_group_current_member_read on realtime.messages using(extension='broadcast' and public.phase8_group_topic_authorized());
alter policy phase8_group_current_member_fence on realtime.messages using(realtime.topic() not like 'driveit:group:%' or public.phase8_group_topic_authorized());
alter function public.read_planet_trace_detail_context(text) rename to account_deletion_previous_trace_context;
revoke all on function public.account_deletion_previous_trace_context(text) from public,anon,authenticated,service_role;
create function public.read_planet_trace_detail_context(p_trace_id text) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform public.account_deletion_planet_guard(); return public.account_deletion_previous_trace_context(p_trace_id); end;$$;
revoke all on function public.read_planet_trace_detail_context(text) from public,anon,authenticated;
grant execute on function public.read_planet_trace_detail_context(text) to service_role;

create policy account_deletion_profile_fence on public.profiles as restrictive for all to authenticated
 using(not public.account_deletion_active(id) and not public.account_deletion_active(auth.uid()))
 with check(not public.account_deletion_active(id) and not public.account_deletion_active(auth.uid()));
create policy account_deletion_publish_fence on public.world_publishes as restrictive for all to authenticated
 using(not public.account_deletion_active(user_id) and not public.account_deletion_active(auth.uid()))
 with check(not public.account_deletion_active(user_id) and not public.account_deletion_active(auth.uid()));
create policy account_deletion_road_fence on public.world_validated_roads as restrictive for select to authenticated
 using(not public.account_deletion_active(user_id) and not public.account_deletion_active(auth.uid()));
create policy account_deletion_section_fence on public.world_validated_road_sections as restrictive for select to authenticated
 using(not public.account_deletion_active(auth.uid()) and not exists(select 1 from public.world_validated_roads r where r.id=validated_road_id and public.account_deletion_active(r.user_id)));
create policy account_deletion_storage_fence on storage.objects as restrictive for all to authenticated
 using(not public.account_deletion_active(auth.uid())) with check(not public.account_deletion_active(auth.uid()));

-- Protect service-only writes as well as client RLS; requests already in flight cannot recreate owner rows.
create function public.account_deletion_write_fence() returns trigger language plpgsql security definer set search_path='' as $$
declare v uuid;
begin
 if tg_table_schema='storage' then
  if split_part(new.name,'/',1) ~ '^[0-9a-f-]{36}$' then v:=split_part(new.name,'/',1)::uuid; end if;
 else v:=(to_jsonb(new)->>tg_argv[0])::uuid; end if;
 if v is not null then perform public.account_deletion_assert_active(v); end if;
 return new;
end;$$;
revoke all on function public.account_deletion_write_fence() from public,anon,authenticated,service_role;
do $$declare r record;begin
 for r in select table_name,column_name from information_schema.columns where table_schema='public' and column_name in ('owner_id','user_id') and table_name<>'account_deletion_jobs' loop
  execute format('create trigger account_delete_write_fence before insert or update on public.%I for each row execute function public.account_deletion_write_fence(%L)',r.table_name,r.column_name);
 end loop;
end;$$;
create trigger account_delete_storage_fence before insert or update on storage.objects for each row execute function public.account_deletion_write_fence();

create function public.account_deletion_request(p_owner uuid,p_id uuid,p_hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_deletion_jobs%rowtype;
begin
 if p_owner is null or p_id is null or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'request_invalid'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_delete:'||p_owner::text,0));
 select * into j from public.account_deletion_jobs where owner_id=p_owner or id=p_id for update;
 if found then
  if j.owner_id is distinct from p_owner or j.id<>p_id or j.receipt_hash<>p_hash then raise exception 'deletion_request_conflict'; end if;
  return jsonb_build_object('state',j.state);
 end if;
 if not exists(select 1 from auth.users where id=p_owner) then raise exception 'account_unavailable'; end if;
 insert into public.account_deletion_jobs(id,owner_id,receipt_hash) values(p_id,p_owner,p_hash);
 -- End administered groups; revoke only the deleting member in other groups.
 update public.phase8_groups set status='ended',generation=generation+1,revision=revision+1 where administrator_id=p_owner and status<>'ended';
 update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null
 where account_id=p_owner or group_id in(select id from public.phase8_groups where administrator_id=p_owner);
 return jsonb_build_object('state','pending');
end;$$;
revoke all on function public.account_deletion_request(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.account_deletion_request(uuid,uuid,text) to service_role;

create function public.account_deletion_claim(p_id uuid,p_hash text,p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_deletion_jobs%rowtype;
begin
 select * into j from public.account_deletion_jobs where id=p_id and receipt_hash=p_hash for update;
 if not found then raise exception 'receipt_invalid' using errcode='42501'; end if;
 if j.state='completed' then return jsonb_build_object('state','completed'); end if;
 if j.lease_until>clock_timestamp() then return jsonb_build_object('state','busy'); end if;
 update public.account_deletion_jobs set lease=p_lease,lease_until=clock_timestamp()+interval '120 seconds',updated_at=clock_timestamp() where id=p_id;
 return jsonb_build_object('state',j.state,'owner',j.owner_id);
end;$$;
revoke all on function public.account_deletion_claim(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_claim(uuid,text,uuid) to service_role;

create function public.account_deletion_objects(p_id uuid,p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v uuid;begin
 select owner_id into v from public.account_deletion_jobs where id=p_id and lease=p_lease and lease_until>clock_timestamp();
 if v is null then raise exception 'lease_invalid'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('bucket',bucket_id,'name',name)) from
 (select bucket_id,name from storage.objects where owner_id=v::text or owner=v or split_part(name,'/',1)=v::text order by bucket_id,name limit 100)s),'[]'::jsonb);
end;$$;
revoke all on function public.account_deletion_objects(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_objects(uuid,uuid) to service_role;

create function public.account_deletion_release(p_id uuid,p_lease uuid) returns void language sql security definer set search_path='' as $$
 update public.account_deletion_jobs set lease=null,lease_until=null,updated_at=clock_timestamp() where id=p_id and lease=p_lease;
$$;
revoke all on function public.account_deletion_release(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_release(uuid,uuid) to service_role;

-- Physical deletion bypass is transaction-scoped, definer-only and bound to one durable job owner.
create or replace function public.phase8_reject_immutable_mutation() returns trigger language plpgsql set search_path='' as $$
begin
 if current_user='postgres' and tg_op='DELETE' and current_setting('driveit.purge_owner',true)=to_jsonb(old)->>'owner_id'
 and exists(select 1 from public.account_deletion_jobs where owner_id=(to_jsonb(old)->>'owner_id')::uuid and state<>'completed') then return old; end if;
 raise exception using errcode='55000',message='phase8_row_immutable';
end;$$;

create function public.account_deletion_purge(p_id uuid,p_lease uuid) returns text
language plpgsql security definer set search_path='' as $$
declare v uuid;r record;
begin
 select owner_id into v from public.account_deletion_jobs where id=p_id and lease=p_lease and lease_until>clock_timestamp() for update;
 if v is null then raise exception 'lease_invalid'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_delete:'||v::text,0));
 -- Serialize against the existing Planet mutation writer.
 perform 1 from public.world_active_world_state where singleton for update;
 if exists(select 1 from public.world_publishes p join public.world_validated_roads own on own.publish_id=p.id
 join public.world_validated_roads other on other.user_id<>v and extensions.ST_Intersects(own.geometry,other.geometry) where p.user_id=v)
 then update public.account_deletion_jobs set state='blocked_planet',lease=null,lease_until=null where id=p_id;return 'blocked_planet';end if;
 if exists(select 1 from storage.objects where owner_id=v::text or owner=v or split_part(name,'/',1)=v::text) then return 'pending';end if;
 perform set_config('driveit.purge_owner',v::text,true);
 delete from public.phase8_drive_cancellations where owner_id=v;
 delete from public.phase8_drive_tombstones where owner_id=v;
 delete from public.phase8_drive_leases where owner_id=v;
 delete from public.phase8_drive_snapshots where owner_id=v;
 delete from public.phase8_drive_changes where owner_id=v;
 delete from public.phase8_drive_manifests where owner_id=v;
 delete from public.phase8_drive_upload_intents where owner_id=v;
 delete from public.phase8_drive_owner_sequences where owner_id=v;
 delete from public.world_active_world_traces where source_publish_id in(select id from public.world_publishes where user_id=v);
 -- Retain only non-personal generation ordering needed by other users; erase all source identity/distance metadata.
 update public.world_active_world_generations set source_publish_id=null,source_drive_session_id=null,valid_distance_meters=null,trace_count=0,operation_id='erased-generation:'||generation::text where source_publish_id in(select id from public.world_publishes where user_id=v);
 delete from public.world_publishes where user_id=v;
 delete from public.phase8_group_memberships where account_id=v or group_id in(select id from public.phase8_groups where administrator_id=v);
 delete from public.phase8_groups where administrator_id=v;
 delete from public.profiles where id=v;
 update public.account_deletion_jobs set state='purged',updated_at=clock_timestamp() where id=p_id;
 return 'purged';
end;$$;
revoke all on function public.account_deletion_purge(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_purge(uuid,uuid) to service_role;

create function public.account_deletion_complete(p_id uuid,p_lease uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v uuid;begin
 select owner_id into v from public.account_deletion_jobs where id=p_id and lease=p_lease and state='purged' for update;
 if v is null or exists(select 1 from auth.users where id=v) then raise exception 'auth_deletion_unconfirmed';end if;
 if exists(select 1 from storage.objects where owner_id=v::text or owner=v or split_part(name,'/',1)=v::text) then raise exception 'storage_deletion_unconfirmed';end if;
 update public.account_deletion_jobs set state='completed',owner_id=null,completed_at=clock_timestamp(),updated_at=clock_timestamp(),lease=null,lease_until=null where id=p_id;
end;$$;
revoke all on function public.account_deletion_complete(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_complete(uuid,uuid) to service_role;
commit;
