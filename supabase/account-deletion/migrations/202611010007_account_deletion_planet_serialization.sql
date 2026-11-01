begin;
-- Block derived Planet writes as well as reads while the withdrawal is unresolved.
-- A trigger rechecks after table-lock waits; an earlier Edge snapshot is not authority to resurrect a source.
create function public.account_deletion_planet_write_fence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(current_setting('driveit.purge_owner',true),'')<>'' and exists(select 1 from public.account_deletion_jobs where owner_id::text=current_setting('driveit.purge_owner',true) and state<>'completed') then return new;end if;
 perform public.account_deletion_planet_guard();return new;
end;$$;
revoke all on function public.account_deletion_planet_write_fence() from public,anon,authenticated,service_role;
do $$declare t text;begin
 foreach t in array array['world_publishes','world_validated_roads','world_validated_road_sections','world_active_world_generations','world_active_world_state','world_active_world_traces'] loop
  execute format('create trigger account_deletion_planet_write before insert or update on public.%I for each row execute function public.account_deletion_planet_write_fence()',t);
 end loop;
end;$$;
alter table public.world_active_world_generations drop constraint world_active_world_generations_operation_reason_check;
alter table public.world_active_world_generations add constraint world_active_world_generations_operation_reason_check check(operation_reason in ('initial','recordProcessing','accountDeletion'));
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_request(uuid,uuid,text)'::regprocedure);
 d:=replace(d,'insert into public.account_deletion_jobs(id,owner_id,receipt_hash)',
 'perform 1 from public.world_active_world_state where singleton for update;
 lock table public.world_publishes,public.world_validated_roads,public.world_validated_road_sections,public.world_active_world_generations,public.world_active_world_traces in share row exclusive mode;
 insert into public.account_deletion_jobs(id,owner_id,receipt_hash)');
 execute d;
 d:=pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure);
 d:=replace(d,'declare v uuid;r record;','declare v uuid;r record;v_planet_changed boolean;v_generation bigint;');
 d:=replace(d,'perform 1 from public.world_active_world_state where singleton for update;',
 'perform 1 from public.world_active_world_state where singleton for update;
 lock table public.world_publishes,public.world_validated_roads,public.world_validated_road_sections,public.world_active_world_generations,public.world_active_world_traces in share row exclusive mode;
 v_planet_changed:=exists(select 1 from public.world_publishes where user_id=v);');
 d:=replace(d,'delete from public.world_publishes where user_id=v;',
 'delete from public.world_publishes where user_id=v;
 if v_planet_changed then
  select current_generation into strict v_generation from public.world_active_world_state where singleton;
  insert into public.world_active_world_generations(generation,base_generation,operation_id,operation_reason,drive_score_algorithm_version,validated_road_processing_version,trace_count,created_at)
  values(v_generation+1,v_generation,''account-deletion-generation:''||(v_generation+1)::text,''accountDeletion'',1,3,(select count(*) from public.world_active_world_traces where active_to_generation is null),clock_timestamp());
  update public.world_active_world_state set current_generation=v_generation+1,updated_at=clock_timestamp() where singleton;
 end if;');
 execute d;
end;$$;
commit;
