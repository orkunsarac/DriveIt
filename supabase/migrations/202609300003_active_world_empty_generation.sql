begin;

create table if not exists public.world_active_world_generations (
  generation bigint primary key check (generation >= 0),
  base_generation bigint,
  operation_id text not null unique,
  operation_reason text not null check (operation_reason in ('initial', 'recordProcessing')),
  source_publish_id uuid unique references public.world_publishes(id) on delete restrict,
  source_drive_session_id text,
  drive_score_algorithm_version integer not null,
  validated_road_processing_version integer not null,
  valid_distance_meters double precision,
  trace_count integer not null default 0 check (trace_count >= 0),
  created_at timestamptz not null
);

create table if not exists public.world_active_world_state (
  singleton boolean primary key default true check (singleton),
  current_generation bigint not null references public.world_active_world_generations(generation),
  updated_at timestamptz not null default now()
);

create table if not exists public.world_active_world_traces (
  trace_id text not null,
  active_from_generation bigint not null references public.world_active_world_generations(generation),
  active_to_generation bigint references public.world_active_world_generations(generation),
  source_publish_id uuid not null references public.world_publishes(id) on delete restrict,
  source_drive_session_id text not null,
  validated_road_id uuid not null references public.world_validated_roads(id) on delete restrict,
  matched_section_id text not null,
  start_offset_meters double precision not null check (start_offset_meters >= 0),
  end_offset_meters double precision not null,
  direction_key text not null,
  min_latitude double precision not null,
  max_latitude double precision not null,
  min_longitude double precision not null,
  max_longitude double precision not null,
  bounds extensions.geometry(Geometry, 4326) not null,
  processing_version integer not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (trace_id, active_from_generation),
  check (end_offset_meters > start_offset_meters),
  check (max_latitude >= min_latitude and max_longitude >= min_longitude),
  check (active_to_generation is null or active_to_generation > active_from_generation)
);

create index if not exists world_active_world_traces_bounds_gix
  on public.world_active_world_traces using gist (bounds)
  where active_to_generation is null;
create index if not exists world_active_world_traces_generation_idx
  on public.world_active_world_traces (active_from_generation, active_to_generation);
create index if not exists world_active_world_traces_source_idx
  on public.world_active_world_traces (source_publish_id, active_from_generation);
create unique index if not exists world_active_world_traces_current_id_unique
  on public.world_active_world_traces (trace_id)
  where active_to_generation is null;

alter table public.world_active_world_generations enable row level security;
alter table public.world_active_world_state enable row level security;
alter table public.world_active_world_traces enable row level security;

-- Use the same spherical distance formula and radius as GeoDistance / the
-- WorldSectionOffsetMapper geometry fallback in Flutter.
create or replace function public.world_section_geometry_length_meters(p_line extensions.geometry)
returns double precision
language plpgsql immutable strict
set search_path = pg_catalog, extensions, pg_temp
as $$
declare
  v_total double precision := 0;
  v_index integer;
  v_lat1 double precision;
  v_lat2 double precision;
  v_lon1 double precision;
  v_lon2 double precision;
  v_h double precision;
begin
  if extensions.ST_NPoints(p_line) < 2 then return 0; end if;
  for v_index in 2..extensions.ST_NPoints(p_line) loop
    v_lat1 := radians(extensions.ST_Y(extensions.ST_PointN(p_line, v_index - 1)));
    v_lat2 := radians(extensions.ST_Y(extensions.ST_PointN(p_line, v_index)));
    v_lon1 := radians(extensions.ST_X(extensions.ST_PointN(p_line, v_index - 1)));
    v_lon2 := radians(extensions.ST_X(extensions.ST_PointN(p_line, v_index)));
    v_h := power(sin((v_lat2 - v_lat1) / 2), 2) +
      cos(v_lat1) * cos(v_lat2) * power(sin((v_lon2 - v_lon1) / 2), 2);
    v_total := v_total + 2 * 6371008.8 * asin(sqrt(least(1, greatest(0, v_h))));
  end loop;
  return v_total;
