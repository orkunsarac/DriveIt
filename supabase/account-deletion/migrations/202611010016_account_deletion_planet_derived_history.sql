begin;
-- Historical survivor intervals may have been split by the withdrawing source.
-- They are derived index versions, not canonical drives. Rebuild the entire
-- bounded index atomically, retaining no old geometry/boundaries influenced by A.
do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 anchor:='update public.world_active_world_traces set active_to_generation=g+1 where active_to_generation is null;';
 if position(anchor in d)=0 then raise exception 'unexpected_plan_retirement_contract';end if;
 execute replace(d,anchor,'delete from public.world_active_world_traces;');
end;$$;
commit;
