-- Run only on an empty DEV world. All fixtures, commits and temporary helpers
-- are rolled back. Never invokes the user's real publish or external services.
begin;
set local statement_timeout = '30s';
create temporary table precision_test_results (test text) on commit drop;

create function pg_temp.precision_plan(p_road uuid, p_drive text)
returns jsonb language plpgsql
set extra_float_digits = 3
as $$
declare
  s record;
  v_start double precision := 0;
  v_end double precision;
  v_traces jsonb := '[]'::jsonb;
  v_bounds record;
begin
  for s in select * from public.get_world_validated_road_sections_for_processing_exact(p_road) loop
    v_end := v_start + s.distance_meters::double precision;
    if v_end - v_start >= 1000 then
      select min((p->>0)::double precision) as min_lon,
        max((p->>0)::double precision) as max_lon,
        min((p->>1)::double precision) as min_lat,
        max((p->>1)::double precision) as max_lat into v_bounds
      from jsonb_array_elements(s.geometry->'coordinates') p;
      v_traces := v_traces || jsonb_build_array(jsonb_build_object(
        'id', p_drive || ':' || p_road || ':' || s.section_key || ':' ||
          to_char(v_start::numeric, 'FM99999999999999999990.000') || ':' ||
          to_char(v_end::numeric, 'FM99999999999999999990.000'),
        'sourceDriveSessionId', p_drive, 'validatedRoadId', p_road,
        'matchedSectionId', s.section_key, 'directionKey', 'precision-forward',
        'startOffsetMeters', v_start, 'endOffsetMeters', v_end,
        'minLatitude', v_bounds.min_lat, 'maxLatitude', v_bounds.max_lat,
        'minLongitude', v_bounds.min_lon, 'maxLongitude', v_bounds.max_lon,
        'processingVersion', 3));
    end if;
    v_start := v_end;
  end loop;
  return jsonb_build_object('baseGeneration', 0, 'generation', 1,
    'operationId', 'world:' || p_drive || ':v1', 'operationReason', 'recordProcessing',
    'sourceDriveSessionId', p_drive, 'driveScoreAlgorithmVersion', 1,
    'validatedRoadProcessingVersion', 6, 'processedDriveSessionIds', jsonb_build_array(p_drive),
    'traces', v_traces);
end;
$$;

do $$
declare
  v_user uuid;
  v_publish uuid := gen_random_uuid();
  v_road uuid := gen_random_uuid();
  v_drive text := 'synthetic-precision-' || v_publish::text;
  v_canonical double precision := '6998.4040194567788'::double precision;
  v_exact text;
  v_plan jsonb;
  v_bad_plan jsonb;
  v_result jsonb;
  v_delta double precision;
  v_message text;
