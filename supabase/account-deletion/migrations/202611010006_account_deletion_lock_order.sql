begin;
-- Match request's owner->job order. Never hold a job row while waiting for the owner fence.
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure);
 if position('lease_until>clock_timestamp() for update;' in d)=0 then raise exception 'unexpected_purge_lock_contract';end if;
 d:=replace(d,'lease_until>clock_timestamp() for update;','lease_until>clock_timestamp();');
 d:=replace(d,
 'perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''account_delete:''||v::text,0));',
 'perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''account_delete:''||v::text,0));
 perform 1 from public.account_deletion_jobs where id=p_id and owner_id=v and lease=p_lease and lease_until>clock_timestamp() for update;
 if not found then raise exception ''lease_invalid'';end if;');
 execute d;
end;$$;
commit;
