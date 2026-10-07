begin;
-- Same ordered spherical metric/fraction/interpolation as the first read
-- migration, without N PL/pgSQL calls/ST_MakeLine allocations per section.
create or replace function public.world_map_clip_geometry(p_line extensions.geometry,p_start float8,p_end float8)
returns extensions.geometry language sql immutable strict
set search_path=pg_catalog,extensions,pg_temp as $$
with points as (
 select path[1] seq,extensions.ST_X(geom) lon,extensions.ST_Y(geom) lat from extensions.ST_DumpPoints(p_line)
), previous as (
 select *,lag(lon) over(order by seq) x,lag(lat) over(order by seq) y from points
), lengths as (
 select *,case when seq=1 then 0::float8 else 2*6371008.8*asin(sqrt(greatest(0,least(1,
 power(sin(radians(lat-y)/2),2)+cos(radians(y))*cos(radians(lat))*power(sin(radians(lon-x)/2),2))))) end distance from previous
), offsets as (
 select *,sum(distance) over(order by seq rows between unbounded preceding and current row) cumulative from lengths
), total as (select max(cumulative) length from offsets),
segments as (
 select o.*,greatest(0,(p_start*t.length-(cumulative-distance))/distance) lo,
 least(1,(p_end*t.length-(cumulative-distance))/distance) hi,
 row_number() over(order by seq) selected_order
 from offsets o cross join total t where distance>0 and cumulative>p_start*t.length
 and cumulative-distance<p_end*t.length and p_start>=0 and p_end<=1 and p_end>p_start
), clipped as (
 select seq,0 priority,extensions.ST_SetSRID(extensions.ST_MakePoint(x+(lon-x)*lo,y+(lat-y)*lo),4326) point
 from segments where selected_order=1
 union all
 select seq,1,extensions.ST_SetSRID(extensions.ST_MakePoint(x+(lon-x)*hi,y+(lat-y)*hi),4326) from segments
)
select case when count(*)>=2 then extensions.ST_MakeLine(array_agg(point order by seq,priority)) else null end from clipped;
$$;
revoke all on function public.world_map_clip_geometry(extensions.geometry,float8,float8) from public,anon,authenticated;
grant execute on function public.world_map_clip_geometry(extensions.geometry,float8,float8) to service_role;
commit;
