-- Metadata only. Run against both the restored DEV copy and a clean reference
-- with the two bootstrap files and the 22 subsequent migrations applied.
WITH planet AS (
 SELECT c.oid, n.nspname, c.relname, c.relowner, c.relrowsecurity, c.relforcerowsecurity, c.relacl
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('profiles','world_publishes','world_validated_roads','world_validated_road_sections') AND c.relkind='r'
), records(kind, object_name, definition) AS (
 SELECT 'table', relname::text, jsonb_build_object('owner',pg_get_userbyid(relowner),'rls',relrowsecurity,'force_rls',relforcerowsecurity,'acl',relacl)::text FROM planet
 UNION ALL
 SELECT 'column', p.relname||'.'||a.attname, jsonb_build_object('number',a.attnum,'type',format_type(a.atttypid,a.atttypmod),'collation',a.attcollation::regcollation::text,'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated,'acl',a.attacl)::text
 FROM planet p JOIN pg_attribute a ON a.attrelid=p.oid AND a.attnum>0 AND NOT a.attisdropped LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
 UNION ALL
 SELECT 'constraint',p.relname||'.'||c.conname,jsonb_build_object('type',c.contype,'definition',pg_get_constraintdef(c.oid,true),'validated',c.convalidated,'deferrable',c.condeferrable,'deferred',c.condeferred)::text FROM planet p JOIN pg_constraint c ON c.conrelid=p.oid
 UNION ALL
 SELECT 'index',p.relname||'.'||i.relname,jsonb_build_object('definition',pg_get_indexdef(i.oid),'valid',x.indisvalid,'ready',x.indisready)::text FROM planet p JOIN pg_index x ON x.indrelid=p.oid JOIN pg_class i ON i.oid=x.indexrelid
 UNION ALL
 SELECT 'function',p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',jsonb_build_object('definition',replace(pg_get_functiondef(p.oid),E'\r\n',E'\n'),'owner',pg_get_userbyid(p.proowner),'acl',ARRAY(SELECT a::text FROM unnest(coalesce(p.proacl,acldefault('f',p.proowner))) a ORDER BY a::text))::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('attach_world_publish_source','handle_new_user','is_username_available','set_updated_at')
 UNION ALL
 SELECT 'trigger',n.nspname||'.'||c.relname||'.'||t.tgname,jsonb_build_object('definition',pg_get_triggerdef(t.oid,true),'enabled',t.tgenabled)::text FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND ((c.oid IN (SELECT oid FROM planet)) OR (n.nspname='auth' AND c.relname='users' AND t.tgname='on_auth_user_created'))
 UNION ALL
 SELECT 'policy',schemaname||'.'||tablename||'.'||policyname,jsonb_build_object('permissive',permissive,'roles',roles,'command',cmd,'using',qual,'check',with_check)::text FROM pg_policies WHERE (schemaname='public' AND tablename IN (SELECT relname FROM planet)) OR (schemaname='storage' AND tablename='objects' AND policyname='Users can upload own world drive sources')
)
SELECT jsonb_build_object('kind',kind,'object',object_name,'definition',definition)::text FROM records ORDER BY kind, object_name;
