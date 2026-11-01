begin;
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_hidden_roads()'::regprocedure);
 if position('declare result uuid[];' in d)=0 then raise exception 'unexpected_scope_budget_contract';end if;
 d:=replace(d,'begin
 if exists','begin
 if not exists(select 1 from public.account_deletion_jobs where state<>''completed'') then return ''{}''::uuid[];end if;
 if (select count(*) from(select 1 from public.world_validated_roads limit 129) bounded)>128 then return null;end if;
 if exists');
 d:=replace(d,'return array(select id from public.world_validated_roads);','return null;');execute d;
 d:=pg_get_functiondef('public.read_planet_trace_detail_context(text)'::regprocedure);
 if position('and t.validated_road_id=any(public.account_deletion_planet_hidden_roads())' in d)=0 then raise exception 'unexpected_detail_scope_contract';end if;
 execute replace(d,'and t.validated_road_id=any(public.account_deletion_planet_hidden_roads())',
 'and coalesce(t.validated_road_id=any(public.account_deletion_planet_hidden_roads()),true)');
end;$$;
commit;
