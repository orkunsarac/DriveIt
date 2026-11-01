begin;
-- A failing private-only deletion has no Planet footprint. Do not apply the
-- world-size/global fallback merely because an unrelated private job exists.
do $$declare d text;anchor text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure);
 anchor:='if not exists(select 1 from public.account_deletion_jobs where state<>''completed'') then return ''{}''::uuid[];end if;';
 if position(anchor in d)=0 then raise exception 'unexpected_scope_relevance_contract';end if;
 execute replace(d,anchor,'if not exists(select 1 from public.account_deletion_jobs j where j.state<>''completed'' and (
 exists(select 1 from public.world_publishes p where p.user_id=j.owner_id) or exists(select 1 from public.world_validated_roads r where r.user_id=j.owner_id)))
 then return ''{}''::uuid[];end if;');
end;$$;
commit;
