begin;
-- No verified shared-world recomputation contract exists yet. Any second owner's
-- validated road makes cross-contribution independence unproven, even if geometries do not intersect exactly.
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_purge(uuid,uuid)'::regprocedure);
 if position('extensions.ST_Intersects(own.geometry,other.geometry)' in d)=0 then raise exception 'unexpected_purge_contract';end if;
 execute replace(d,'extensions.ST_Intersects(own.geometry,other.geometry)','true');
end;$$;

create table public.account_deletion_events(
 id bigint generated always as identity primary key,
 job_id uuid not null references public.account_deletion_jobs(id) on delete cascade,
 state text not null,occurred_at timestamptz not null default clock_timestamp()
);
alter table public.account_deletion_events enable row level security;
revoke all on public.account_deletion_events from public,anon,authenticated,service_role;
create function public.account_deletion_record_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' or new.state is distinct from old.state then
  insert into public.account_deletion_events(job_id,state) values(new.id,new.state);
 end if;return new;
end;$$;
revoke all on function public.account_deletion_record_event() from public,anon,authenticated,service_role;
create trigger account_deletion_event after insert or update on public.account_deletion_jobs for each row execute function public.account_deletion_record_event();

-- Unlinked random receipts are only for bounded response-loss recovery, not a new personal-data retention exception.
create function public.account_deletion_prune_receipts() returns void language sql security definer set search_path='' as $$
 delete from public.account_deletion_jobs where state='completed' and completed_at<clock_timestamp()-interval '24 hours';
$$;
revoke all on function public.account_deletion_prune_receipts() from public,anon,authenticated;
grant execute on function public.account_deletion_prune_receipts() to service_role;
commit;
