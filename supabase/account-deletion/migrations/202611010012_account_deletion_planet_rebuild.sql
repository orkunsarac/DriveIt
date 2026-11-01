begin;
-- Forward candidate, never part of an implicit PROD deployment.
alter table public.account_deletion_jobs add column planet_rebuilt_generation bigint;

create function public.account_deletion_planet_context(p_id uuid,p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' set extra_float_digits=3 as $$
declare v uuid;g bigint;data jsonb;
begin
 select owner_id into v from public.account_deletion_jobs where id=p_id and lease=p_lease and lease_until>clock_timestamp();
 if v is null then raise exception 'lease_invalid';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('account_delete:'||v::text,0));
 perform 1 from public.account_deletion_jobs where id=p_id and owner_id=v and lease=p_lease and lease_until>clock_timestamp() for update;
 if not found then raise exception 'lease_invalid';end if;
 select current_generation into strict g from public.world_active_world_state where singleton for update;
 if (select planet_rebuilt_generation=g from public.account_deletion_jobs where id=p_id) then return jsonb_build_object('state','ready');end if;
 if not exists(select 1 from public.world_validated_roads where user_id=v) or
 not exists(select 1 from public.world_validated_roads where user_id<>v) then return jsonb_build_object('state','not_required');end if;
 -- No invented ordering/ownership for legacy, incomplete, or concurrently deleting sources.
 if exists(select 1 from public.account_deletion_jobs j join public.world_publishes p on p.user_id=j.owner_id where j.id<>p_id and j.state<>'completed')
 or (select count(*) from public.world_validated_roads where user_id<>v)>32
 or (select count(*) from public.world_validated_road_sections s join public.world_validated_roads r on r.id=s.validated_road_id where r.user_id<>v)>512
 or exists(select 1 from public.world_validated_roads r join public.world_publishes p on p.id=r.publish_id
 left join public.world_active_world_generations h on h.source_publish_id=p.id
 where r.user_id<>v and (p.user_id<>r.user_id or p.status<>'published' or r.processing_version<>6 or h.generation is null or
 r.section_count<>(select count(*) from public.world_validated_road_sections where validated_road_id=r.id) or
 r.valid_distance_meters<5000 or p.source_path is distinct from (p.user_id::text||'/'||p.id::text||'.json') or p.source_ready_at is null))
 or exists(select 1 from public.world_active_world_traces t join public.world_publishes p on p.id=t.source_publish_id
 where p.user_id<>v and not exists(select 1 from public.world_validated_roads r where r.id=t.validated_road_id and r.publish_id=p.id and r.user_id=p.user_id))
 then return jsonb_build_object('state','blocked_planet');end if;
 select coalesce(jsonb_agg(jsonb_build_object(
 'source',to_jsonb(p),'order',h.generation::text,'replay_time',h.created_at,
 'object_version',(select jsonb_build_object('id',o.id,'updated_at',o.updated_at,'metadata',o.metadata,'owner',o.owner_id) from storage.objects o where o.bucket_id='world-drive-sources' and o.name=p.source_path),
 'road',jsonb_build_object('id',r.id,'drive_id',p.local_drive_id,'direction_key',r.direction_key,'processing_version',r.processing_version,
 'sections',(select jsonb_agg(jsonb_build_object('section_key',s.section_key,'section_order',s.section_order,'distance_meters',s.distance_meters::text,'geometry',extensions.ST_AsGeoJSON(s.geometry,17)::jsonb) order by s.section_order) from public.world_validated_road_sections s where s.validated_road_id=r.id)))
 order by h.generation),'[]'::jsonb) into data
 from public.world_validated_roads r join public.world_publishes p on p.id=r.publish_id
 join public.world_active_world_generations h on h.source_publish_id=p.id where r.user_id<>v;
 if octet_length(data::text)>2097152 or exists(select 1 from jsonb_array_elements(data) e where
 e->'object_version'='null'::jsonb or (e->'object_version'->>'owner') is distinct from (e->'source'->>'user_id'))
 then return jsonb_build_object('state','blocked_planet');end if;
 return jsonb_build_object('state','rebuild','generation',g::text,'sources',data,
 'fingerprint',encode(extensions.digest(g::text||data::text,'sha256'),'hex'));
