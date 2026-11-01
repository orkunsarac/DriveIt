begin;
-- Forward fix: a/b float8 locals must not collide with JSON interval aliases.
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 if position('jsonb_array_elements(p_traces) a join' in d)=0 then raise exception 'unexpected_plan_interval_contract';end if;
 d:=replace(d,'jsonb_array_elements(p_traces) a join jsonb_array_elements(p_traces) b on a->>''id''<b->>''id''',
 'jsonb_array_elements(p_traces) left_trace join jsonb_array_elements(p_traces) right_trace on left_trace->>''id''<right_trace->>''id''');
 d:=replace(replace(d,'a->>','left_trace->>'),'b->>','right_trace->>');
 execute d;
end;$$;
commit;
