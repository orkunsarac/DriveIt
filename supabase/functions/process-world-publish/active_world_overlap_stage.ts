import { sectionCoordinates, sectionDistanceMeters } from "./validated_section_geojson.ts";
import { analyzeActiveCandidates, type Coverage, type Road, type Trace } from "./world_road_overlap.ts";

export type CandidateSnapshot = { generation: string; isEmpty: boolean; candidates: Trace[]; roads: Road[] };
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const text = (v: unknown): v is string => typeof v === "string" && v.length > 0;
const generation = (v: unknown): v is string => typeof v === "string" && /^(0|[1-9][0-9]*)$/.test(v);
function offset(value: unknown): number {
  const parsed = sectionDistanceMeters(value);
  if (parsed === null || !Number.isFinite(parsed) || parsed < 0) throw new Error("candidate_snapshot_invalid");
  return parsed;
}
export function parseCandidateSnapshot(value: unknown): CandidateSnapshot {
  if (!object(value) || !generation(value.generation) || typeof value.is_empty !== "boolean" ||
    !Array.isArray(value.candidates) || !Array.isArray(value.roads)) throw new Error("candidate_snapshot_invalid");
  const current = BigInt(value.generation);
  const candidates = value.candidates.map((t): Trace => {
    if (!object(t) || ![t.id,t.source_publish_id,t.source_drive_id,t.validated_road_id,t.matched_section_id,t.direction_key].every(text) ||
      !generation(t.active_from_generation) || (t.active_to_generation !== null && !generation(t.active_to_generation)) ||
      !Number.isInteger(t.processing_version)) throw new Error("candidate_snapshot_invalid");
    if (BigInt(t.active_from_generation) > current || t.active_to_generation !== null) {
      throw new Error("candidate_snapshot_inactive_trace");
    }
    const start = offset(t.start_offset_meters), end = offset(t.end_offset_meters);
    if (end <= start) throw new Error("candidate_snapshot_invalid");
    return { id: t.id as string, sourcePublishId: t.source_publish_id as string,
      sourceDriveId: t.source_drive_id as string, validatedRoadId: t.validated_road_id as string,
      matchedSectionId: t.matched_section_id as string, directionKey: t.direction_key as string,
      startOffsetMeters: start, endOffsetMeters: end, activeFromGeneration: t.active_from_generation,
      activeToGeneration: t.active_to_generation as string | null, processingVersion: t.processing_version as number };
  });
  if (new Set(candidates.map((t) => t.id)).size !== candidates.length || (value.is_empty && candidates.length)) {
    throw new Error("candidate_snapshot_invalid");
  }
  const roads = value.roads.map((r): Road => {
    if (!object(r) || !text(r.id) || !text(r.drive_id) || !Array.isArray(r.sections)) throw new Error("candidate_snapshot_invalid");
    let lastOrder = -1;
    return { id: r.id, driveId: r.drive_id, sections: r.sections.map((s) => {
      if (!object(s) || !text(s.section_key) || !Number.isInteger(s.section_order) || (s.section_order as number) <= lastOrder) {
        throw new Error("candidate_snapshot_invalid");
      }
      lastOrder = s.section_order as number;
      const geometry = sectionCoordinates(s.geometry), distanceMeters = sectionDistanceMeters(s.distance_meters);
      if (!geometry || distanceMeters === null) throw new Error("candidate_snapshot_invalid");
      return { id: s.section_key, geometry, distanceMeters };
    }) };
  });
  for (const t of candidates) {
    const r = roads.find((r) => r.id === t.validatedRoadId);
    if (!r || r.driveId !== t.sourceDriveId || !r.sections.some((s) => s.id === t.matchedSectionId)) {
      throw new Error("candidate_snapshot_invalid");
    }
  }
  return { generation: value.generation, isEmpty: value.is_empty, candidates, roads };
}
export type OverlapStageResult = {
  state: "empty_world" | "ownership_processing_not_implemented";
  snapshot: CandidateSnapshot; overlaps: Coverage[];
};
// Read-only intermediate stage. No commit, score, telemetry, Storage or Mapbox.
export function evaluateCandidateSnapshot(challenger: Road, raw: unknown): OverlapStageResult {
  const snapshot = parseCandidateSnapshot(raw);
  return { state: snapshot.isEmpty ? "empty_world" : "ownership_processing_not_implemented", snapshot,
    overlaps: snapshot.isEmpty ? [] : analyzeActiveCandidates(challenger, snapshot.candidates, snapshot.roads) };
}
