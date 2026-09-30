import type { Coordinate, TelemetryPoint } from "./world_validation.ts";

export type PublishSourceMetadata = {
  id: string;
  local_drive_id: string;
  source_schema_version: number | null;
  telemetry_version: number | null;
  drive_score_algorithm_version: number | null;
  world_rules_version: number;
  raw_route_point_count: number | null;
  telemetry_point_count: number | null;
};

export function sourceMatches(source: unknown, publish: PublishSourceMetadata): source is {
  raw_route: Coordinate[];
  canonical_telemetry: TelemetryPoint[];
} {
  if (!source || typeof source !== "object" || Array.isArray(source)) return false;
  const value = source as Record<string, unknown>;
  if (value.publish_id !== publish.id ||
      value.local_drive_id !== publish.local_drive_id ||
      value.schema_version !== publish.source_schema_version ||
      value.telemetry_version !== publish.telemetry_version ||
      value.drive_score_algorithm_version !== publish.drive_score_algorithm_version ||
      value.world_rules_version !== publish.world_rules_version ||
      typeof value.started_at !== "string" ||
      !Number.isFinite(Date.parse(value.started_at)) ||
      typeof value.ended_at !== "string" ||
      !Number.isFinite(Date.parse(value.ended_at)) ||
      typeof value.recorded_distance_meters !== "number" ||
      !Number.isFinite(value.recorded_distance_meters) ||
      !Array.isArray(value.raw_route) ||
      !Array.isArray(value.canonical_telemetry) ||
      value.raw_route.length < 2 ||
      value.canonical_telemetry.length < 2 ||
      value.raw_route.length !== publish.raw_route_point_count ||
      value.canonical_telemetry.length !== publish.telemetry_point_count) {
    return false;
  }
  const finite = (x: unknown) => typeof x === "number" && Number.isFinite(x);
  if (!value.raw_route.every((p) =>
    p && typeof p === "object" &&
    finite(p.latitude) && finite(p.longitude))) return false;
  if (!value.canonical_telemetry.every((p) =>
    p && typeof p === "object" &&
    finite(p.latitude) && finite(p.longitude) &&
    p.latitude >= -90 && p.latitude <= 90 &&
    p.longitude >= -180 && p.longitude <= 180 &&
    typeof p.timestamp === "string" && Number.isFinite(Date.parse(p.timestamp)) &&
    finite(p.speed_mps) && finite(p.heading_degrees) &&
    finite(p.altitude_meters) && finite(p.accuracy_meters) &&
    finite(p.distance_from_previous_meters) && finite(p.acceleration_mps2))) {
    return false;
  }
  return true;
}
