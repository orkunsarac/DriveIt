$ErrorActionPreference='Stop'
$taskHeaders=@{Authorization=('Bearer '+$env:SUPABASE_ACCESS_TOKEN)}
$taskMigration=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../supabase/migrations/202610060003_planet_map_read.sql'))
$taskOptimized=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../supabase/migrations/202610060004_planet_clip_set_based.sql')) -replace '^begin;','' -replace 'commit;\s*$',''
$taskMigration=$taskMigration -replace '^begin;','' -replace "notify pgrst,'reload schema';",'' -replace 'commit;\s*$',''
$taskMigration=$taskMigration.Replace('public.world_','driveit_planet_test.world_').Replace('public.read_planet_viewport','driveit_planet_test.read_planet_viewport')
$taskBaseline=[regex]::Match($taskMigration,'(?s)create or replace function driveit_planet_test.world_map_clip_geometry.*?end \$\$;').Value.Replace('world_map_clip_geometry','world_map_clip_geometry_baseline')
$taskMigration+=$taskBaseline+$taskOptimized.Replace('public.world_','driveit_planet_test.world_')
$taskSetup=@'
begin;
set local request.jwt.claim.role='service_role';
create schema driveit_planet_test;
create table driveit_planet_test.world_active_world_state as select * from public.world_active_world_state;
create table driveit_planet_test.world_active_world_traces as select * from public.world_active_world_traces where false;
create table driveit_planet_test.world_validated_road_sections as select * from public.world_validated_road_sections where false;
create index test_bounds on driveit_planet_test.world_active_world_traces using gist(bounds) where active_to_generation is null;
create function driveit_planet_test.world_section_geometry_length_meters(extensions.geometry) returns float8
language sql immutable as 'select public.world_section_geometry_length_meters($1)';
'@
$taskCases=@'
do $$ declare original public.world_active_world_traces%rowtype; line extensions.geometry; dense extensions.geometry;
 before_clip extensions.geometry; after_clip extensions.geometry; response jsonb; lon float8; i integer;
begin
 select * into strict original from public.world_active_world_traces where active_to_generation is null limit 1;
 line:=extensions.ST_SetSRID(extensions.ST_MakeLine(extensions.ST_MakePoint(0,0),extensions.ST_MakePoint(4000/6371008.8*180/pi(),0)),4326);
 insert into driveit_planet_test.world_validated_road_sections
 select id,original.validated_road_id,original.matched_section_id,0,5000,confidence,source_trace_index,source_chunk_index,line,created_at
 from public.world_validated_road_sections where validated_road_id=original.validated_road_id limit 1;
 original.trace_id:='current'; original.active_from_generation:=2;original.active_to_generation:=null;
 original.start_offset_meters:=2400;original.end_offset_meters:=2600; original.bounds:=extensions.ST_Envelope(line);
 insert into driveit_planet_test.world_active_world_traces select original.*;
 original.trace_id:='retired';original.active_from_generation:=1;original.active_to_generation:=2;
 insert into driveit_planet_test.world_active_world_traces select original.*;
 original.trace_id:='future';original.active_from_generation:=3;original.active_to_generation:=null;
 insert into driveit_planet_test.world_active_world_traces select original.*;
 response:=driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12);
 if response->>'generation'<>'2' or jsonb_array_length(response->'traces')<>1 then raise exception 'current_generation_only'; end if;
 lon:=(response#>>'{traces,0,geometry,coordinates,0,0}')::float8;
 if abs(lon-(1920/6371008.8*180/pi()))>1e-12 then raise exception 'canonical_start'; end if;
 lon:=(response#>>'{traces,0,geometry,coordinates,1,0}')::float8;
 if abs(lon-(2080/6371008.8*180/pi()))>1e-12 then raise exception 'canonical_end'; end if;
 select extensions.ST_MakeLine(array_agg(extensions.ST_SetSRID(extensions.ST_MakePoint(29+k.seq*.0001,40+sin(k.seq*.03)*.001),4326) order by k.seq)) into dense from generate_series(0,572) k(seq);
 before_clip:=driveit_planet_test.world_map_clip_geometry_baseline(dense,.48,.52);
 after_clip:=driveit_planet_test.world_map_clip_geometry(dense,.48,.52);
 if extensions.ST_NPoints(before_clip)<>extensions.ST_NPoints(after_clip) or extensions.ST_HausdorffDistance(before_clip,after_clip)>1e-12 then raise exception 'dense_clip_parity';end if;
 if response::text~'telemetry|source_path|user_id|publish_id|drive_id' then raise exception 'private_payload_leak'; end if;
 if jsonb_array_length(driveit_planet_test.read_planet_viewport(10,10.1,20,20.1,12)->'traces')<>0 then raise exception 'outside'; end if;
 if jsonb_array_length(driveit_planet_test.read_planet_viewport(-.01,.01,.001,.002,12)->'traces')<>0 then raise exception 'partial_outside_full_section'; end if;
 if driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,5)->>'state'<>'zoom_in' then raise exception 'low_zoom'; end if;
 if driveit_planet_test.read_planet_viewport(-2,2,0,.1,12)->>'state'<>'zoom_in' then raise exception 'large_viewport'; end if;
 if jsonb_array_length(driveit_planet_test.read_planet_viewport(-.01,.01,179.9,-179.9,12)->'traces')<>0 then raise exception 'dateline'; end if;
 begin perform driveit_planet_test.read_planet_viewport(5,4,0,.1,12);raise exception 'invalid_not_rejected'; exception when sqlstate '22023' then null;end;
 begin perform driveit_planet_test.read_planet_viewport('NaN',4,0,.1,12);raise exception 'nan_not_rejected'; exception when sqlstate '22023' then null;end;
 if response<>driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12) then raise exception 'nondeterministic';end if;
 -- Move the target to section 1: cumulative prefix must be subtracted exactly.
 update driveit_planet_test.world_validated_road_sections set section_order=1;
 insert into driveit_planet_test.world_validated_road_sections
 select '00000000-0000-4000-8000-000000000001',validated_road_id,'prefix',0,1000,confidence,0,0,geometry,created_at
 from driveit_planet_test.world_validated_road_sections limit 1;
 update driveit_planet_test.world_active_world_traces set start_offset_meters=3400,end_offset_meters=3600 where trace_id='current';
 response:=driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12);
 if abs((response#>>'{traces,0,geometry,coordinates,0,0}')::float8-(1920/6371008.8*180/pi()))>1e-12 then raise exception 'cumulative_prefix';end if;
 perform set_config('request.jwt.claim.role','anon',true);
 begin perform driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12);raise exception 'auth_not_rejected'; exception when sqlstate '42501' then null;end;
 perform set_config('request.jwt.claim.role','service_role',true);
 for i in 1..201 loop
 original.trace_id:='limit:'||i;original.active_from_generation:=2;original.active_to_generation:=null;
 insert into driveit_planet_test.world_active_world_traces select original.*;
 end loop;
 if driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12)->>'state'<>'zoom_in' then raise exception 'result_limit'; end if;
 if has_function_privilege('anon','driveit_planet_test.read_planet_viewport(float8,float8,float8,float8,float8)','EXECUTE')
 or not has_function_privilege('authenticated','driveit_planet_test.read_planet_viewport(float8,float8,float8,float8,float8)','EXECUTE') then raise exception 'read_grants';end if;
