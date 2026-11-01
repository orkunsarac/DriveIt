begin;
-- Validate both the withdrawing and surviving sides before any early return.
do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure);
 anchor:='select current_generation into strict g from public.world_active_world_state where singleton for update;';
 if position(anchor in d)=0 then raise exception 'unexpected_planet_context_lock';end if;
 execute replace(d,anchor,anchor||'
 if exists(select 1 from public.world_validated_roads road join public.world_publishes publication on publication.id=road.publish_id where road.user_id<>publication.user_id)
 or exists(select 1 from public.world_active_world_traces trace join public.world_validated_roads road on road.id=trace.validated_road_id
 join public.world_publishes publication on publication.id=trace.source_publish_id
 where road.publish_id<>publication.id or road.user_id<>publication.user_id or trace.source_drive_session_id<>publication.local_drive_id)
 then return jsonb_build_object(''state'',''blocked_planet'');end if;');
end;$$;
commit;
