begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,aud,role,email) values
 ('a7171717-1717-4171-8171-171717171717','authenticated','authenticated','lobby-a@example.invalid'),
 ('b7171717-1717-4171-8171-171717171717','authenticated','authenticated','lobby-b@example.invalid'),
 ('c7171717-1717-4171-8171-171717171717','authenticated','authenticated','lobby-c@example.invalid');
create temporary table lobby_state(id uuid,invite text,revision bigint,member_color int);
grant all on lobby_state to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','a7171717-1717-4171-8171-171717171717',true);
insert into lobby_state select (j->>'id')::uuid,j->>'inviteCode',(j->>'revision')::bigint,null
 from (select public.phase8_group_command('create') j) c;
select is(public.phase8_group_command('current')->>'phase','lobby','new group is server-authoritative lobby');
select throws_ok($q$select public.phase8_group_command('share_start',(select id from lobby_state),null,null,true)$q$,
 'PT409','ride_not_started','consent cannot start GPS in lobby');
select set_config('request.jwt.claim.sub','b7171717-1717-4171-8171-171717171717',true);
select is(public.phase8_group_command('join',null,(select invite from lobby_state))->>'phase','lobby','joining preserves lobby');
select throws_ok($q$select public.phase8_group_command('start',(select id from lobby_state))$q$,
 '42501','administrator_required','member cannot start ride');
select set_config('request.jwt.claim.sub','a7171717-1717-4171-8171-171717171717',true);
select is(public.phase8_group_command('start',(select id from lobby_state))->>'phase','running','admin starts ride');
update lobby_state set revision=(public.phase8_group_command('current')->>'revision')::bigint;
select is((public.phase8_group_command('start',(select id from lobby_state))->>'revision')::bigint,
 (select revision from lobby_state),'start retry is idempotent');
select is(public.phase8_group_command('current')->'members'->0->>'sharingStatus','off','start never grants GPS consent');
select set_config('request.jwt.claim.sub','b7171717-1717-4171-8171-171717171717',true);
select is(public.phase8_group_command('current')->>'phase','running','peer observes running phase');
update lobby_state set member_color=(public.phase8_group_command('current')->'members'->1->>'colorIndex')::int;
select lives_ok($q$select public.phase8_group_command('share_start',(select id from lobby_state),null,null,true)$q$,'explicit consent allowed after start');
select lives_ok($q$select public.phase8_group_command('leave',(select id from lobby_state))$q$,'member leaves');
select set_config('request.jwt.claim.sub','c7171717-1717-4171-8171-171717171717',true);
select is(public.phase8_group_command('join',null,(select invite from lobby_state))->>'phase','running','late join enters running phase');
select is((public.phase8_group_command('current')->'members'->1->>'colorIndex')::int,
 (select member_color from lobby_state),'vacated color slot reused without collision');
select is((select count(distinct m->>'colorIndex')::int from jsonb_array_elements(public.phase8_group_command('current')->'members') m),2,'active colors unique');
select throws_ok($q$select public.phase8_group_command('end',(select id from lobby_state))$q$,
 '42501','administrator_required','late join cannot end ride');
reset role;
select ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.phase8_group_command(text,uuid,text,uuid,boolean)'::regprocedure),'RPC remains security definer with empty search path');
set local role anon;
select throws_ok($q$select public.phase8_group_command('start',(select id from lobby_state))$q$,'42501',null,'anonymous start denied');
reset role;
select * from finish();
rollback;
