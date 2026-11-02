-- Read-only security metadata; no user rows or secret values.
SELECT jsonb_build_object(
  'roles', (SELECT jsonb_agg(jsonb_build_object('object',v.object_name,'privilege',v.privilege,'allowed',CASE WHEN v.kind='table' THEN has_table_privilege('service_role',v.object_name,v.privilege) ELSE has_function_privilege('service_role',v.object_name,v.privilege) END) ORDER BY v.object_name,v.privilege)
    FROM (VALUES
      ('table','public.phase8_drive_leases','DELETE'),
      ('table','public.phase8_drive_tombstones','DELETE'),
      ('table','public.phase8_drive_tombstones','UPDATE'),
      ('function','public.phase8_can_access_staging_object(text)','EXECUTE'),
      ('function','public.phase8_group_command(text,uuid,text,uuid,boolean)','EXECUTE'),
      ('function','public.world_section_geometry_length_meters(extensions.geometry)','EXECUTE')) v(kind,object_name,privilege)),
  'default_acl',(SELECT jsonb_agg(jsonb_build_object('role',pg_get_userbyid(d.defaclrole),'schema',coalesce(n.nspname,'global'),'kind',d.defaclobjtype::text,'acl',d.defaclacl::text) ORDER BY pg_get_userbyid(d.defaclrole),coalesce(n.nspname,'global'),d.defaclobjtype::text) FROM pg_default_acl d LEFT JOIN pg_namespace n ON n.oid=d.defaclnamespace WHERE pg_get_userbyid(d.defaclrole)='postgres'),
  'rls_auto_enable',(SELECT jsonb_build_object('exists',true,'owner',pg_get_userbyid(p.proowner),'security_definer',p.prosecdef,'config',p.proconfig,'return_type',format_type(p.prorettype,NULL),'acl',coalesce(p.proacl,acldefault('f',p.proowner))::text,'definition_hash',md5(replace(pg_get_functiondef(p.oid),E'\r\n',E'\n')),'event_triggers',(SELECT count(*) FROM pg_event_trigger e WHERE e.evtfoid=p.oid),'dependencies',(SELECT count(*) FROM pg_depend d WHERE d.refobjid=p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='rls_auto_enable' AND p.pronargs=0)
)::text;
