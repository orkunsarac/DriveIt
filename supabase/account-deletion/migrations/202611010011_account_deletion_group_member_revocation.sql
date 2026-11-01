begin;
-- A cached Realtime authorization cannot be recalled instantly. Rotate the
-- surviving group's topic generation when the deleting subject is a member,
-- just as the existing leave/revocation contract does.
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_request(uuid,uuid,text)'::regprocedure);
 if position('-- End administered groups;' in d)=0 then raise exception 'unexpected_group_revocation_contract';end if;
 d:=replace(d,'-- End administered groups;',
 'update public.phase8_groups set generation=generation+1,revision=revision+1
 where administrator_id<>p_owner and status=''active'' and id in
 (select group_id from public.phase8_group_memberships where account_id=p_owner and state=''active'');
 -- End administered groups;');
 execute d;
end;$$;
commit;
