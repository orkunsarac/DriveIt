begin;
create schema driveit_2c_test;
create table driveit_2c_test.world_publishes (like public.world_publishes including all);
create table driveit_2c_test.world_validated_roads (like public.world_validated_roads including all);
create table driveit_2c_test.world_validated_road_sections (like public.world_validated_road_sections including all);
create table driveit_2c_test.world_active_world_generations (like public.world_active_world_generations including all);
create table driveit_2c_test.world_active_world_state (like public.world_active_world_state including all);
create table driveit_2c_test.world_active_world_traces (like public.world_active_world_traces including all);
alter table driveit_2c_test.world_active_world_traces add foreign key (active_from_generation) references driveit_2c_test.world_active_world_generations(generation);
alter table driveit_2c_test.world_active_world_traces add foreign key (active_to_generation) references driveit_2c_test.world_active_world_generations(generation);
alter table driveit_2c_test.world_active_world_traces add foreign key (source_publish_id) references driveit_2c_test.world_publishes(id);
alter table driveit_2c_test.world_active_world_traces add foreign key (validated_road_id) references driveit_2c_test.world_validated_roads(id);
alter table driveit_2c_test.world_active_world_state add foreign key (current_generation) references driveit_2c_test.world_active_world_generations(generation);
/* FUNCTION */
create temp table mutation_test_results(name text, passed boolean, commit_ms double precision);
do $test$
declare
  c jsonb; t jsonb; r jsonb; s jsonb; v_id uuid; v_pub uuid;
  v_plan jsonb; v_result jsonb; v_before text; v_after text; v_bad jsonb;
  v_expected integer; v_order integer; v_error boolean; v_started timestamptz;
