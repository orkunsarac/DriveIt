begin;
-- Never expose a partial replay. Keep committed output only outside the
-- conservative transitive spatial component touched by any pending deletion.
create function public.account_deletion_planet_hidden_roads() returns uuid[]
language plpgsql stable security definer set search_path='' as $$
declare result uuid[];
begin
 if exists(select 1 from public.world_validated_roads r join public.world_publishes p on p.id=r.publish_id where r.user_id<>p.user_id)
 or exists(select 1 from public.world_validated_roads r join public.account_deletion_jobs j on j.owner_id=r.user_id and j.state<>'completed'
 where extensions.ST_YMax(r.geometry::extensions.box3d)>85 or extensions.ST_YMin(r.geometry::extensions.box3d)<-85)
 then return array(select id from public.world_validated_roads);end if;
 with recursive affected(id) as (
  select r.id from public.world_validated_roads r join public.world_publishes p on p.id=r.publish_id
  where exists(select 1 from public.account_deletion_jobs j where j.state<>'completed' and (j.owner_id=r.user_id or j.owner_id=p.user_id))
  union
  select r.id from public.world_validated_roads r join public.world_validated_roads previous
  on r.geometry operator(extensions.&&) extensions.ST_Expand(previous.geometry,.01)
  join affected a on a.id=previous.id
 ) select coalesce(array_agg(id),'{}'::uuid[]) into result from affected;
 return result;
end;$$;
revoke all on function public.account_deletion_planet_hidden_roads() from public,anon,authenticated;
grant execute on function public.account_deletion_planet_hidden_roads() to service_role;

do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.read_planet_viewport(double precision,double precision,double precision,double precision,double precision)'::regprocedure);
 anchor:='perform public.account_deletion_planet_guard();';
 if position(anchor in d)=0 or position('declare g bigint;' in d)=0 then raise exception 'unexpected_viewport_guard_contract';end if;
 d:=replace(d,'declare g bigint;','declare hidden uuid[];g bigint;');
 d:=replace(d,anchor,'if auth.uid() is not null then perform public.account_deletion_assert_active(auth.uid());end if; hidden:=public.account_deletion_planet_hidden_roads();');
 d:=replace(d,'where active_to_generation is null and active_from_generation<=g','where active_to_generation is null and active_from_generation<=g and not(validated_road_id=any(hidden))');
 d:=replace(d,'where t.active_to_generation is null and t.active_from_generation<=g','where t.active_to_generation is null and t.active_from_generation<=g and not(t.validated_road_id=any(hidden))');
 execute d;
end;$$;

create or replace function public.read_planet_trace_detail_context(p_trace_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is not null then perform public.account_deletion_assert_active(auth.uid());end if;
 if exists(select 1 from public.world_active_world_traces t where md5(t.trace_id)=p_trace_id
 and t.validated_road_id=any(public.account_deletion_planet_hidden_roads())) then return null;end if;
 return public.account_deletion_previous_trace_context(p_trace_id);
end;$$;
-- Existing EXECUTE ACL is retained: detail is service-only. Write fencing stays
-- global until final CAS commit; a new publish's influence is not yet provable.
commit;
