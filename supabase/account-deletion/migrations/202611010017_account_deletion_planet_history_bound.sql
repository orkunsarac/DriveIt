begin;
-- Keep safeupdate enabled. Delete only versions proven to belong to the
-- captured committed generation, never rows beyond the validated snapshot.
do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 anchor:='delete from public.world_active_world_traces;';
 if position(anchor in d)=0 then raise exception 'unexpected_history_delete_contract';end if;
 execute replace(d,anchor,'delete from public.world_active_world_traces where active_from_generation<=g;');
 d:=pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure);
 anchor:='select current_generation into strict g from public.world_active_world_state where singleton for update;';
 if position(anchor in d)=0 then raise exception 'unexpected_history_snapshot_contract';end if;
 execute replace(d,anchor,anchor||'
 if exists(select 1 from public.world_active_world_traces where active_from_generation>g or active_to_generation>g)
 then return jsonb_build_object(''state'',''blocked_planet'');end if;');
end;$$;
commit;
