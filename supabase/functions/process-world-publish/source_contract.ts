import { distanceMeters, type Coordinate, rules } from "./world_validation.ts";

export type CanonicalSourcePoint = Coordinate & {
  timestamp: string;
  speed_mps: number;
  heading_degrees: number;
  altitude_meters: number;
  accuracy_meters: number;
  distance_from_previous_meters: number;
  acceleration_mps2: number;
  break_before?: boolean;
  gap_duration_micros?: number;
  speed_source?: string;
  acceleration_reliable?: boolean;
  timestamp_micros?: string;
};
export type PublishedSource = {
  schema_version: number;
  publish_id: string;
  local_drive_id: string;
  telemetry_version: number;
  drive_score_algorithm_version: number;
  world_rules_version: number;
  started_at: string;
  ended_at: string;
  recorded_distance_meters: number;
  score_calculation_mode?: string;
  score_calculation_version?: number;
  telemetry_reliability?: {
    reliabilityPolicyVersion: number;
    startedAtMicros: number;
    stopRequestedAtMicros: number;
  };
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
    if (!value.raw_route.every((p) => typeof p.break_before === "boolean" &&
      p.latitude >= -90 && p.latitude <= 90 &&
      p.longitude >= -180 && p.longitude <= 180)) {
      return false;
    }
    const rawBoundaries = (value.raw_route as Coordinate[]).filter((p) => p.break_before === true);
    const telemetryBoundaries = (value.canonical_telemetry as CanonicalSourcePoint[]).filter(
      (p) => p.break_before === true,
    );
    const hasBoundary = (point: { latitude: number; longitude: number }, candidates: unknown[]) =>
      candidates.some((candidate) => {
        if (!candidate || typeof candidate !== "object") return false;
        const value = candidate as Record<string, unknown>;
        return typeof value.latitude === "number" &&
          typeof value.longitude === "number" &&
          distanceMeters(point, value as Coordinate) <=
            rules.canonicalRouteAlignmentToleranceMeters;
      });
    if (rawBoundaries.some((point) => !hasBoundary(point, telemetryBoundaries)) ||
        telemetryBoundaries.some((point) => !hasBoundary(point, rawBoundaries))) {
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
    const timestampMicros = (timestamp: string): bigint => {
      const fraction = (timestamp.match(/\.(\d+)Z$/)?.[1] ?? "").padEnd(6, "0");
      return BigInt(Date.parse(timestamp)) * 1000n + BigInt(fraction.slice(3) || "0");
    };
    if (timestampMicros(value.started_at).toString() !==
        String(policy.startedAtMicros) ||
        timestampMicros(value.ended_at).toString() !==
        String(policy.stopRequestedAtMicros)) return false;
    let previous: bigint | undefined;
    for (const raw of value.canonical_telemetry) {
      const p = raw as Record<string, unknown>;
      const speed = p.speed_mps as number;
      const heading = p.heading_degrees as number;
      const altitude = p.altitude_meters as number;
      const accuracy = p.accuracy_meters as number;
      const distance = p.distance_from_previous_meters as number;
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
      if (
        speed < 0 || speed > 100 ||
        heading < -1 || heading > 360 ||
        altitude < -1000 || altitude > 10000 ||
        accuracy < 0 || accuracy > 1000 ||
        distance < 0 ||
        !Number.isSafeInteger(p.gap_duration_micros) ||
        Number(p.gap_duration_micros) < 0 ||
        !["native", "geometry_estimate", "held_estimate", "unavailable"]
          .includes(p.speed_source as string)
      ) return false;
      if (typeof p.timestamp_micros !== "string" ||
          !/^\d{1,16}$/.test(p.timestamp_micros)) return false;
      const micros = timestampMicros(p.timestamp);
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
