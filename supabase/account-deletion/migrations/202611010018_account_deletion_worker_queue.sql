begin;
alter table public.account_deletion_jobs add column phase text not null default 'queued'
 check(phase in('queued','storage','planet','auth','completed','review'));
alter table public.account_deletion_jobs add column processed_units integer not null default 0 check(processed_units>=0);
alter table public.account_deletion_jobs add column total_units integer not null default 0 check(total_units>=0);
alter table public.account_deletion_jobs add column attempts integer not null default 0;
alter table public.account_deletion_jobs add column review_required boolean not null default false;

create function public.account_deletion_worker_claim(p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_deletion_jobs%rowtype;
begin
 if p_lease is null then raise exception 'lease_required';end if;
 select * into j from public.account_deletion_jobs where state in('pending','purged') and not review_required and failures<8
 and next_attempt_at<=clock_timestamp() and (lease_until is null or lease_until<=clock_timestamp())
 order by next_attempt_at,created_at,id for update skip locked limit 1;
 if not found then return jsonb_build_object('state','idle');end if;
 update public.account_deletion_jobs set lease=p_lease,lease_until=clock_timestamp()+interval '120 seconds',attempts=attempts+1,updated_at=clock_timestamp() where id=j.id;
 return jsonb_build_object('state',j.state,'id',j.id,'owner',j.owner_id);
end;$$;
revoke all on function public.account_deletion_worker_claim(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_worker_claim(uuid) to service_role;

create or replace function public.account_deletion_failed(p_id uuid,p_lease uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 update public.account_deletion_jobs set failures=failures+1,
 next_attempt_at=clock_timestamp()+make_interval(secs=>least(3600,120*power(2,least(failures,5)))::integer),
 review_required=failures+1>=8,phase=case when failures+1>=8 then 'review' else phase end,updated_at=clock_timestamp()
 where id=p_id and lease=p_lease and state<>'completed';
end;$$;

create or replace function public.account_deletion_planet_block(p_id uuid,p_lease uuid) returns void
language sql security definer set search_path='' as $$
 update public.account_deletion_jobs set state='blocked_planet',phase='review',review_required=true,updated_at=clock_timestamp()
 where id=p_id and lease=p_lease and lease_until>clock_timestamp();
$$;

create function public.account_deletion_worker_status() returns jsonb
language sql security definer set search_path='' as $$
 select jsonb_build_object('pending',(select count(*) from public.account_deletion_jobs where state<>'completed'),
 'review',(select count(*) from public.account_deletion_jobs where state<>'completed' and review_required),
 'jobs',coalesce((select jsonb_agg(jsonb_build_object('job',id,'state',state,'phase',phase,'done',processed_units,'total',total_units,
 'attempts',attempts,'failures',failures,'review',review_required,'next_attempt_at',next_attempt_at,'leased',coalesce(lease_until>clock_timestamp(),false)))
 from(select * from public.account_deletion_jobs where state<>'completed' order by created_at,id limit 20)s),'[]'::jsonb));
$$;
revoke all on function public.account_deletion_worker_status() from public,anon,authenticated;
grant execute on function public.account_deletion_worker_status() to service_role;

create function public.account_deletion_worker_retry(p_id uuid) returns text
language plpgsql security definer set search_path='' as $$
begin
 update public.account_deletion_jobs set state=case when state='blocked_planet' then 'pending' else state end,
 review_required=false,failures=0,phase=case when state='purged' then 'auth' else 'queued' end,next_attempt_at=clock_timestamp()
 where id=p_id and state<>'completed' and (lease_until is null or lease_until<=clock_timestamp());
 if not found then return 'not_requeued';end if;
 insert into public.account_deletion_events(job_id,state) values(p_id,'review_requeued');return 'requeued';
end;$$;
revoke all on function public.account_deletion_worker_retry(uuid) from public,anon,authenticated;
grant execute on function public.account_deletion_worker_retry(uuid) to service_role;

create function public.account_deletion_progress(p_id uuid,p_lease uuid,p_phase text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_phase not in('storage','planet','auth') then raise exception 'invalid_phase';end if;
 update public.account_deletion_jobs set phase=p_phase,updated_at=clock_timestamp()
 where id=p_id and lease=p_lease and lease_until>clock_timestamp() and state<>'completed';
 if not found then raise exception 'lease_invalid';end if;
end;$$;
revoke all on function public.account_deletion_progress(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.account_deletion_progress(uuid,uuid,text) to service_role;
commit;
