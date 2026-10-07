begin;
-- Private metadata boundary: only the authenticated Edge handler calls this.
-- No geometry/source duplication, summary writes, or ownership changes.
create or replace function public.read_planet_trace_detail_context(p_trace_id text)
returns jsonb language sql stable security definer
set search_path=pg_catalog,pg_temp as $$
select jsonb_build_object(
  'generation',s.current_generation::text,
  'trace_id',md5(t.trace_id),
  'ownership_distance_meters',t.end_offset_meters-t.start_offset_meters,
  'display_name',p.display_name,'username',p.username,
  'publish',jsonb_build_object(
    'id',w.id,'user_id',w.user_id,'local_drive_id',w.local_drive_id,
    'source_path',w.source_path,'source_ready_at',w.source_ready_at,
    'source_schema_version',w.source_schema_version,'telemetry_version',w.telemetry_version,
    'drive_score_algorithm_version',w.drive_score_algorithm_version,
    'world_rules_version',w.world_rules_version,
    'raw_route_point_count',w.raw_route_point_count,'telemetry_point_count',w.telemetry_point_count))
from public.world_active_world_state s
join public.world_active_world_traces t on t.active_from_generation<=s.current_generation
  and (t.active_to_generation is null or t.active_to_generation>s.current_generation)
join public.world_publishes w on w.id=t.source_publish_id and w.status='published'
left join public.profiles p on p.id=w.user_id
where s.singleton and md5(t.trace_id)=p_trace_id and p_trace_id ~ '^[0-9a-f]{32}$';
$$;
revoke all on function public.read_planet_trace_detail_context(text) from public,anon,authenticated;
grant execute on function public.read_planet_trace_detail_context(text) to service_role;
notify pgrst,'reload schema';
commit;
