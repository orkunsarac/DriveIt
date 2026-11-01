-- Read-only catalog acceptance. Run only through the pinned disposable runner.
begin read only;
do $$declare f record;n integer:=0;begin
 for f in select p.* from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace
 where ns.nspname='public' and p.proname in('account_deletion_planet_context','account_deletion_planet_commit','account_deletion_planet_block') loop
  n:=n+1;
  if not f.prosecdef or not coalesce(f.proconfig @> array['search_path=""'],false) or pg_get_userbyid(f.proowner)<>'postgres'
  then raise exception 'unsafe_planet_rpc_definition';end if;
  if has_function_privilege('anon',f.oid,'execute') or has_function_privilege('authenticated',f.oid,'execute')
  or not has_function_privilege('service_role',f.oid,'execute') or exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) where grantee=0 and privilege_type='EXECUTE')
  then raise exception 'unsafe_planet_rpc_execute';end if;
 end loop;
 if n<>3 then raise exception 'missing_or_overloaded_planet_rpc';end if;
end;$$;
select 'PASS: 3 Planet RPC definitions and effective role grants';
rollback;
