begin;
-- Same spherical segment lengths and coordinate interpolation as the Dart
-- geometry resolver. ST_LineSubstring on planar degrees is not that metric.
create or replace function public.world_map_clip_geometry(p_line extensions.geometry,p_start float8,p_end float8)
returns extensions.geometry language plpgsql immutable strict
set search_path=pg_catalog,extensions,pg_temp as $$
declare n integer:=extensions.ST_NPoints(p_line); total float8; offset_m float8:=0;
 a extensions.geometry; b extensions.geometry; segment float8; lo float8; hi float8;
 points extensions.geometry[]:='{}'; i integer;
begin
 total:=public.world_section_geometry_length_meters(p_line);
 if n<2 or total<=0 or p_start<0 or p_end>1 or p_end<=p_start then return null; end if;
 for i in 2..n loop
   a:=extensions.ST_PointN(p_line,i-1); b:=extensions.ST_PointN(p_line,i);
   segment:=public.world_section_geometry_length_meters(extensions.ST_MakeLine(a,b));
   if segment>0 and offset_m+segment>p_start*total and offset_m<p_end*total then
     lo:=greatest(0,(p_start*total-offset_m)/segment); hi:=least(1,(p_end*total-offset_m)/segment);
     if cardinality(points)=0 then points:=array_append(points,extensions.ST_SetSRID(extensions.ST_MakePoint(
       extensions.ST_X(a)+(extensions.ST_X(b)-extensions.ST_X(a))*lo,
       extensions.ST_Y(a)+(extensions.ST_Y(b)-extensions.ST_Y(a))*lo),4326)); end if;
     points:=array_append(points,extensions.ST_SetSRID(extensions.ST_MakePoint(
       extensions.ST_X(a)+(extensions.ST_X(b)-extensions.ST_X(a))*hi,
       extensions.ST_Y(a)+(extensions.ST_Y(b)-extensions.ST_Y(a))*hi),4326));
   end if;
   offset_m:=offset_m+segment;
 end loop;
 if cardinality(points)<2 then return null; end if;
 return extensions.ST_MakeLine(points);
end $$;
revoke all on function public.world_map_clip_geometry(extensions.geometry,float8,float8) from public,anon,authenticated;
grant execute on function public.world_map_clip_geometry(extensions.geometry,float8,float8) to service_role;

create or replace function public.world_map_section_prefix(p_road uuid,p_order integer)
returns float8 language plpgsql stable security definer
set search_path=pg_catalog,extensions,pg_temp as $$
declare result float8:=0; s record;
begin
 for s in select distance_meters,geometry from public.world_validated_road_sections
   where validated_road_id=p_road and section_order<p_order order by section_order loop
   result:=result+case when s.distance_meters>0 then s.distance_meters else public.world_section_geometry_length_meters(s.geometry) end;
 end loop;
 return result;
end $$;
revoke all on function public.world_map_section_prefix(uuid,integer) from public,anon,authenticated;
grant execute on function public.world_map_section_prefix(uuid,integer) to service_role;

create or replace function public.read_planet_viewport(p_south float8,p_north float8,p_west float8,p_east float8,p_zoom float8)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,extensions,pg_temp set extra_float_digits=3 as $$
declare g bigint; viewport extensions.geometry; box1 extensions.geometry; box2 extensions.geometry;
 span float8; candidates integer; vertices bigint; result jsonb;
begin
 if auth.uid() is null and current_setting('request.jwt.claim.role',true) is distinct from 'service_role' then
   raise exception 'authentication_required' using errcode='42501'; end if;
 if p_south is null or p_north is null or p_west is null or p_east is null or p_zoom is null
   or not(p_south>=-85 and p_north<=85 and p_south<p_north)
   or not(p_west>=-180 and p_west<=180 and p_east>=-180 and p_east<=180)
   or not(p_zoom>=0 and p_zoom<=22) then raise exception 'invalid_viewport' using errcode='22023'; end if;
 select current_generation into strict g from public.world_active_world_state where singleton;
 span:=case when p_east>=p_west then p_east-p_west else 360+p_east-p_west end;
 if p_zoom<10 or p_north-p_south>1 or span>1 or span<=0 then
   return jsonb_build_object('generation',g::text,'state','zoom_in','traces','[]'::jsonb); end if;
 box1:=extensions.ST_MakeEnvelope(p_west,p_south,case when p_west<=p_east then p_east else 180 end,p_north,4326);
 if p_west>p_east then box2:=extensions.ST_MakeEnvelope(-180,p_south,p_east,p_north,4326); end if;
 viewport:=case when box2 is null then box1 else extensions.ST_Collect(box1,box2) end;
 -- Partial current GiST index; bound work BEFORE clipping. No world-wide scan.
 select count(*) into candidates from (select trace_id from public.world_active_world_traces
   where active_to_generation is null and active_from_generation<=g
     and (bounds && box1 or (box2 is not null and bounds && box2)) limit 201) t;
 if candidates>200 then return jsonb_build_object('generation',g::text,'state','zoom_in','traces','[]'::jsonb); end if;
 select coalesce(sum(extensions.ST_NPoints(s.geometry)),0) into vertices
 from public.world_active_world_traces t join public.world_validated_road_sections s
 on s.validated_road_id=t.validated_road_id and s.section_key=t.matched_section_id
 where t.active_to_generation is null and t.active_from_generation<=g
 and (t.bounds && box1 or (box2 is not null and t.bounds && box2));
 if vertices>100000 then return jsonb_build_object('generation',g::text,'state','zoom_in','traces','[]'::jsonb); end if;
 with current_traces as materialized (
   select t.*,s.geometry,s.distance_meters,s.section_order from public.world_active_world_traces t
   join public.world_validated_road_sections s on s.validated_road_id=t.validated_road_id and s.section_key=t.matched_section_id
   where t.active_to_generation is null and t.active_from_generation<=g
   and (t.bounds && box1 or (box2 is not null and t.bounds && box2))
 ), lengths as (
   select t.*,public.world_map_section_prefix(t.validated_road_id,t.section_order) prefix,
     case when t.distance_meters>0 then t.distance_meters else public.world_section_geometry_length_meters(t.geometry) end len
   from current_traces t
 ), clipped as materialized (
   select t.*,public.world_map_clip_geometry(geometry,greatest(0,least(1,(start_offset_meters-prefix)/len)),
     greatest(0,least(1,(end_offset_meters-prefix)/len))) drawing
   from lengths t where len>0
 ) select jsonb_build_object('generation',g::text,'state','ready','traces',coalesce(jsonb_agg(
   jsonb_build_object('id',md5(trace_id),'style_key',md5(source_publish_id::text),
     'distance_meters',(end_offset_meters-start_offset_meters)::text,
     'geometry',extensions.ST_AsGeoJSON(drawing,15)::jsonb) order by trace_id),'[]'::jsonb)) into result
 from clipped where drawing is not null and extensions.ST_Intersects(drawing,viewport);
 if octet_length(result::text)>1048576 then return jsonb_build_object('generation',g::text,'state','zoom_in','traces','[]'::jsonb); end if;
 return result;
end $$;
revoke all on function public.read_planet_viewport(float8,float8,float8,float8,float8) from public,anon;
grant execute on function public.read_planet_viewport(float8,float8,float8,float8,float8) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
