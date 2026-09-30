-- The Edge Function uses a privileged server client to look up its publish.
-- RLS is bypassed by service_role, but Postgres table privileges are separate.
grant select on table public.world_publishes to service_role;