end $$;
-- Representative bounded spatial selection on 20k distant synthetic versions.
insert into driveit_planet_test.world_active_world_traces
select 'distant:'||i,2,null,t.source_publish_id,t.source_drive_session_id,t.validated_road_id,t.matched_section_id,
t.start_offset_meters,t.end_offset_meters,t.direction_key,t.min_latitude,t.max_latitude,t.min_longitude,t.max_longitude,
extensions.ST_MakeEnvelope(100+(i%100)*.01,30+(i/100)*.01,100+(i%100)*.01+.001,30+(i/100)*.01+.001,4326),t.processing_version,t.created_at,t.updated_at
from driveit_planet_test.world_active_world_traces t cross join generate_series(1,20000) i where trace_id='current';
analyze driveit_planet_test.world_active_world_traces;
do $$ declare plan json; begin
execute 'explain (analyze,buffers,format json) select trace_id from driveit_planet_test.world_active_world_traces where active_to_generation is null and active_from_generation<=2 and bounds && extensions.ST_MakeEnvelope(0,-.01,.1,.01,4326) limit 201' into plan;
if plan::text not like '%test_bounds%' then raise exception 'spatial_index_unused';end if;
end $$;
create table driveit_planet_test.measurement(value jsonb);
delete from driveit_planet_test.world_active_world_traces where trace_id like 'limit:%';
insert into driveit_planet_test.world_active_world_traces
select 'visible:'||i,2,null,t.source_publish_id,t.source_drive_session_id,t.validated_road_id,t.matched_section_id,
t.start_offset_meters,t.end_offset_meters,t.direction_key,t.min_latitude,t.max_latitude,t.min_longitude,t.max_longitude,
t.bounds,t.processing_version,t.created_at,t.updated_at
from driveit_planet_test.world_active_world_traces t cross join generate_series(1,99) i where trace_id='current';
do $$ declare plan json; started timestamptz; response jsonb; elapsed float8; begin
 execute 'explain (analyze,buffers,format json) select trace_id from driveit_planet_test.world_active_world_traces where active_to_generation is null and active_from_generation<=2 and bounds && extensions.ST_MakeEnvelope(0,-.01,.1,.01,4326) limit 201' into plan;
 started:=clock_timestamp();response:=driveit_planet_test.read_planet_viewport(-.01,.01,0,.1,12);
 elapsed:=extract(epoch from clock_timestamp()-started)*1000;
 if jsonb_array_length(response->'traces')<>100 then raise exception 'multi_trace_response';end if;
 insert into driveit_planet_test.measurement values(jsonb_build_object('assertions_passed',true,'spatial_plan',plan,'visible_traces',100,
 'synthetic_total_traces',(select count(*) from driveit_planet_test.world_active_world_traces),'payload_bytes',octet_length(response::text),'read_ms',elapsed));
end $$;
select value from driveit_planet_test.measurement;
rollback;
'@
$taskSql=$taskSetup+$taskMigration+$taskCases
try {
 $taskResponse=Invoke-RestMethod -Method Post -Uri 'https://api.supabase.com/v1/projects/viqngnjfgknpxtoapzcg/database/query' -Headers $taskHeaders -ContentType 'application/json' -Body (@{query=$taskSql}|ConvertTo-Json)
 $taskResponse|ConvertTo-Json -Depth 12
} catch { Write-Output $_.ErrorDetails.Message;exit 1 }
