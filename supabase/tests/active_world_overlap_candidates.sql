-- DEV only. All synthetic versions are transient and rolled back.
begin;
set local statement_timeout='30s';
create temporary table overlap_test_results(test text) on commit drop;
do $$
declare
  v_snapshot jsonb;
  v_road uuid := gen_random_uuid();
  v_publish uuid := gen_random_uuid();
  v_user uuid;
  v_generation bigint;
  v_source_publish uuid;
  v_id text := 'synthetic-candidate-' || gen_random_uuid()::text;
begin
  select current_generation into strict v_generation from public.world_active_world_state where singleton;
  select p.user_id,p.id into strict v_user,v_source_publish
    from public.world_publishes p join public.world_active_world_traces t on t.source_publish_id=p.id
    where t.active_to_generation is null limit 1;
  insert into public.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version,status)
    values(v_publish,v_user,'synthetic-overlap-'||v_publish,now()-interval '1 hour',now(),6000,6,'processing');
  insert into public.world_validated_roads(id,publish_id,user_id,provider_id,processing_version,valid_distance_meters,
    validation_status,direction_key,section_count,geometry)
    values(v_road,v_publish,v_user,'synthetic',3,6000,'validated','unrelated-metadata',1,
      extensions.ST_GeomFromText('MULTILINESTRING((0 0,0.04 0))',4326));
  insert into public.world_validated_road_sections(validated_road_id,section_key,section_order,distance_meters,source_trace_index,source_chunk_index,geometry)
    values(v_road,'synthetic-section',0,6000,0,0,extensions.ST_GeomFromText('LINESTRING(0 0,0.04 0)',4326));
  -- Closed generation-zero version cannot be a current candidate.
  insert into public.world_active_world_traces(trace_id,active_from_generation,active_to_generation,
    source_publish_id,source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,
    direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
  values(v_id||'-closed',0,v_generation,v_publish,'synthetic-overlap-'||v_publish,v_road,'synthetic-section',0,6000,
    'unrelated-metadata',0,0,0,.04,extensions.ST_GeomFromText('LINESTRING(0 0,0.04 0)',4326),3,now(),now()),
    (v_id||'-current',v_generation,null,v_publish,'synthetic-overlap-'||v_publish,v_road,'synthetic-section',500,2000,
    'unrelated-metadata',0,0,0,.04,extensions.ST_GeomFromText('LINESTRING(0 0,0.04 0)',4326),3,now(),now());
  v_snapshot:=public.get_active_world_overlap_candidates(v_road);
  if v_snapshot->>'generation' <> v_generation::text or
      (v_snapshot->>'is_empty')::boolean or jsonb_array_length(v_snapshot->'candidates') <> 1 or
      v_snapshot->'candidates'->0->>'id' <> v_id||'-current' or
      v_snapshot->'candidates'->0->>'start_offset_meters' <> '500' or
      v_snapshot->'candidates'->0->>'end_offset_meters' <> '2000' or
      jsonb_array_length(v_snapshot->'roads') <> 1 or
      v_snapshot->'roads'->0->'sections'->0->'geometry'->>'type' <> 'LineString' then
    raise exception 'current-only candidate/span/source regression';
  end if;
  insert into overlap_test_results values('closed version excluded; current partial span and exact section preserved');
  update public.world_validated_roads set geometry=extensions.ST_GeomFromText('MULTILINESTRING((1 1,1.04 1))',4326) where id=v_road;
  v_snapshot:=public.get_active_world_overlap_candidates(v_road);
  if jsonb_array_length(v_snapshot->'candidates') <> 0 or (v_snapshot->>'is_empty')::boolean then
    raise exception 'spatial no-candidates must not imply empty world';
  end if;
  insert into overlap_test_results values('spatial locality; empty candidate list preserves non-empty state');
  if has_function_privilege('anon','public.get_active_world_overlap_candidates(uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.get_active_world_overlap_candidates(uuid)','EXECUTE') or
     not has_function_privilege('service_role','public.get_active_world_overlap_candidates(uuid)','EXECUTE') then
    raise exception 'candidate RPC privilege regression';
  end if;
  insert into overlap_test_results values('server-only grants');
end;
$$;
select jsonb_agg(test) as passed_tests from overlap_test_results;
rollback;
