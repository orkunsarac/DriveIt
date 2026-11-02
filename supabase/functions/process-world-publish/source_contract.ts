import { type Coordinate, rules } from "./world_validation.ts";

export type CanonicalSourcePoint = Coordinate & {
  timestamp: string;
  speed_mps: number;
  heading_degrees: number;
  altitude_meters: number;
  accuracy_meters: number;
  distance_from_previous_meters: number;
  acceleration_mps2: number;
};
export type PublishedSource = {
  raw_route: Coordinate[];
  canonical_telemetry: CanonicalSourcePoint[];
};

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

export function sourceMatches(
  source: unknown,
  publish: PublishSourceMetadata,
): source is PublishedSource {
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    return false;
  }
  const value = source as Record<string, unknown>;
  if (value.schema_version !== 1 && value.schema_version !== 2) return false;
  if (
    value.schema_version === 1 && (value.score_calculation_mode != null ||
      value.score_calculation_version != null ||
      value.telemetry_reliability != null)
  ) return false;
  if (
    value.publish_id !== publish.id ||
    value.local_drive_id !== publish.local_drive_id ||
    value.schema_version !== publish.source_schema_version ||
    value.telemetry_version !== publish.telemetry_version ||
    value.drive_score_algorithm_version !==
      publish.drive_score_algorithm_version ||
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
    value.canonical_telemetry.length !== publish.telemetry_point_count
  ) {
    return false;
  }
  const finite = (x: unknown) => typeof x === "number" && Number.isFinite(x);
  if (
    !value.raw_route.every((p) =>
      p && typeof p === "object" &&
      finite(p.latitude) && finite(p.longitude)
    )
  ) return false;
  if (
    !value.canonical_telemetry.every((p) =>
      p && typeof p === "object" &&
      finite(p.latitude) && finite(p.longitude) &&
      p.latitude >= -90 && p.latitude <= 90 &&
      p.longitude >= -180 && p.longitude <= 180 &&
      typeof p.timestamp === "string" &&
      Number.isFinite(Date.parse(p.timestamp)) &&
      finite(p.speed_mps) && finite(p.heading_degrees) &&
      finite(p.altitude_meters) && finite(p.accuracy_meters) &&
      finite(p.distance_from_previous_meters) && finite(p.acceleration_mps2)
    )
  ) {
    return false;
  }
  if (value.schema_version === 2) {
    if (!value.raw_route.every((p) => typeof p.break_before === "boolean")) {
      return false;
    }
    if (
      value.telemetry_version !== rules.telemetryVersion ||
      value.world_rules_version !== rules.worldRulesVersion
    ) return false;
    const policy = value.telemetry_reliability as
      | Record<string, unknown>
      | undefined;
    if (
      value.drive_score_algorithm_version !== 1 ||
      value.score_calculation_mode !== "reliable_intervals" ||
      value.score_calculation_version !== 1 || !policy ||
      policy.reliabilityPolicyVersion !== 1 ||
      !Number.isSafeInteger(policy.startedAtMicros) ||
      !Number.isSafeInteger(policy.stopRequestedAtMicros) ||
      Number(policy.stopRequestedAtMicros) <= Number(policy.startedAtMicros)
    ) return false;
    let previous: bigint | undefined;
    for (const raw of value.canonical_telemetry) {
      const p = raw as Record<string, unknown>;
      if (
        typeof p.break_before !== "boolean" ||
        typeof p.acceleration_reliable !== "boolean" ||
        !Number.isSafeInteger(p.gap_duration_micros) ||
        Number(p.gap_duration_micros) < 0 ||
        !["native", "geometry_estimate", "held_estimate", "unavailable"]
          .includes(p.speed_source as string) ||
        typeof p.timestamp_micros !== "string" ||
        !/^\d{1,16}$/.test(p.timestamp_micros) ||
        typeof p.timestamp !== "string" ||
        !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$/.test(p.timestamp)
      ) return false;
      const fraction = (p.timestamp.match(/\.(\d+)Z$/)?.[1] ?? "").padEnd(
        6,
        "0",
      );
      const micros = BigInt(Date.parse(p.timestamp)) * 1000n +
        BigInt(fraction.slice(3) || "0");
      if (
        micros.toString() !== p.timestamp_micros ||
        (previous !== undefined && micros <= previous) ||
        micros < BigInt(policy.startedAtMicros as number) ||
        micros > BigInt(policy.stopRequestedAtMicros as number)
      ) return false;
      previous = micros;
    }
  }
  return true;
}