end;
$$;

-- Generation zero is the deterministic empty-world equivalent of
-- WorldIndexSnapshot.empty(). Both inserts are idempotent on migration replay.
insert into public.world_active_world_generations (
  generation, base_generation, operation_id, operation_reason,
  source_publish_id, source_drive_session_id,
  drive_score_algorithm_version, validated_road_processing_version,
  valid_distance_meters, trace_count, created_at
) values (0, null, 'initial', 'initial', null, null, 1, 6, null, 0, 'epoch')
on conflict (generation) do nothing;

insert into public.world_active_world_state (singleton, current_generation)
values (true, 0)
on conflict (singleton) do nothing;

create or replace function public.activate_empty_world_publish(
  p_publish_id uuid,
  p_expected_generation bigint,
  p_drive_score_algorithm_version integer,
  p_world_rules_version integer,
  p_expected_plan jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, extensions, pg_temp
as $$
declare
  v_current bigint;
  v_publish public.world_publishes%rowtype;
  v_road public.world_validated_roads%rowtype;
  v_section record;
  v_section_count integer;
  v_start double precision := 0;
  v_length double precision;
  v_end double precision;
  v_trace_count integer := 0;
  v_generation bigint;
  v_existing public.world_active_world_generations%rowtype;
  v_trace_id text;
  v_expected_trace jsonb;
  v_bounds box3d;
  v_plan_start double precision;
  v_plan_end double precision;
  v_geometry_fallback_seen boolean := false;
  v_is_geometry_fallback boolean;
  v_offset_tolerance constant double precision := 0.000001;
  v_now timestamptz := now();
begin
  select * into v_publish from public.world_publishes
    where id = p_publish_id for update;
  if not found then
    return jsonb_build_object('state', 'publish_not_found');
  end if;

  select * into v_existing from public.world_active_world_generations
    where source_publish_id = p_publish_id;
  if found then
    return jsonb_build_object(
      'state', 'already_processed', 'generation', v_existing.generation,
      'operation_id', v_existing.operation_id, 'trace_count', v_existing.trace_count
    );
  end if;

  select current_generation into v_current from public.world_active_world_state
    where singleton = true for update;
  if not found then raise exception 'active World state row missing'; end if;

  -- Recheck after acquiring the singleton lock to serialize simultaneous first commits.
  select * into v_existing from public.world_active_world_generations
    where source_publish_id = p_publish_id;
  if found then
    return jsonb_build_object(
      'state', 'already_processed', 'generation', v_existing.generation,
      'operation_id', v_existing.operation_id, 'trace_count', v_existing.trace_count
    );
  end if;
  if v_current <> p_expected_generation then
    return jsonb_build_object('state', 'stale_generation', 'current_generation', v_current);
  end if;
  if v_current <> 0 or exists (
    select 1 from public.world_active_world_traces where active_to_generation is null
  ) or exists (
    select 1 from public.world_active_world_generations where source_publish_id is not null
  ) then
    return jsonb_build_object('state', 'world_comparison_not_implemented');
  end if;
  if p_expected_generation <> 0 then
    return jsonb_build_object('state', 'stale_generation', 'current_generation', v_current);
  end if;
  if v_publish.status <> 'processing' or v_publish.source_ready_at is null
      or v_publish.source_path is null then
    return jsonb_build_object('state', 'publish_not_ready');
  end if;
  if p_drive_score_algorithm_version <> 1 or p_world_rules_version <> 6 then
    return jsonb_build_object('state', 'unsupported_world_version');
  end if;

  select * into v_road from public.world_validated_roads
    where publish_id = p_publish_id and user_id = v_publish.user_id;
  if not found or v_road.validation_status not in ('validated', 'partiallyValidated') then
    return jsonb_build_object('state', 'validated_road_not_found');
  end if;
  if not (v_road.valid_distance_meters >= 5000 and
      v_road.valid_distance_meters < 'Infinity'::double precision) then
    return jsonb_build_object('state', 'ineligible_validated_road');
  end if;
  select count(*) into v_section_count from public.world_validated_road_sections
    where validated_road_id = v_road.id;
  if v_section_count <> v_road.section_count or v_section_count < 1 then
    return jsonb_build_object('state', 'validated_sections_incomplete');
  end if;

  if jsonb_typeof(p_expected_plan) <> 'object' or
      (p_expected_plan->>'baseGeneration')::bigint <> v_current or
      (p_expected_plan->>'generation')::bigint <> v_current + 1 or
      p_expected_plan->>'operationId' <> (
        'world:' || v_publish.local_drive_id || ':v' || p_drive_score_algorithm_version::text
      ) or
      p_expected_plan->>'operationReason' <> 'recordProcessing' or
      p_expected_plan->>'sourceDriveSessionId' <> v_publish.local_drive_id or
      (p_expected_plan->>'driveScoreAlgorithmVersion')::integer <>
        p_drive_score_algorithm_version or
      (p_expected_plan->>'validatedRoadProcessingVersion')::integer <>
        p_world_rules_version or
      not (p_expected_plan->'processedDriveSessionIds' ? v_publish.local_drive_id) or
      jsonb_typeof(p_expected_plan->'traces') <> 'array' then
    raise exception 'empty-world plan metadata mismatch';
  end if;

  v_generation := v_current + 1;
  insert into public.world_active_world_generations (
    generation, base_generation, operation_id, operation_reason,
    source_publish_id, source_drive_session_id,
    drive_score_algorithm_version, validated_road_processing_version,
    valid_distance_meters, trace_count, created_at
  ) values (
    v_generation, v_current,
    'world:' || v_publish.local_drive_id || ':v' || p_drive_score_algorithm_version,
    'recordProcessing', p_publish_id, v_publish.local_drive_id,
    p_drive_score_algorithm_version, p_world_rules_version,
    v_road.valid_distance_meters, 0, v_now
  );

  for v_section in
    select section_key, distance_meters, geometry
    from public.world_validated_road_sections
    where validated_road_id = v_road.id
    order by section_order
  loop
    if v_section.distance_meters > 0 and
        v_section.distance_meters < 'Infinity'::double precision then
      v_length := v_section.distance_meters;
      v_is_geometry_fallback := false;
    else
      v_length := public.world_section_geometry_length_meters(v_section.geometry);
      v_is_geometry_fallback := true;
    end if;
    v_end := v_start + v_length;
    if v_length >= 1000 then
      select candidate.value into v_expected_trace
      from jsonb_array_elements(p_expected_plan->'traces') candidate(value)
      where candidate.value->>'matchedSectionId' = v_section.section_key;
      if v_expected_trace is null then
        raise exception 'empty-world trace is missing from plan';
      end if;
      v_plan_start := (v_expected_trace->>'startOffsetMeters')::double precision;
      v_plan_end := (v_expected_trace->>'endOffsetMeters')::double precision;
      -- Only geometry-measured fallback distances allow floating point
      -- tolerance; declared provider distance remains exact/canonical.
      if v_geometry_fallback_seen or v_is_geometry_fallback then
        if abs(v_plan_start - v_start) > v_offset_tolerance or
            abs(v_plan_end - v_end) > v_offset_tolerance then
          raise exception 'empty-world trace offset mismatch';
        end if;
      elsif v_plan_start <> v_start or v_plan_end <> v_end then
        raise exception 'empty-world trace offset mismatch';
      end if;
      v_trace_id := v_publish.local_drive_id || ':' || v_road.id::text || ':' ||
        v_section.section_key || ':' ||
        to_char(v_plan_start::numeric, 'FM99999999999999999990.000') || ':' ||
        to_char(v_plan_end::numeric, 'FM99999999999999999990.000');
      v_bounds := extensions.Box3D(v_section.geometry);
      if v_expected_trace->>'id' <> v_trace_id or
          v_expected_trace->>'sourceDriveSessionId' <> v_publish.local_drive_id or
          v_expected_trace->>'validatedRoadId' <> v_road.id::text or
          v_expected_trace->>'matchedSectionId' <> v_section.section_key or
          v_expected_trace->>'directionKey' <> v_road.direction_key or
          (v_expected_trace->>'processingVersion')::integer <> v_road.processing_version or
          (v_expected_trace->>'minLatitude')::double precision <> extensions.ST_YMin(v_bounds) or
          (v_expected_trace->>'maxLatitude')::double precision <> extensions.ST_YMax(v_bounds) or
          (v_expected_trace->>'minLongitude')::double precision <> extensions.ST_XMin(v_bounds) or
          (v_expected_trace->>'maxLongitude')::double precision <> extensions.ST_XMax(v_bounds) then
        raise exception 'empty-world trace plan mismatch';
      end if;
      insert into public.world_active_world_traces (
        trace_id, active_from_generation, active_to_generation,
        source_publish_id, source_drive_session_id, validated_road_id,
        matched_section_id, start_offset_meters, end_offset_meters,
        direction_key, min_latitude, max_latitude, min_longitude, max_longitude,
        bounds, processing_version, created_at, updated_at
      ) values (
        v_trace_id, v_generation, null, p_publish_id,
        v_publish.local_drive_id, v_road.id, v_section.section_key,
        v_plan_start, v_plan_end, v_road.direction_key,
        extensions.ST_YMin(v_bounds),
        extensions.ST_YMax(v_bounds),
        extensions.ST_XMin(v_bounds),
        extensions.ST_XMax(v_bounds),
        extensions.ST_Envelope(v_section.geometry), v_road.processing_version,
        v_now, v_now
      );
      v_trace_count := v_trace_count + 1;
      v_end := v_plan_end;
    end if;
    v_start := v_end;
    v_geometry_fallback_seen := v_geometry_fallback_seen or v_is_geometry_fallback;
  end loop;
  if v_trace_count <> jsonb_array_length(p_expected_plan->'traces') then
    raise exception 'empty-world trace count mismatch';
  end if;

  update public.world_active_world_generations
    set trace_count = v_trace_count where generation = v_generation;
  update public.world_active_world_state
    set current_generation = v_generation, updated_at = v_now
    where singleton = true and current_generation = v_current;
  if not found then raise exception 'active World generation pointer changed'; end if;
  update public.world_publishes
    set status = 'published', processed_at = v_now, error_code = null, updated_at = v_now
    where id = p_publish_id and status = 'processing';
  if not found then raise exception 'publish status changed before activation'; end if;

  return jsonb_build_object(
    'state', 'committed', 'generation', v_generation,
    'operation_id', 'world:' || v_publish.local_drive_id || ':v' || p_drive_score_algorithm_version,
    'trace_count', v_trace_count,
    'validated_road_id', v_road.id,
    'valid_distance_meters', v_road.valid_distance_meters,
    'eligible_for_world', true
  );
end;
$$;

revoke all on public.world_active_world_generations from public, anon, authenticated, service_role;
revoke all on public.world_active_world_state from public, anon, authenticated, service_role;
revoke all on public.world_active_world_traces from public, anon, authenticated, service_role;
revoke all on function public.activate_empty_world_publish(uuid, bigint, integer, integer, jsonb)
  from public, anon, authenticated;
revoke all on function public.world_section_geometry_length_meters(extensions.geometry)
  from public, anon, authenticated;
grant select on public.world_active_world_generations,
  public.world_active_world_state, public.world_active_world_traces to service_role;
grant execute on function public.activate_empty_world_publish(uuid, bigint, integer, integer, jsonb)
  to service_role;

commit;
