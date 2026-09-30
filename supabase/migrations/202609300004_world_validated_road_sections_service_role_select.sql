-- The server-only Active World planner reads the validated section geometry.
-- No client role receives access through this grant.
grant select on table public.world_validated_road_sections to service_role;
