begin;
alter table public.account_deletion_jobs add column next_attempt_at timestamptz not null default clock_timestamp();
alter table public.account_deletion_jobs add column failures integer not null default 0 check(failures>=0);
create function public.account_deletion_worker_jobs() returns jsonb language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'receipt_hash',receipt_hash)),'[]'::jsonb) from
 (select id,receipt_hash from public.account_deletion_jobs where state in ('pending','purged') and next_attempt_at<=clock_timestamp()
 and (lease_until is null or lease_until<=clock_timestamp()) order by created_at,id limit 1) s;
$$;
revoke all on function public.account_deletion_worker_jobs() from public,anon,authenticated;
grant execute on function public.account_deletion_worker_jobs() to service_role;
create function public.account_deletion_failed(p_id uuid,p_lease uuid) returns void language sql security definer set search_path='' as $$
 update public.account_deletion_jobs set failures=failures+1,next_attempt_at=clock_timestamp()+interval '2 minutes',updated_at=clock_timestamp()
 where id=p_id and lease=p_lease and state<>'completed';
$$;
revoke all on function public.account_deletion_failed(uuid,uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_failed(uuid,uuid) to service_role;
commit;
