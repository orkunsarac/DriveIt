begin;
create index if not exists world_active_world_traces_current_section_idx
  on public.world_active_world_traces(validated_road_id,matched_section_id,direction_key,start_offset_meters,end_offset_meters)
  where active_to_generation is null;

-- Same MVCC candidate snapshot; only current spatial candidates are hydrated.
-- No whole-world / historical drive scan and no copied unchanged trace rows.
create or replace function public.get_active_world_mutation_snapshot(p_challenger_road_id uuid)
returns jsonb language sql stable security definer
set search_path = pg_catalog, extensions, public, pg_temp
set extra_float_digits = 3
as $$
  with snapshot as materialized (
    select public.get_active_world_overlap_candidates(p_challenger_road_id) value
  )
  select value || jsonb_build_object(
    'candidates',coalesce((select jsonb_agg(c || jsonb_build_object(
      'min_latitude',t.min_latitude::text,'max_latitude',t.max_latitude::text,
      'min_longitude',t.min_longitude::text,'max_longitude',t.max_longitude::text,
      'created_at',t.created_at,'updated_at',t.updated_at) order by t.trace_id)
      from jsonb_array_elements(value->'candidates') c
      join public.world_active_world_traces t on t.trace_id=c->>'id'
        and t.active_from_generation=(c->>'active_from_generation')::bigint),'[]'::jsonb),
    'roads',coalesce((select jsonb_agg(r || jsonb_build_object(
      'direction_key',v.direction_key,'processing_version',v.processing_version) order by v.id)
      from jsonb_array_elements(value->'roads') r
      join public.world_validated_roads v on v.id=(r->>'id')::uuid),'[]'::jsonb))
  from snapshot;
$$;
revoke all on function public.get_active_world_mutation_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.get_active_world_mutation_snapshot(uuid) to service_role;

create or replace function public.commit_active_world_mutation(
  p_publish_id uuid, p_expected_generation bigint, p_plan jsonb)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, extensions, public, pg_temp
set extra_float_digits = 3
as $$
declare
  v_current bigint; v_next bigint; v_done public.world_active_world_generations%rowtype;
  v_publish public.world_publishes%rowtype; v_road public.world_validated_roads%rowtype;
  v_owner public.world_publishes%rowtype; v_source public.world_validated_roads%rowtype;
  v_section public.world_validated_road_sections%rowtype;
  v_old public.world_active_world_traces%rowtype;
  v_item jsonb; v_start double precision; v_end double precision;
  v_prefix double precision; v_length double precision; v_total integer;
  v_prefix_section record;
  v_closed integer := 0; v_created integer := 0; v_now timestamptz := now();
