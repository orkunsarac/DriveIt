begin;
create or replace function public.account_deletion_objects(p_id uuid,p_lease uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v uuid;begin
 select owner_id into v from public.account_deletion_jobs where id=p_id and lease=p_lease and lease_until>clock_timestamp();
 if v is null then raise exception 'lease_invalid';end if;
 if exists(select 1 from storage.objects o where
  (split_part(o.name,'/',1)=v::text and ((coalesce(o.owner_id,'')<>'' and o.owner_id<>v::text) or (o.owner is not null and o.owner<>v)))
  or ((o.owner_id=v::text or o.owner=v) and split_part(o.name,'/',1) ~ '^[0-9a-f-]{36}$' and split_part(o.name,'/',1)<>v::text))
 then raise exception 'storage_ownership_conflict';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('bucket',bucket_id,'name',name)) from
 (select bucket_id,name from storage.objects where owner_id=v::text or owner=v or split_part(name,'/',1)=v::text order by bucket_id,name limit 100)s),'[]'::jsonb);
end;$$;
create or replace function public.account_deletion_record_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' or new.state is distinct from old.state then
  insert into public.account_deletion_events(job_id,state) values(new.id,new.state);
 elsif new.failures>old.failures then
  insert into public.account_deletion_events(job_id,state) values(new.id,'retry_required');
 end if;return new;
end;$$;
commit;
