-- Server-only, read-only projection of canonical PostGIS sections to GeoJSON.
begin;

create or replace function public.get_world_validated_road_sections_for_processing(
  p_validated_road_id uuid
) returns table (
  id uuid,
  validated_road_id uuid,
  section_key text,
  section_order integer,
  distance_meters double precision,
  confidence double precision,
  source_trace_index integer,
  source_chunk_index integer,
  geometry jsonb
)
language sql
stable
set search_path = pg_catalog, extensions, public, pg_temp
as $$
  select
    s.id,
    s.validated_road_id,
    s.section_key,
    s.section_order,
    s.distance_meters,
    s.confidence,
    s.source_trace_index,
    s.source_chunk_index,
    extensions.ST_AsGeoJSON(s.geometry, 15, 0)::jsonb as geometry
  from public.world_validated_road_sections as s
  where s.validated_road_id = p_validated_road_id
    and extensions.ST_SRID(s.geometry) = 4326
  order by s.section_order;
$$;

revoke all on function public.get_world_validated_road_sections_for_processing(uuid)
  from public, anon, authenticated;
grant execute on function public.get_world_validated_road_sections_for_processing(uuid)
  to service_role;

notify pgrst, 'reload schema';

commit;
