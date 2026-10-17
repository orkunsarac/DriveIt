-- Forward-only fix: LEFT memberships rejoin with a new identity and no grants.
-- Banned memberships remain denied. Existing migrations are unchanged.
begin;
create or replace function public.phase8_group_command(
  p_action text,
  p_group_id uuid default null,
  p_invite_code text default null,
  p_member_id uuid default null,
  p_consent boolean default false
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  g public.phase8_groups%rowtype;
  m public.phase8_group_memberships%rowtype;
  v_invite text;
  v_expired_group uuid;
  v_active_group uuid;
  v_expired_publishers integer := 0;
  v_now timestamptz := clock_timestamp();
  v_snapshot jsonb;
begin
  if v_actor is null then raise exception using errcode='42501',message='account_required'; end if;
  if p_action not in ('current','create','join','extend','leave','ban','end','share_start','share_pause','share_stop','share_heartbeat','start') then
    raise exception using errcode='22023',message='action_invalid';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text,0));
  select group_id into v_active_group from public.phase8_group_memberships where account_id=v_actor and state='active' limit 1;
  update public.phase8_groups gg set status='expired',ride_phase='ended',generation=generation+1,revision=revision+1
    where gg.id=v_active_group
      and gg.status='active' and gg.expires_at<=v_now returning id into v_expired_group;
  if v_expired_group is not null then
    update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null
      where group_id=v_expired_group and state='active';
  elsif v_active_group is not null then
    perform 1 from public.phase8_groups where id=v_active_group for update;
    update public.phase8_group_memberships set sharing_state='paused',publication_id=null,publisher_expires_at=null,
      last_sequence=0,last_sample_at=null
      where group_id=v_active_group and state='active' and sharing_state='sharing'
        and (publisher_expires_at is null or publisher_expires_at<=v_now);
    get diagnostics v_expired_publishers = row_count;
    if v_expired_publishers>0 then
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=v_active_group;
    end if;
  end if;
  update public.phase8_groups set status='expired',ride_phase='ended',generation=generation+1,revision=revision+1
    where status='active' and expires_at<=v_now;
  update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null
    where state='active' and group_id in (select id from public.phase8_groups where status='expired' and expires_at<=v_now);
  select mm.* into m
  from public.phase8_group_memberships mm join public.phase8_groups gg on gg.id=mm.group_id
  where mm.account_id=v_actor and mm.state='active' and gg.status='active'
    and gg.expires_at>v_now limit 1;
  if m.id is not null then select * into g from public.phase8_groups where id=m.group_id; end if;

  if p_action='current' then
    if g.id is null then return null; end if;
  elsif p_action='create' then
    if m.id is not null then p_action := 'current';
    else
      v_invite := lower(gen_random_uuid()::text);
      insert into public.phase8_groups(administrator_id,invite_code,invite_hash)
        values(v_actor,v_invite::uuid,extensions.digest(convert_to(v_invite,'UTF8'),'sha256')) returning * into g;
      insert into public.phase8_group_memberships(group_id,account_id,role,join_order,color_index)
        values(g.id,v_actor,'administrator',0,0) returning * into m;
    end if;
  elsif p_action='join' then
    if p_invite_code is null or p_invite_code !~* '^[0-9a-f-]{36}$' then
      raise exception using errcode='22023',message='invalid_invite';
    end if;
    select * into g from public.phase8_groups where invite_hash=extensions.digest(convert_to(lower(p_invite_code),'UTF8'),'sha256') for update;
    if not found or g.status<>'active' or g.expires_at<=v_now then
      raise exception using errcode='P0002',message='invite_unavailable';
    end if;
    if m.id is not null and m.group_id<>g.id then raise exception using errcode='PT409',message='already_in_group'; end if;
    if exists(select 1 from public.phase8_group_memberships where group_id=g.id and account_id=v_actor and state='banned') then
      raise exception using errcode='42501',message='membership_banned';
    end if;
    if not exists(select 1 from public.phase8_group_memberships where group_id=g.id and state='active' and account_id=v_actor) then
      if (select count(*) from public.phase8_group_memberships where group_id=g.id and state='active')>=10 then
        raise exception using errcode='PT409',message='group_full';
      end if;
      insert into public.phase8_group_memberships(group_id,account_id,role,join_order,color_index)
        values(g.id,v_actor,'member',g.next_join_order,
          (select slot from generate_series(0,9) slot where not exists(
            select 1 from public.phase8_group_memberships used
            where used.group_id=g.id and used.state='active' and used.color_index=slot
          ) order by slot limit 1))
        on conflict (group_id,account_id) do update set
          id=gen_random_uuid(),state='active',role='member',
          joined_at=v_now,join_order=excluded.join_order,color_index=excluded.color_index,
          sharing_state='off',publication_id=null,publisher_expires_at=null,
          last_sequence=0,last_sample_at=null
        where phase8_group_memberships.state='left'
        returning * into m;
      if not found then raise exception using errcode='42501',message='membership_banned'; end if;
      update public.phase8_groups set next_join_order=next_join_order+1,generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    end if;
  else
    if g.id is null or (p_group_id is not null and g.id<>p_group_id) then
      raise exception using errcode='42501',message='membership_required';
    end if;
    select * into g from public.phase8_groups where id=g.id for update;
    select * into m from public.phase8_group_memberships where id=m.id and state='active' for update;
    if not found then raise exception using errcode='42501',message='membership_required'; end if;
    if p_action in ('extend','ban','end','start') and m.role<>'administrator' then
      raise exception using errcode='42501',message='administrator_required';
    end if;
    if p_action='start' then
      if g.ride_phase='lobby' then
        update public.phase8_groups set ride_phase='running',revision=revision+1
          where id=g.id returning * into g;
      end if;
    elsif p_action='extend' then
      if g.extension_count>=2 then raise exception using errcode='PT409',message='extension_limit'; end if;
      update public.phase8_groups set expires_at=expires_at+interval '6 hours',extension_count=extension_count+1,revision=revision+1
        where id=g.id returning * into g;
    elsif p_action='leave' then
      update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null where id=m.id;
      if g.administrator_id=v_actor then
        update public.phase8_group_memberships set role='administrator'
          where id=(select id from public.phase8_group_memberships where group_id=g.id and state='active' and account_id<>v_actor order by join_order limit 1);
      end if;
      update public.phase8_groups set generation=generation+1,revision=revision+1,
        ride_phase=case when (select count(*) from public.phase8_group_memberships where group_id=g.id and state='active')=0 then 'ended' else ride_phase end,
        status=case when (select count(*) from public.phase8_group_memberships where group_id=g.id and state='active')=0 then 'ended' else status end,
        administrator_id=case when g.administrator_id=v_actor then coalesce((select account_id from public.phase8_group_memberships where group_id=g.id and state='active' and account_id<>v_actor order by join_order limit 1),v_actor) else administrator_id end
        where id=g.id returning * into g;
    elsif p_action='ban' then
      if p_member_id is null or p_member_id=m.id then raise exception using errcode='22023',message='member_invalid'; end if;
      update public.phase8_group_memberships set state='banned',sharing_state='off',publication_id=null,publisher_expires_at=null
        where id=p_member_id and group_id=g.id and state='active';
      if not found then raise exception using errcode='P0002',message='member_not_found'; end if;
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    elsif p_action='end' then
      update public.phase8_groups set status='ended',ride_phase='ended',generation=generation+1,revision=revision+1 where id=g.id returning * into g;
      update public.phase8_group_memberships set state='left',sharing_state='off',publication_id=null,publisher_expires_at=null where group_id=g.id and state='active';
    elsif p_action in ('share_start','share_pause','share_stop') then
      if p_action='share_start' and g.ride_phase<>'running' then
        raise exception using errcode='PT409',message='ride_not_started';
      end if;
      if p_action='share_start' and p_consent is distinct from true then
        raise exception using errcode='42501',message='consent_required';
      end if;
      update public.phase8_group_memberships set
        sharing_state=case p_action when 'share_start' then 'sharing' when 'share_pause' then 'paused' else 'off' end,
        publication_id=case when p_action='share_start' then gen_random_uuid() else null end,
        publisher_expires_at=case when p_action='share_start' then v_now+interval '30 seconds' else null end,
        last_sequence=0,last_sample_at=null
        where id=m.id returning * into m;
      update public.phase8_groups set generation=generation+1,revision=revision+1 where id=g.id returning * into g;
    elsif p_action='share_heartbeat' then
      update public.phase8_group_memberships set publisher_expires_at=v_now+interval '30 seconds'
        where id=m.id and sharing_state='sharing' and publication_id is not null and publisher_expires_at>v_now
        returning * into m;
      if not found then raise exception using errcode='42501',message='publication_revoked'; end if;
    end if;
  end if;

  select jsonb_build_object(
    'phase',g.ride_phase,'id',g.id,'createdAt',g.created_at,'observedAt',v_now,'expiresAt',g.expires_at,
    'status',case when g.status='active' and g.expires_at<=v_now then 'expired' else g.status end,
    'extensionCount',g.extension_count,'revision',g.revision,'generation',g.generation,
    'inviteCode',g.invite_code::text,
    'grant',case when p_action='share_start' then jsonb_build_object('membershipId',m.id,'publicationId',m.publication_id,'startedAt',v_now,'generation',g.generation) else null end,
    'members',coalesce((select jsonb_agg(jsonb_build_object(
      'membershipId',mm.id,'accountId',case when mm.account_id=v_actor then v_actor::text else mm.id::text end,
      'displayName',coalesce(u.raw_user_meta_data->>'display_name','DriveIt üyesi'),
      'joinedAt',mm.joined_at,'joinOrder',mm.join_order,'role',mm.role,
      'sharingStatus',case when mm.sharing_state='sharing' and mm.last_sample_at>=v_now-interval '15 seconds' then 'sharing' else mm.sharing_state end,
      'location',null,'colorIndex',mm.color_index
    ) order by mm.join_order) from public.phase8_group_memberships mm join auth.users u on u.id=mm.account_id where mm.group_id=g.id and mm.state='active'),'[]'::jsonb)
  ) into v_snapshot;
  return v_snapshot;
end; $$;

revoke all on function public.phase8_group_command(text,uuid,text,uuid,boolean) from public,anon;
grant execute on function public.phase8_group_command(text,uuid,text,uuid,boolean) to authenticated;
commit;
