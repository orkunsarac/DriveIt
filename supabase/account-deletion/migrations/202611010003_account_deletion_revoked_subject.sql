begin;
-- Auth deletion does not invalidate a JWT signature immediately. Do not retain UID
-- tombstones solely for fencing: verify that the subject still exists in authoritative Auth.
create or replace function public.account_deletion_active(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select p_owner is null or not exists(select 1 from auth.users where id=p_owner)
 or exists(select 1 from public.account_deletion_jobs where owner_id=p_owner and state<>'completed');
$$;
commit;
