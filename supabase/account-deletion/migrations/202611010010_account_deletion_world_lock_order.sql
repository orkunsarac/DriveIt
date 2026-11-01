begin;
-- Acquire the existing world row lock in the write trigger, before checking the
-- deletion fence. No SHARE table lock is needed (and table/owner inversion would deadlock).
create or replace function public.account_deletion_planet_write_fence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(current_setting('driveit.purge_owner',true),'')<>'' and exists(select 1 from public.account_deletion_jobs where owner_id::text=current_setting('driveit.purge_owner',true) and state<>'completed') then return new;end if;
 if auth.uid() is not null then perform public.account_deletion_assert_active(auth.uid());end if;
 perform 1 from public.world_active_world_state where singleton for update;
 perform public.account_deletion_planet_guard();return new;
end;$$;
do $$declare name regprocedure;d text;line text;
begin
 line:='lock table public.world_publishes,public.world_validated_roads,public.world_validated_road_sections,public.world_active_world_generations,public.world_active_world_traces in share row exclusive mode;';
 foreach name in array array['public.account_deletion_request(uuid,uuid,text)'::regprocedure,'public.account_deletion_purge(uuid,uuid)'::regprocedure] loop
  d:=pg_get_functiondef(name);if position(line in d)=0 then raise exception 'unexpected_world_lock_contract';end if;
  execute replace(d,line,'');
 end loop;
end;$$;
commit;
