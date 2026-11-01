begin;
do $$declare d text;tail text;pos integer;begin
 d:=pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 pos:=position('select t->>''id'',g+1' in d);
 if pos=0 then raise exception 'unexpected_plan_insert_contract';end if;
 tail:=substring(d from pos);
 tail:=replace(replace(tail,'t->>','projected->>'),'jsonb_array_elements(p_traces) t;','jsonb_array_elements(p_traces) projected;');
 execute substring(d from 1 for pos-1)||tail;
end;$$;
commit;
