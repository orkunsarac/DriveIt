-- Forward correction: WorldRules version 6 is not road-processing version 3.
-- Existing applied migration files and historical road data remain unchanged.
begin;
do $$
declare definition text; old_guard text := 'r.processing_version<>6';
begin
 definition := pg_get_functiondef('public.account_deletion_planet_context(uuid,uuid)'::regprocedure);
 if (length(definition)-length(replace(definition,old_guard,'')))/length(old_guard) <> 1
 or position('r.processing_version<>3' in definition)>0 then
  raise exception 'unexpected_deletion_processing_version_contract';
 end if;
 execute replace(definition,old_guard,'r.processing_version<>3');
end;
$$;
commit;
