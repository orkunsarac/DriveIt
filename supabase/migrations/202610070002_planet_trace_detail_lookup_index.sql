begin;
-- Detail lookup by the existing opaque viewport identity, without a world scan.
create index if not exists world_active_world_traces_map_id_idx
  on public.world_active_world_traces (md5(trace_id));
commit;