begin
  -- Global serialization and publish idempotency precede stale-plan rejection.
  select current_generation into strict v_current from public.world_active_world_state
    where singleton for update;
  select * into v_done from public.world_active_world_generations where source_publish_id=p_publish_id;
  if found then return jsonb_build_object('state','already_processed','generation',v_done.generation::text,
    'operation_id',v_done.operation_id,'trace_count',v_done.trace_count); end if;
  if v_current <> p_expected_generation then
    return jsonb_build_object('state','stale_generation','generation',v_current::text);
  end if;
  select * into strict v_publish from public.world_publishes where id=p_publish_id for update;
  select * into strict v_road from public.world_validated_roads where publish_id=p_publish_id;
  if v_publish.status <> 'processing' or v_publish.source_ready_at is null then
    raise exception 'invalid_publish_state' using errcode='22023';
  end if;
  if not (v_road.valid_distance_meters >= 5000 and v_road.valid_distance_meters < 'Infinity'::float8) then
    raise exception 'ineligible_validated_road' using errcode='22023'; end if;
  v_next := v_current+1;
  if jsonb_typeof(p_plan) <> 'object' or jsonb_typeof(p_plan->'closeVersions') <> 'array'
    or jsonb_typeof(p_plan->'createTraces') <> 'array'
    or p_plan->>'baseGeneration' is distinct from v_current::text
    or p_plan->>'generation' is distinct from v_next::text
    or p_plan->>'operationId' is distinct from ('world:'||v_publish.local_drive_id||':v1')
    or jsonb_array_length(p_plan->'closeVersions') > 10000
    or jsonb_array_length(p_plan->'createTraces') > 20000 then
    raise exception 'invalid_mutation_plan' using errcode='22023';
  end if;
  if (select count(*) <> count(distinct c->>'id') from jsonb_array_elements(p_plan->'closeVersions') c)
    or (select count(*) <> count(distinct c->>'id') from jsonb_array_elements(p_plan->'createTraces') c) then
    raise exception 'duplicate_plan_trace' using errcode='22023';
  end if;
  -- Every retirement is the exact version from this current spatial snapshot.
  for v_item in select * from jsonb_array_elements(p_plan->'closeVersions') loop
    select * into strict v_old from public.world_active_world_traces
      where trace_id=v_item->>'id' and active_from_generation=(v_item->>'fromGeneration')::bigint
        and active_to_generation is null and active_from_generation<=v_current for update;
    if not (v_old.bounds && extensions.ST_Envelope(v_road.geometry)) then
      raise exception 'retirement_outside_candidates' using errcode='22023';
    end if;
  end loop;
  -- Validate reference, provenance, interval and temporal consistency. SQL does
  -- not elect winners; only the shared Dart planner makes ownership decisions.
  for v_item in select * from jsonb_array_elements(p_plan->'createTraces') loop
    v_start := (v_item->>'startOffsetMeters')::double precision;
    v_end := (v_item->>'endOffsetMeters')::double precision;
    if v_start is null or v_end is null or v_start<0 or v_end<=v_start
      or v_start in ('NaN'::float8,'Infinity'::float8,'-Infinity'::float8)
      or v_end in ('NaN'::float8,'Infinity'::float8,'-Infinity'::float8)
      or v_end-v_start<1000 or coalesce(length(v_item->>'id'),0)=0 then
      raise exception 'invalid_trace_span' using errcode='22023';
    end if;
    select * into strict v_source from public.world_validated_roads where id=(v_item->>'validatedRoadId')::uuid;
    select * into strict v_owner from public.world_publishes where id=v_source.publish_id;
    select * into strict v_section from public.world_validated_road_sections
      where validated_road_id=v_source.id and section_key=v_item->>'matchedSectionId';
    if v_source.user_id is distinct from v_owner.user_id
      or v_owner.id is distinct from (v_item->>'sourcePublishId')::uuid
      or v_owner.local_drive_id is distinct from v_item->>'sourceDriveId'
      or (v_owner.id<>p_publish_id and v_owner.status<>'published')
      or v_source.processing_version is distinct from (v_item->>'processingVersion')::integer
      or coalesce(v_item->>'directionKey','')='' then
      raise exception 'invalid_trace_provenance' using errcode='22023';
    end if;
    -- Ordered float8 addition exactly matches Dart cumulative offsets. An
    -- unordered SUM (or numeric rounding) can move a physical boundary by ULPs.
    v_prefix:=0;
    for v_prefix_section in select distance_meters,geometry from public.world_validated_road_sections
      where validated_road_id=v_source.id and section_order<v_section.section_order order by section_order loop
      v_prefix:=v_prefix + case when v_prefix_section.distance_meters>0 then v_prefix_section.distance_meters else
        public.world_section_geometry_length_meters(v_prefix_section.geometry) end;
    end loop;
    v_length := case when v_section.distance_meters>0 then v_section.distance_meters else
      public.world_section_geometry_length_meters(v_section.geometry) end;
    if v_start<v_prefix or v_end>v_prefix+v_length then
      raise exception 'trace_outside_canonical_section' using errcode='22023';
    end if;
    if v_source.id=v_road.id then
      if v_item->>'directionKey' is distinct from v_source.direction_key
        or (v_item->>'minLatitude')::float8 is distinct from extensions.ST_YMin(v_section.geometry::extensions.box3d)
        or (v_item->>'maxLatitude')::float8 is distinct from extensions.ST_YMax(v_section.geometry::extensions.box3d)
        or (v_item->>'minLongitude')::float8 is distinct from extensions.ST_XMin(v_section.geometry::extensions.box3d)
        or (v_item->>'maxLongitude')::float8 is distinct from extensions.ST_XMax(v_section.geometry::extensions.box3d) then
        raise exception 'invalid_challenger_bounds' using errcode='22023';
      end if;
    else
      -- A remainder cannot invent ownership, widen, change direction or bounds.
      if not exists (select 1 from public.world_active_world_traces t
        join jsonb_array_elements(p_plan->'closeVersions') c on t.trace_id=c->>'id'
          and t.active_from_generation=(c->>'fromGeneration')::bigint
        where t.validated_road_id=v_source.id and t.matched_section_id=v_section.section_key
          and t.source_publish_id=v_owner.id and t.active_to_generation is null
          and t.direction_key=v_item->>'directionKey'
          and t.min_latitude=(v_item->>'minLatitude')::float8 and t.max_latitude=(v_item->>'maxLatitude')::float8
          and t.min_longitude=(v_item->>'minLongitude')::float8 and t.max_longitude=(v_item->>'maxLongitude')::float8) then
        raise exception 'invalid_incumbent_remainder' using errcode='22023';
      end if;
      -- Adjacent same-source versions can merge in Dart. Prove that the new
      -- interval is covered by their union, not necessarily one old version.
      with closed as (
        select t.start_offset_meters a,t.end_offset_meters b
        from public.world_active_world_traces t join jsonb_array_elements(p_plan->'closeVersions') c
          on t.trace_id=c->>'id' and t.active_from_generation=(c->>'fromGeneration')::bigint
        where t.validated_road_id=v_source.id and t.matched_section_id=v_section.section_key
          and t.source_publish_id=v_owner.id and t.direction_key=v_item->>'directionKey'
          and t.end_offset_meters>v_start and t.start_offset_meters<v_end
      ), ordered as (
        select a,b,max(b) over(order by a,b rows between unbounded preceding and 1 preceding) previous_end from closed
      ) select min(a),max(b) into v_prefix,v_length from ordered;
      if v_prefix is null or v_start<v_prefix or v_end>v_length or exists (
        select 1 from (
          select t.start_offset_meters a,max(t.end_offset_meters) over(order by t.start_offset_meters,t.end_offset_meters
            rows between unbounded preceding and 1 preceding) previous_end
          from public.world_active_world_traces t join jsonb_array_elements(p_plan->'closeVersions') c
            on t.trace_id=c->>'id' and t.active_from_generation=(c->>'fromGeneration')::bigint
          where t.validated_road_id=v_source.id and t.matched_section_id=v_section.section_key
            and t.source_publish_id=v_owner.id and t.direction_key=v_item->>'directionKey'
            and t.end_offset_meters>v_start and t.start_offset_meters<v_end
        ) intervals where previous_end is not null and a-previous_end>.01
      ) then raise exception 'remainder_expands_ownership' using errcode='22023'; end if;
    end if;
  end loop;
  select trace_count into strict v_total from public.world_active_world_generations where generation=v_current;
  v_closed:=jsonb_array_length(p_plan->'closeVersions'); v_created:=jsonb_array_length(p_plan->'createTraces');
  insert into public.world_active_world_generations(generation,base_generation,operation_id,operation_reason,
    source_publish_id,source_drive_session_id,drive_score_algorithm_version,validated_road_processing_version,
    valid_distance_meters,trace_count,created_at)
  values(v_next,v_current,p_plan->>'operationId','recordProcessing',p_publish_id,v_publish.local_drive_id,
    1,6,v_road.valid_distance_meters,v_total-v_closed+v_created,v_now);
  update public.world_active_world_traces t set active_to_generation=v_next
    from jsonb_array_elements(p_plan->'closeVersions') c
    where t.trace_id=c->>'id' and t.active_from_generation=(c->>'fromGeneration')::bigint;
  insert into public.world_active_world_traces(trace_id,active_from_generation,source_publish_id,
    source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,
    direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
  select t->>'id',v_next,(t->>'sourcePublishId')::uuid,t->>'sourceDriveId',(t->>'validatedRoadId')::uuid,
    t->>'matchedSectionId',(t->>'startOffsetMeters')::float8,(t->>'endOffsetMeters')::float8,t->>'directionKey',
    (t->>'minLatitude')::float8,(t->>'maxLatitude')::float8,(t->>'minLongitude')::float8,(t->>'maxLongitude')::float8,
    extensions.ST_MakeEnvelope((t->>'minLongitude')::float8,(t->>'minLatitude')::float8,
      (t->>'maxLongitude')::float8,(t->>'maxLatitude')::float8,4326),
    (t->>'processingVersion')::integer,(t->>'createdAt')::timestamptz,(t->>'updatedAt')::timestamptz
  from jsonb_array_elements(p_plan->'createTraces') t;
  -- No duplicate interval ownership for any newly created source section.
  if exists (select 1 from public.world_active_world_traces a join public.world_active_world_traces b
    on a.validated_road_id=b.validated_road_id and a.matched_section_id=b.matched_section_id
      and a.direction_key=b.direction_key and a.trace_id<>b.trace_id
      and a.active_from_generation=v_next and a.active_to_generation is null and b.active_to_generation is null
      and least(a.end_offset_meters,b.end_offset_meters)-greatest(a.start_offset_meters,b.start_offset_meters)>.01) then
    raise exception 'duplicate_active_interval' using errcode='22023';
  end if;
  update public.world_publishes set status='published',processed_at=v_now,error_code=null where id=p_publish_id;
  update public.world_active_world_state set current_generation=v_next,updated_at=v_now where singleton;
  return jsonb_build_object('state','committed','generation',v_next::text,'operation_id',p_plan->>'operationId',
    'trace_count',v_total-v_closed+v_created);
end;
$$;
revoke all on function public.commit_active_world_mutation(uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.commit_active_world_mutation(uuid,bigint,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
