-- Add a server-only read projection without changing canonical storage or the
-- existing RPC contract. Text is computed while extra_float_digits=3 is active,
-- so PostgREST's later JSON number formatting cannot lose a float8 bit.
begin;

create or replace function public.get_world_validated_road_sections_for_processing_exact(
  p_validated_road_id uuid
) returns table (
  id uuid,
  validated_road_id uuid,
  section_key text,
  section_order integer,
  distance_meters text,
  confidence double precision,
  source_trace_index integer,
  source_chunk_index integer,
  geometry jsonb
)
language sql
stable
set search_path = pg_catalog, extensions, public, pg_temp
set extra_float_digits = 3
as $$
  select
    s.id,
    s.validated_road_id,
    s.section_key,
    s.section_order,
    s.distance_meters::text,
    s.confidence,
    s.source_trace_index,
    s.source_chunk_index,
    extensions.ST_AsGeoJSON(s.geometry, 15, 0)::jsonb
  from public.world_validated_road_sections as s
  where s.validated_road_id = p_validated_road_id
    and extensions.ST_SRID(s.geometry) = 4326
  order by s.section_order;
$$;

revoke all on function public.get_world_validated_road_sections_for_processing_exact(uuid)
  from public, anon, authenticated;
grant execute on function public.get_world_validated_road_sections_for_processing_exact(uuid)
  to service_role;

notify pgrst, 'reload schema';
commit;
