-- Preserve the canonical road-processing version on newly replayed generations.
begin;
do $$
declare definition text; old_value text := '''accountDeletion'',1,6,jsonb_array_length';
begin
 definition := pg_get_functiondef('public.account_deletion_planet_commit(uuid,uuid,text,jsonb)'::regprocedure);
 if (length(definition)-length(replace(definition,old_value,'')))/length(old_value) <> 1 then
  raise exception 'unexpected_deletion_generation_version_contract';
 end if;
 execute replace(definition,old_value,'''accountDeletion'',1,3,jsonb_array_length');
end;
$$;
commit;