begin
  if (select current_generation from public.world_active_world_state where singleton) <> 0
      or exists (select 1 from public.world_active_world_traces)
      or (select count(*) from public.world_active_world_generations) <> 1 then
    raise exception 'precision regression requires an empty DEV world';
  end if;
  select user_id into strict v_user from public.world_publishes order by created_at limit 1;
  insert into public.world_publishes (id, user_id, local_drive_id, started_at,
    ended_at, distance_meters, world_rules_version, status, source_path, source_ready_at)
  values (v_publish, v_user, v_drive, now() - interval '1 hour', now(), v_canonical,
    6, 'processing', 'synthetic-precision/' || v_publish || '.json', now());
  insert into public.world_validated_roads (id, publish_id, user_id, provider_id,
    processing_version, valid_distance_meters, validation_status, direction_key, section_count, geometry)
  values (v_road, v_publish, v_user, 'synthetic-regression', 3, v_canonical, 'validated',
    'precision-forward', 1, extensions.ST_GeomFromText('MULTILINESTRING((0 0,0.02 0))',4326));
  insert into public.world_validated_road_sections (validated_road_id, section_key,
    section_order, distance_meters, source_trace_index, source_chunk_index, geometry)
  values (v_road, 'b-precision', 0, v_canonical, 0, 0,
    extensions.ST_GeomFromText('LINESTRING(0 0,0.02 0)',4326));

  select distance_meters into strict v_exact
    from public.get_world_validated_road_sections_for_processing_exact(v_road);
  if v_exact::double precision <> v_canonical or
      v_canonical = '6998.4040194567797'::double precision then
    raise exception 'canonical float8 round-trip regression';
  end if;
  v_plan := pg_temp.precision_plan(v_road, v_drive);
  if (v_plan->'traces'->0->>'endOffsetMeters')::double precision <> v_canonical
      or v_plan->'traces'->0->>'id' <> v_drive || ':' || v_road || ':b-precision:0.000:6998.404' then
    raise exception 'canonical plan/trace ID regression';
  end if;
  insert into precision_test_results values ('exact float8/JSON round-trip and deterministic ID');

  foreach v_delta in array array[0.1::double precision, 1.0::double precision] loop
    -- The exception occurs after inserting generation metadata. PostgreSQL's
    -- subtransaction must remove that metadata and every other partial write.
    v_bad_plan := jsonb_set(v_plan, '{traces,0,endOffsetMeters}', to_jsonb(v_canonical + v_delta));
    begin
      perform public.activate_empty_world_publish(v_publish, 0, 1, 6, v_bad_plan);
      raise exception 'offset mismatch was accepted' using errcode = 'ZT002';
    exception when sqlstate 'P0001' then
      get stacked diagnostics v_message = message_text;
      if v_message <> 'empty-world trace offset mismatch' then raise; end if;
    end;
    if exists (select 1 from public.world_active_world_generations where generation <> 0)
        or exists (select 1 from public.world_active_world_traces)
        or (select status from public.world_publishes where id=v_publish) <> 'processing' then
      raise exception 'failed commit left partial state';
    end if;
  end loop;
  insert into precision_test_results values ('0.1m and 1m mismatch rejected; transaction rollback');

  begin
    v_result := public.activate_empty_world_publish(v_publish, 0, 1, 6, v_plan);
    if v_result->>'state' <> 'committed' or
        (select end_offset_meters from public.world_active_world_traces where source_publish_id=v_publish) <> v_canonical then
      raise exception 'exact commit changed canonical offset';
    end if;
    v_result := public.activate_empty_world_publish(v_publish, 0, 1, 6, v_plan);
    if v_result->>'state' <> 'already_processed' or
        (select count(*) from public.world_active_world_generations) <> 2 or
        (select count(*) from public.world_active_world_traces) <> 1 then
      raise exception 'duplicate commit is not idempotent';
    end if;
    -- Revert this synthetic activation before testing another empty-world plan.
    raise exception 'rollback synthetic activation' using errcode = 'ZT001';
  exception when sqlstate 'ZT001' then null;
  end;
  if (select current_generation from public.world_active_world_state where singleton) <> 0
      or exists (select 1 from public.world_active_world_traces)
      or (select status from public.world_publishes where id=v_publish) <> 'processing' then
    raise exception 'synthetic activation rollback failed';
  end if;
  insert into precision_test_results values ('single-section canonical commit and duplicate idempotency');

  update public.world_validated_road_sections set section_order=1,
    geometry=extensions.ST_GeomFromText('LINESTRING(0.01 0,0.02 0)',4326)
    where validated_road_id=v_road;
  insert into public.world_validated_road_sections (validated_road_id, section_key,
    section_order, distance_meters, source_trace_index, source_chunk_index, geometry)
  values
    (v_road, 'a-short', 0, 600, 0, 0, extensions.ST_GeomFromText('LINESTRING(0 0,0.01 0)',4326)),
    (v_road, 'c-tail', 2, 1200.25, 0, 0, extensions.ST_GeomFromText('LINESTRING(0.02 0,0.03 0)',4326));
  update public.world_validated_roads set section_count=3,
    valid_distance_meters=600+v_canonical+1200.25 where id=v_road;
  v_plan := pg_temp.precision_plan(v_road, v_drive);
  begin
    v_result := public.activate_empty_world_publish(v_publish, 0, 1, 6, v_plan);
    if v_result->>'state' <> 'committed' or (v_result->>'trace_count')::integer <> 2
        or (select end_offset_meters from public.world_active_world_traces
          where source_publish_id=v_publish and matched_section_id='c-tail') <> 600+v_canonical+1200.25 then
      raise exception 'cumulative canonical commit regression';
    end if;
    raise exception 'rollback synthetic activation' using errcode = 'ZT001';
  exception when sqlstate 'ZT001' then null;
  end;
  insert into precision_test_results values ('multi-section cumulative offsets and sub-km filter');
end;
$$;

select jsonb_agg(test) as passed_precision_tests from precision_test_results;
rollback;
