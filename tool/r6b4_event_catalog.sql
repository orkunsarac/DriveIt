-- Read-only metadata, targeted to the managed RLS event-trigger function.
SELECT jsonb_build_object(
 'event_triggers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',e.evtname,'event',e.evtevent,'enabled',e.evtenabled::text,'tags',e.evttags,'owner',pg_get_userbyid(e.evtowner)) ORDER BY e.evtname),'[]'::jsonb) FROM pg_event_trigger e WHERE e.evtfoid='public.rls_auto_enable()'::regprocedure),
 'dependencies',(SELECT coalesce(jsonb_agg(pg_describe_object(d.classid,d.objid,d.objsubid) ORDER BY pg_describe_object(d.classid,d.objid,d.objsubid)),'[]'::jsonb) FROM pg_depend d WHERE d.refobjid='public.rls_auto_enable()'::regprocedure),
 'function_references',(SELECT coalesce(jsonb_agg(p.oid::regprocedure::text ORDER BY p.oid::regprocedure::text),'[]'::jsonb) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','auth','storage','realtime') AND p.proname<>'rls_auto_enable' AND p.prokind='f' AND position('rls_auto_enable' in pg_get_functiondef(p.oid))>0)
)::text;
