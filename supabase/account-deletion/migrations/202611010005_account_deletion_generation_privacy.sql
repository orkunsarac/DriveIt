begin;
-- Generation ordering may be needed by other records, but the deleting source's original processing time is not.
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure);
 if position('operation_id=''erased-generation:''||generation::text' in d)=0 then raise exception 'unexpected_generation_scrub_contract';end if;
 execute replace(d,'operation_id=''erased-generation:''||generation::text','operation_id=''erased-generation:''||generation::text,created_at=clock_timestamp()');
end;$$;
commit;