begin
  for c in select * from jsonb_array_elements($fixtures$/* FIXTURES */$fixtures$::jsonb) loop
    truncate driveit_2c_test.world_active_world_traces,driveit_2c_test.world_active_world_state,
      driveit_2c_test.world_active_world_generations,driveit_2c_test.world_validated_road_sections,
      driveit_2c_test.world_validated_roads,driveit_2c_test.world_publishes;
    -- Templates supply existing required schema fields; actual route geometry,
    -- identifiers, timestamps and source pointers below are synthetic. No real
    -- record is updated and no Storage/source download occurs.
    for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('id','00000000-0000-4000-8000-000000000011','driveId','owner-drive'),
      jsonb_build_object('id','00000000-0000-4000-8000-000000000012','driveId','owner2-drive'),c->'challenger')) loop
      v_id:=(r->>'id')::uuid;
      v_pub:=case v_id when '00000000-0000-4000-8000-000000000011' then '00000000-0000-4000-8000-000000000021'::uuid
        when '00000000-0000-4000-8000-000000000012' then '00000000-0000-4000-8000-000000000022'::uuid
        else '00000000-0000-4000-8000-000000000023'::uuid end;
      insert into driveit_2c_test.world_publishes select (jsonb_populate_record(null::public.world_publishes,
        to_jsonb(p)||jsonb_build_object('id',v_pub,'local_drive_id',r->>'driveId',
          'status',case when v_pub=(c->>'publishId')::uuid then 'processing' else 'published' end,
          'source_path',v_pub::text||'.json','source_ready_at',now(),'validation_claim_token',null,
          'processed_at',null,'error_code',null))).* from public.world_publishes p limit 1;
      insert into driveit_2c_test.world_validated_roads select (jsonb_populate_record(null::public.world_validated_roads,
        to_jsonb(v)||jsonb_build_object('id',v_id,'publish_id',v_pub,'valid_distance_meters',10000,
          'section_count',1,'processing_version',3,'direction_key','east',
          'geometry',encode(extensions.ST_AsEWKB(extensions.ST_GeomFromText('MULTILINESTRING((0 0,0.1 0))',4326)),'hex')))).*
        from public.world_validated_roads v limit 1;
      v_order:=0;
      for s in select * from jsonb_array_elements(case when r ? 'sections' then r->'sections'
        else jsonb_build_array(jsonb_build_object('id',case when r->>'driveId'='owner-drive' then 'owner-section' else 'owner2-section' end,
          'distanceMeters',10000,'geometry',jsonb_build_array(jsonb_build_object('latitude',0,'longitude',0),jsonb_build_object('latitude',0,'longitude',.1)))) end) loop
        insert into driveit_2c_test.world_validated_road_sections select (jsonb_populate_record(null::public.world_validated_road_sections,
          to_jsonb(v)||jsonb_build_object('id',gen_random_uuid(),'validated_road_id',v_id,'section_key',s->>'id',
            'section_order',v_order,'distance_meters',s->'distanceMeters','geometry',encode(extensions.ST_AsEWKB(
              extensions.ST_SetSRID(extensions.ST_MakeLine(
                extensions.ST_MakePoint((s->'geometry'->0->>'longitude')::float8,(s->'geometry'->0->>'latitude')::float8),
                extensions.ST_MakePoint((s->'geometry'->1->>'longitude')::float8,(s->'geometry'->1->>'latitude')::float8)),4326)),'hex')))).*
          from public.world_validated_road_sections v limit 1;
        v_order:=v_order+1;
      end loop;
    end loop;
    insert into driveit_2c_test.world_active_world_generations select (jsonb_populate_record(null::public.world_active_world_generations,
      to_jsonb(g)||jsonb_build_object('generation',1,'base_generation',0,'operation_id','synthetic-initial',
        'source_publish_id','00000000-0000-4000-8000-000000000021','source_drive_session_id','owner-drive',
        'trace_count',jsonb_array_length(c->'snapshot'->'candidates')))).*
      from public.world_active_world_generations g where generation=1;
    insert into driveit_2c_test.world_active_world_state values(true,1,now());
    for t in select * from jsonb_array_elements(c->'snapshot'->'candidates') loop
      insert into driveit_2c_test.world_active_world_traces(trace_id,active_from_generation,source_publish_id,
        source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,
        direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
      values(t->>'id',1,(t->>'sourcePublishId')::uuid,t->>'sourceDriveId',(t->>'validatedRoadId')::uuid,
        t->>'matchedSectionId',(t->>'startOffsetMeters')::float8,(t->>'endOffsetMeters')::float8,'east',0,0,0,.1,
        extensions.ST_MakeEnvelope(0,0,.1,0,4326),3,now(),now());
    end loop;
    v_plan:=c->'plan';
    if c->>'name'='middle' then
      for v_bad in select jsonb_set(v_plan,'{createTraces,0,startOffsetMeters}','"-1"'::jsonb)
        union all select jsonb_set(v_plan,'{createTraces,0,sourcePublishId}','"00000000-0000-4000-8000-000000000099"'::jsonb)
        union all select jsonb_set(v_plan,'{createTraces,0,endOffsetMeters}','"99999"'::jsonb)
        union all select jsonb_set(v_plan,'{createTraces,0,minLatitude}','"99"'::jsonb) loop
        v_error:=false;
        begin
          v_result:=driveit_2c_test.commit_active_world_mutation((c->>'publishId')::uuid,1,v_bad);
        exception when others then v_error:=true;
        end;
        if not v_error then raise exception 'Tampered invariant accepted'; end if;
      end loop;
    end if;
    -- CAS reject leaves the entire isolated snapshot unchanged.
    v_result:=driveit_2c_test.commit_active_world_mutation((c->>'publishId')::uuid,0,v_plan);
    if v_result->>'state'<>'stale_generation' then raise exception 'CAS test failed'; end if;
    select md5(string_agg(row_to_json(trace_row)::text,',' order by trace_id)) into v_before from driveit_2c_test.world_active_world_traces trace_row;
    -- Trigger failure AFTER retirement/insertion proves transaction rollback,
    -- rather than only rejecting an invalid input before writes.
    begin
      execute 'create function driveit_2c_test.fail_publish() returns trigger language plpgsql as ''begin raise exception ''''injected_post_insert_failure''''; end''';
      execute 'create trigger fail_publish before update on driveit_2c_test.world_publishes for each row execute function driveit_2c_test.fail_publish()';
      v_result:=driveit_2c_test.commit_active_world_mutation((c->>'publishId')::uuid,1,v_plan);
      raise exception 'Expected rollback not raised';
    exception when raise_exception then
      if sqlerrm <> 'injected_post_insert_failure' then raise; end if;
    end;
    select md5(string_agg(row_to_json(trace_row)::text,',' order by trace_id)) into v_after from driveit_2c_test.world_active_world_traces trace_row;
    if v_before is distinct from v_after or exists(select 1 from driveit_2c_test.world_active_world_generations where generation=2) then
      raise exception 'Partial transaction survived'; end if;
    v_started:=clock_timestamp();
    v_result:=driveit_2c_test.commit_active_world_mutation((c->>'publishId')::uuid,1,v_plan);
    if v_result->>'state'<>'committed' then raise exception 'Commit failed'; end if;
    select count(*) into v_expected from driveit_2c_test.world_active_world_traces where active_to_generation is null;
    if v_expected<>(v_result->>'trace_count')::integer then raise exception 'trace count mismatch'; end if;
    for t in select * from jsonb_array_elements(v_plan->'createTraces') loop
      if not exists(select 1 from driveit_2c_test.world_active_world_traces trace_row
        where trace_row.trace_id=t->>'id' and trace_row.active_from_generation=2 and trace_row.active_to_generation is null
          and trace_row.start_offset_meters=(t->>'startOffsetMeters')::float8
          and trace_row.end_offset_meters=(t->>'endOffsetMeters')::float8
          and trace_row.source_publish_id=(t->>'sourcePublishId')::uuid
          and trace_row.validated_road_id=(t->>'validatedRoadId')::uuid
          and trace_row.direction_key=t->>'directionKey') then raise exception 'Persisted trace mismatch'; end if;
    end loop;
    if (select current_generation from driveit_2c_test.world_active_world_state)<>2 then raise exception 'pointer mismatch'; end if;
    if (select status from driveit_2c_test.world_publishes where id=(c->>'publishId')::uuid)<>'published' then raise exception 'publish not completed'; end if;
    -- Committed-but-response-lost duplicate accepts the stale original plan
    -- without inserting another generation or temporal trace version.
    v_result:=driveit_2c_test.commit_active_world_mutation((c->>'publishId')::uuid,1,v_plan);
    if v_result->>'state'<>'already_processed' then raise exception 'duplicate failed'; end if;
    if (select count(*) from driveit_2c_test.world_active_world_generations)<>2 then raise exception 'duplicate generation'; end if;
    insert into mutation_test_results values(c->>'name',true,extract(epoch from clock_timestamp()-v_started)*1000);
  end loop;
  if has_function_privilege('authenticated','driveit_2c_test.commit_active_world_mutation(uuid,bigint,jsonb)','EXECUTE') then
    raise exception 'Mobile may mutate'; end if;
end;
$test$;
select count(*) as passed, bool_and(passed) as all_passed,avg(commit_ms) as mean_commit_check_ms,
  max(commit_ms) as max_commit_check_ms from mutation_test_results;
rollback;
