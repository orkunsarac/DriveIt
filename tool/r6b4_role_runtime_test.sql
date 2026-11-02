-- Local isolated stack only. Synthetic Planet rows and all writes roll back.
BEGIN;
INSERT INTO auth.users(id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
VALUES ('00000000-0000-4000-8000-000000000101','authenticated','authenticated','r6b4-geometry@example.invalid','','{}','{}',now(),now());
INSERT INTO public.world_publishes(id,user_id,local_drive_id,started_at,ended_at,distance_meters,world_rules_version)
VALUES ('00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101','r6b4-geometry',now(),now(),1,6);
INSERT INTO public.world_validated_roads(id,publish_id,user_id,provider_id,processing_version,valid_distance_meters,validation_status,direction_key,section_count,geometry)
VALUES ('00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000101','r6b4',3,1,'validated','east',1,extensions.ST_Multi(extensions.ST_GeomFromText('LINESTRING(0 0,0.01 0)',4326)));
INSERT INTO public.world_validated_road_sections(validated_road_id,section_key,section_order,distance_meters,source_trace_index,source_chunk_index,geometry)
VALUES ('00000000-0000-4000-8000-000000000103','r6b4-section',0,0,0,0,extensions.ST_GeomFromText('LINESTRING(0 0,0.01 0)',4326));
SET LOCAL ROLE service_role;
DO $$ DECLARE length_m double precision; BEGIN
 IF NOT has_schema_privilege(current_user,'extensions','USAGE') THEN RAISE EXCEPTION 'extension_schema_unavailable'; END IF;
 BEGIN DELETE FROM public.phase8_drive_leases WHERE false; RAISE EXCEPTION 'lease_delete_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 BEGIN DELETE FROM public.phase8_drive_tombstones WHERE false; RAISE EXCEPTION 'tombstone_delete_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 BEGIN UPDATE public.phase8_drive_tombstones SET owner_id=owner_id WHERE false; RAISE EXCEPTION 'tombstone_update_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 BEGIN PERFORM public.phase8_can_access_staging_object('not-an-object'); RAISE EXCEPTION 'storage_helper_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 BEGIN PERFORM public.phase8_group_command('create',NULL::uuid,NULL::text,NULL::uuid,false); RAISE EXCEPTION 'group_rpc_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 BEGIN PERFORM public.world_section_geometry_length_meters(extensions.ST_GeomFromText('LINESTRING(0 0,0.01 0)',4326)); RAISE EXCEPTION 'length_helper_unexpectedly_allowed'; EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;
 SELECT public.world_map_section_prefix('00000000-0000-4000-8000-000000000103',1) INTO length_m;
 IF length_m IS NULL OR length_m <= 0 THEN RAISE EXCEPTION 'security_definer_geometry_path_failed'; END IF;
END $$;
ROLLBACK;
