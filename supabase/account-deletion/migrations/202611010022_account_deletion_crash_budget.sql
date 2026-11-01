begin;
alter table public.account_deletion_jobs add column lease_expirations integer not null default 0 check(lease_expirations>=0);
create or replace function public.account_deletion_worker_claim(p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_deletion_jobs%rowtype;
begin
 if p_lease is null then raise exception 'lease_required';end if;
 select * into j from public.account_deletion_jobs where state in('pending','purged') and not review_required and failures<8
 and next_attempt_at<=clock_timestamp() and (lease_until is null or lease_until<=clock_timestamp())
 order by next_attempt_at,created_at,id for update skip locked limit 1;
 if not found then return jsonb_build_object('state','idle');end if;
 if j.lease is not null then
  if j.lease_expirations+1>=8 then
   update public.account_deletion_jobs set lease_expirations=lease_expirations+1,review_required=true,phase='review',lease=null,lease_until=null where id=j.id;
   insert into public.account_deletion_events(job_id,state) values(j.id,'worker_stalled');return jsonb_build_object('state','idle');
  end if;
  update public.account_deletion_jobs set lease_expirations=lease_expirations+1 where id=j.id;
 end if;
 update public.account_deletion_jobs set lease=p_lease,lease_until=clock_timestamp()+interval '120 seconds',attempts=attempts+1,updated_at=clock_timestamp() where id=j.id;
 return jsonb_build_object('state',j.state,'id',j.id,'owner',j.owner_id);
end;$$;
do $$declare d text;begin
 d:=pg_get_functiondef('public.account_deletion_release(uuid,uuid)'::regprocedure);
 if position('set lease=null,lease_until=null' in d)=0 then raise exception 'unexpected_release_contract';end if;
 execute replace(d,'set lease=null,lease_until=null','set lease=null,lease_until=null,lease_expirations=0');
 d:=pg_get_functiondef('public.account_deletion_worker_retry(uuid)'::regprocedure);
 execute replace(d,'review_required=false,failures=0','review_required=false,failures=0,lease_expirations=0');
 d:=pg_get_functiondef('public.account_deletion_worker_status()'::regprocedure);
 execute replace(d,'''attempts'',attempts,','''crashes'',lease_expirations,''attempts'',attempts,');
end;$$;
commit;
