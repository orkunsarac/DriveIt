begin;
-- Longitude boxes are conservative in the map's ordinary latitude/domain.
-- Polar/dateline/invalid geometry cannot establish a local influence proof:
-- retain global read fencing in those exceptional datasets instead of guessing.
do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure);
 anchor:='declare result uuid[];';
 if position(anchor in d)=0 then raise exception 'unexpected_scope_domain_contract';end if;
 d:=replace(d,'begin
 if exists','begin
 if exists(select 1 from public.account_deletion_jobs where state<>''completed'') and exists(
 select 1 from public.world_validated_roads where extensions.ST_IsEmpty(geometry) or not extensions.ST_IsValid(geometry)
 or extensions.ST_XMax(geometry::extensions.box3d)>179.98 or extensions.ST_XMin(geometry::extensions.box3d)<-179.98
 or extensions.ST_YMax(geometry::extensions.box3d)>85 or extensions.ST_YMin(geometry::extensions.box3d)<-85)
 then return array(select id from public.world_validated_roads);end if;
 if exists');
 execute d;
end;$$;
commit;
