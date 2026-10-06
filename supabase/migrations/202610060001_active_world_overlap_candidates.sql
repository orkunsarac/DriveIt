begin;
-- One MVCC snapshot for pointer, current temporal versions and source sections.
-- Full section bounds are My World's coarse filter; no exact road decision here.
create or replace function public.get_active_world_overlap_candidates(p_challenger_road_id uuid)
returns jsonb language sql stable security definer
set search_path = pg_catalog, extensions, public, pg_temp
set extra_float_digits = 3
as $$
  with state as materialized (
    select current_generation from public.world_active_world_state where singleton
  ), challenger as materialized (
    select geometry from public.world_validated_roads where id=p_challenger_road_id
  ), candidates as materialized (
    select t.* from public.world_active_world_traces t cross join state s cross join challenger c
    where t.active_from_generation <= s.current_generation
      and t.active_to_generation is null
      and t.bounds && extensions.ST_Envelope(c.geometry)
    order by t.trace_id, t.active_from_generation
  ), source_roads as (
    select r.id, p.local_drive_id, (
      select jsonb_agg(to_jsonb(sec) order by sec.section_order)
      from public.get_world_validated_road_sections_for_processing_exact(r.id) sec
    ) as sections
    from public.world_validated_roads r join public.world_publishes p on p.id=r.publish_id
    where r.id in (select distinct validated_road_id from candidates)
  )
  select jsonb_build_object(
    'generation', (select current_generation::text from state),
    'is_empty', not exists (select 1 from public.world_active_world_traces t cross join state s
      where t.active_from_generation <= s.current_generation
        and t.active_to_generation is null),
    'candidates', coalesce((select jsonb_agg(jsonb_build_object(
      'id', trace_id, 'source_publish_id',source_publish_id,
      'source_drive_id',source_drive_session_id,'validated_road_id',validated_road_id,
      'matched_section_id',matched_section_id,'start_offset_meters',start_offset_meters::text,
      'end_offset_meters',end_offset_meters::text,'direction_key',direction_key,
      'active_from_generation',active_from_generation::text,
      'active_to_generation',active_to_generation::text,'processing_version',processing_version
    ) order by trace_id,active_from_generation) from candidates),'[]'::jsonb),
    'roads',coalesce((select jsonb_agg(jsonb_build_object('id',id,'drive_id',local_drive_id,
      'sections',sections) order by id) from source_roads),'[]'::jsonb)
  );
$$;
revoke all on function public.get_active_world_overlap_candidates(uuid) from public,anon,authenticated;
grant execute on function public.get_active_world_overlap_candidates(uuid) to service_role;
-- Pointer switches/trace retirements commit atomically (Stage 1 contract).
-- Thus only open versions are current. Reuse the existing partial bounds GiST;
-- closed historical versions never enter this query/index, even at same bounds.
notify pgrst, 'reload schema';
commit;