end;$$;
revoke all on function public.account_deletion_planet_context(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_planet_context(uuid,uuid) to service_role;

create function public.account_deletion_planet_commit(p_id uuid,p_lease uuid,p_fingerprint text,p_traces jsonb) returns text
language plpgsql security definer set search_path='' set extra_float_digits=3 as $$
declare c jsonb;v uuid;g bigint;t jsonb;r public.world_validated_roads%rowtype;s public.world_validated_road_sections%rowtype;
 prefix float8;finish float8;a float8;b float8;part record;
begin
 c:=public.account_deletion_planet_context(p_id,p_lease);
 if c->>'state'='ready' then return 'ready';end if;
 if c->>'state'<>'rebuild' or c->>'fingerprint' is distinct from p_fingerprint then raise exception 'planet_snapshot_changed';end if;
 if jsonb_typeof(p_traces) is distinct from 'array' or jsonb_array_length(p_traces)>4096 then raise exception 'planet_plan_invalid';end if;
 select owner_id into strict v from public.account_deletion_jobs where id=p_id;
 g:=(c->>'generation')::bigint;
 if exists(select 1 from jsonb_array_elements(p_traces) e group by e->>'id' having count(*)>1) then raise exception 'duplicate_plan_trace';end if;
 for t in select * from jsonb_array_elements(p_traces) loop
  select * into strict r from public.world_validated_roads where id=(t->>'validatedRoadId')::uuid;
  select * into strict s from public.world_validated_road_sections where validated_road_id=r.id and section_key=t->>'matchedSectionId';
  if r.user_id=v or not exists(select 1 from jsonb_array_elements(c->'sources') e where e->'source'->>'id'=t->>'sourcePublishId' and e->'road'->>'id'=r.id::text and e->'source'->>'local_drive_id'=t->>'sourceDriveId')
  or t->>'directionKey' is distinct from r.direction_key or (t->>'processingVersion')::integer is distinct from r.processing_version
  or coalesce(length(t->>'id'),0)=0 or length(t->>'id')>512
  or (t->>'minLatitude')::float8 is distinct from extensions.ST_YMin(s.geometry::extensions.box3d)
  or (t->>'maxLatitude')::float8 is distinct from extensions.ST_YMax(s.geometry::extensions.box3d)
  or (t->>'minLongitude')::float8 is distinct from extensions.ST_XMin(s.geometry::extensions.box3d)
  or (t->>'maxLongitude')::float8 is distinct from extensions.ST_XMax(s.geometry::extensions.box3d)
  then raise exception 'planet_plan_provenance';end if;
  a:=(t->>'startOffsetMeters')::float8;b:=(t->>'endOffsetMeters')::float8;prefix:=0;
  for part in select distance_meters from public.world_validated_road_sections where validated_road_id=r.id and section_order<s.section_order order by section_order loop prefix:=prefix+part.distance_meters;end loop;
  finish:=prefix+s.distance_meters;
  if a is null or b is null or not(a>=prefix and b<=finish and b-a>=1000 and b<'Infinity'::float8) then raise exception 'planet_plan_interval';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p_traces) a join jsonb_array_elements(p_traces) b on a->>'id'<b->>'id'
 where a->>'validatedRoadId'=b->>'validatedRoadId' and a->>'matchedSectionId'=b->>'matchedSectionId'
 and least((a->>'endOffsetMeters')::float8,(b->>'endOffsetMeters')::float8)-greatest((a->>'startOffsetMeters')::float8,(b->>'startOffsetMeters')::float8)>.01)
 then raise exception 'planet_duplicate_interval';end if;
 -- One transaction: either every replacement is durable, or none is visible.
 perform set_config('driveit.purge_owner',v::text,true);
 insert into public.world_active_world_generations(generation,base_generation,operation_id,operation_reason,drive_score_algorithm_version,validated_road_processing_version,trace_count,created_at)
 values(g+1,g,'account-withdrawal:'||(g+1)::text,'accountDeletion',1,6,jsonb_array_length(p_traces),clock_timestamp());
 update public.world_active_world_traces set active_to_generation=g+1 where active_to_generation is null;
 insert into public.world_active_world_traces(trace_id,active_from_generation,source_publish_id,source_drive_session_id,validated_road_id,matched_section_id,start_offset_meters,end_offset_meters,direction_key,min_latitude,max_latitude,min_longitude,max_longitude,bounds,processing_version,created_at,updated_at)
 select t->>'id',g+1,(t->>'sourcePublishId')::uuid,t->>'sourceDriveId',(t->>'validatedRoadId')::uuid,t->>'matchedSectionId',(t->>'startOffsetMeters')::float8,(t->>'endOffsetMeters')::float8,t->>'directionKey',
 (t->>'minLatitude')::float8,(t->>'maxLatitude')::float8,(t->>'minLongitude')::float8,(t->>'maxLongitude')::float8,
 extensions.ST_MakeEnvelope((t->>'minLongitude')::float8,(t->>'minLatitude')::float8,(t->>'maxLongitude')::float8,(t->>'maxLatitude')::float8,4326),
 (t->>'processingVersion')::integer,(t->>'createdAt')::timestamptz,(t->>'updatedAt')::timestamptz from jsonb_array_elements(p_traces) t;
 update public.world_active_world_state set current_generation=g+1,updated_at=clock_timestamp() where singleton;
 update public.account_deletion_jobs set planet_rebuilt_generation=g+1,state='pending' where id=p_id;
 return 'ready';
end;$$;
revoke all on function public.account_deletion_planet_commit(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.account_deletion_planet_commit(uuid,uuid,text,jsonb) to service_role;

create function public.account_deletion_planet_block(p_id uuid,p_lease uuid) returns void language sql security definer set search_path='' as $$
 update public.account_deletion_jobs set state='blocked_planet' where id=p_id and lease=p_lease and lease_until>clock_timestamp();
$$;
revoke all on function public.account_deletion_planet_block(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_planet_block(uuid,uuid) to service_role;

do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure);
 if position('join public.world_validated_roads other on other.user_id<>v and true where p.user_id=v)' in d)=0 then raise exception 'unexpected_planet_block_contract';end if;
 execute replace(d,'join public.world_validated_roads other on other.user_id<>v and true where p.user_id=v)',
 'join public.world_validated_roads other on other.user_id<>v and true where p.user_id=v)
 and not exists(select 1 from public.account_deletion_jobs j join public.world_active_world_state w on w.singleton where j.id=p_id and j.planet_rebuilt_generation=w.current_generation)');
end;$$;
commit;
