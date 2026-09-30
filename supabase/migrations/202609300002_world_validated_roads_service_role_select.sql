-- The Edge Function reads validation results before doing Mapbox work so
-- retries can return the stored result without repeating provider calls.
grant select on table public.world_validated_roads to service_role;
