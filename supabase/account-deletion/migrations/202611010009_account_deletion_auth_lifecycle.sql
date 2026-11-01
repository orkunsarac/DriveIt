begin;
-- Transient authoritative metadata for erasure only; cleared in the same transaction as the completion ACK.
alter table public.account_deletion_jobs add column owner_email text;
create function public.account_deletion_capture_subject() returns trigger language plpgsql security definer set search_path='' as $$
begin
 select email into new.owner_email from auth.users where id=new.owner_id;
 if new.owner_email is null then raise exception 'subject_metadata_missing';end if;
 return new;
end;$$;
revoke all on function public.account_deletion_capture_subject() from public,anon,authenticated,service_role;
create trigger account_deletion_subject before insert on public.account_deletion_jobs for each row execute function public.account_deletion_capture_subject();
update public.account_deletion_jobs j set owner_email=u.email from auth.users u where u.id=j.owner_id and j.state<>'completed';

-- Auth hard-delete does not itself promise erasure of audit payloads.
-- Preserve a different actor's log, remove only the deleting subject's traits/identity.
create function public.account_deletion_erase_auth_residue(p_owner uuid,p_email text) returns void
language plpgsql security definer set search_path='' as $$
declare r record;
begin
 if p_owner is null or p_email is null or exists(select 1 from auth.users where id=p_owner) then raise exception 'auth_erasure_precondition';end if;
 for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid
 where n.nspname='auth' and c.relkind='r' and a.attname='user_id' and a.attnum>0 and not a.attisdropped loop
  execute format('delete from auth.%I where user_id::text=$1',r.relname) using p_owner::text;
 end loop;
 delete from auth.audit_log_entries where payload->>'actor_id'=p_owner::text
 and coalesce(payload->'traits'->>'user_id',p_owner::text)=p_owner::text;
 update auth.audit_log_entries set payload=((payload::jsonb)-'actor_id'-'actor_username'-'actor_name'-'actor_via_sso')::json,ip_address=''
 where payload->>'actor_id'=p_owner::text;
 update auth.audit_log_entries set payload=((payload::jsonb)-'traits')::json where payload->'traits'->>'user_id'=p_owner::text;
 -- Unknown payload shapes are not silently retained under a new exception.
 if exists(select 1 from auth.audit_log_entries a where exists(
 select 1 from jsonb_path_query(a.payload::jsonb,'$.** ? (@.type() == "string")') value
 where lower(value#>>'{}') in(lower(p_owner::text),lower(p_email))))
 then raise exception 'auth_audit_dependency_requires_review';end if;
end;$$;
revoke all on function public.account_deletion_erase_auth_residue(uuid,text) from public,anon,authenticated,service_role;
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_complete(uuid,uuid)'::regprocedure);
 if position('declare v uuid;begin' in d)=0 then raise exception 'unexpected_completion_contract';end if;
 d:=replace(d,'declare v uuid;begin','declare v uuid;v_email text;begin');
 d:=replace(d,'select owner_id into v','select owner_id,owner_email into v,v_email');
 d:=replace(d,'update public.account_deletion_jobs set state=''completed'',owner_id=null,',
 'perform public.account_deletion_erase_auth_residue(v,v_email);
 update public.account_deletion_jobs set state=''completed'',owner_id=null,owner_email=null,');
 execute d;
end;$$;
commit;
