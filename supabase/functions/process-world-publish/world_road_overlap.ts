// Port of Dart WorldRoadOverlapService and WorldIndexMutationPlanner's
// _clipMatchToTrace. Full-section sampling precedes span clipping: trimming
// geometry first changes the 25m sampling phase and is not My World parity.
import { clipActiveCoverage } from "./world_scoring.ts";
export type Point = { latitude: number; longitude: number };
export type Section = { id: string; distanceMeters: number; geometry: Point[] };
export type Road = { id: string; driveId: string; sections: Section[] };
export const overlapRules = Object.freeze({
  resample: 25, tolerance: 15, maxDirection: 30, minConfidence: .65,
  minReported: 100, comparison: 3000, maxRelativeDifference: .2,
  cellDegrees: .0005, clipEpsilon: .01,
});
export type Match = {
  firstDriveId: string; secondDriveId: string;
  firstSectionId: string; secondSectionId: string;
  firstStartOffsetMeters: number; firstEndOffsetMeters: number;
  secondStartOffsetMeters: number; secondEndOffsetMeters: number;
  commonStart: Point; commonEnd: Point; referenceGeometry: Point[];
  commonDistanceMeters: number; directionCompatible: true;
  geometryConfidence: number; comparisonEligible: boolean; ownershipCovered: true;
};
type Sample = { point: Point; offset: number; heading: number };
const radians = (v: number) => v * Math.PI / 180;
const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v));
const modulo = (v: number, divisor: number) => ((v % divisor) + divisor) % divisor;
const angular = (a: number, b: number) => Math.abs(modulo(a - b + 540, 360) - 180);
export function distance(a: Point, b: Point): number {
  const sinLat = Math.sin(radians(b.latitude - a.latitude) / 2);
  const sinLon = Math.sin(radians(b.longitude - a.longitude) / 2);
  return 2 * 6371008.8 * Math.asin(Math.sqrt(clamp(sinLat * sinLat +
    Math.cos(radians(a.latitude)) * Math.cos(radians(b.latitude)) * sinLon * sinLon, 0, 1)));
}
function bearing(a: Point, b: Point): number {
  const lat1 = radians(a.latitude), lat2 = radians(b.latitude);
  const lon = radians(b.longitude - a.longitude);
  return modulo(Math.atan2(Math.sin(lon) * Math.cos(lat2),
    Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(lon)) * 180 / Math.PI + 360, 360);
}
export function sectionLength(section: Section): number {
  let measured = 0;
  for (let i = 1; i < section.geometry.length; i++) {
    const d = distance(section.geometry[i - 1], section.geometry[i]);
    if (Number.isFinite(d) && d > 0) measured += d;
  }
  return Number.isFinite(section.distanceMeters) && section.distanceMeters > 0 ? section.distanceMeters : measured;
}
function samples(section: Section, startOffset: number): Sample[] {
  const geometry = section.geometry;
  if (geometry.length < 2) return [];
  let measured = 0;
  for (let i = 1; i < geometry.length; i++) {
    const d = distance(geometry[i - 1], geometry[i]);
    if (Number.isFinite(d) && d > 0) measured += d;
  }
  if (measured <= 0) return [];
  const length = sectionLength(section);
  const normalized = (offset: number) => startOffset +
    clamp(clamp(offset / measured, 0, 1) * length, 0, length);
  const result: Sample[] = [{ point: geometry[0], offset: normalized(0), heading: bearing(geometry[0], geometry[1]) }];
  let cumulative = 0, next = overlapRules.resample;
  for (let i = 0; i < geometry.length - 1; i++) {
    const a = geometry[i], b = geometry[i + 1], d = distance(a, b);
    if (d <= 0) continue;
    while (next < cumulative + d) {
      const ratio = (next - cumulative) / d;
      result.push({ point: {
        latitude: a.latitude + (b.latitude - a.latitude) * ratio,
        longitude: a.longitude + (b.longitude - a.longitude) * ratio,
      }, offset: normalized(next), heading: bearing(a, b) });
      next += overlapRules.resample;
    }
    cumulative += d;
  }
  if (result[result.length - 1].offset < startOffset + length) {
    result.push({ point: geometry[geometry.length - 1], offset: normalized(cumulative),
      heading: bearing(geometry[geometry.length - 2], geometry[geometry.length - 1]) });
  }
  return result;
}
function roadSamples(road: Road) {
  let offset = 0;
  return road.sections.map((section) => {
    const output = { id: section.id, samples: samples(section, offset) };
    offset += sectionLength(section);
    return output;
  }).filter((section) => section.samples.length >= 2);
}
function bounds(points: Sample[]) {
  const result = { minLat: points[0].point.latitude, maxLat: points[0].point.latitude,
    minLon: points[0].point.longitude, maxLon: points[0].point.longitude };
  for (const s of points.slice(1)) {
    result.minLat = Math.min(result.minLat, s.point.latitude); result.maxLat = Math.max(result.maxLat, s.point.latitude);
    result.minLon = Math.min(result.minLon, s.point.longitude); result.maxLon = Math.max(result.maxLon, s.point.longitude);
  }
  return result;
}
function intersects(a: ReturnType<typeof bounds>, b: ReturnType<typeof bounds>) {
  const lat = overlapRules.tolerance / 111320;
  const lon = overlapRules.tolerance / Math.max(111320 * Math.cos(radians((a.minLat + a.maxLat) / 2)), 1);
  return a.minLat - lat <= b.maxLat && a.maxLat + lat >= b.minLat &&
    a.minLon - lon <= b.maxLon && a.maxLon + lon >= b.minLon;
}
function sampleIndex(points: Sample[]) {
  const buckets = new Map<string, Sample[]>();
  const cell = (p: Point) => [Math.floor(p.latitude / overlapRules.cellDegrees), Math.floor(p.longitude / overlapRules.cellDegrees)];
  for (const s of points) {
    const key = cell(s.point).join(":");
    const bucket = buckets.get(key) ?? []; bucket.push(s); buckets.set(key, bucket);
  }
  return (input: Sample): Sample | null => {
    let closest: Sample | null = null, closestDistance = Infinity;
    const [lat, lon] = cell(input.point);
    for (let y = lat - 1; y <= lat + 1; y++) for (let x = lon - 1; x <= lon + 1; x++) {
      for (const candidate of buckets.get(`${y}:${x}`) ?? []) {
        if (angular(input.heading, candidate.heading) > overlapRules.maxDirection) continue;
        const d = distance(input.point, candidate.point);
        if (d <= overlapRules.tolerance && d < closestDistance) { closest = candidate; closestDistance = d; }
      }
    }
    return closest;
  };
}
type Pair = { first: Sample; second: Sample };
function toMatch(first: Road, second: Road, firstId: string, secondId: string, run: Pair[]): Match | null {
  const a = run[0], b = run[run.length - 1];
  const firstDistance = b.first.offset - a.first.offset, secondDistance = b.second.offset - a.second.offset;
  const common = Math.min(firstDistance, secondDistance);
  if (common < overlapRules.minReported || Math.abs(firstDistance - secondDistance) /
    Math.max(firstDistance, secondDistance, 1) > overlapRules.maxRelativeDifference) return null;
  const meanDistance = run.reduce((s, p) => s + distance(p.first.point, p.second.point), 0) / run.length;
  const agreement = run.reduce((s, p) => s + clamp(1 - angular(p.first.heading, p.second.heading) / 180, 0, 1), 0) / run.length;
  const confidence = clamp((1 - meanDistance / overlapRules.tolerance) * .65 + agreement * .35, 0, 1);
  if (confidence < overlapRules.minConfidence) return null;
  return {
    firstDriveId: first.driveId, secondDriveId: second.driveId, firstSectionId: firstId, secondSectionId: secondId,
    firstStartOffsetMeters: a.first.offset, firstEndOffsetMeters: b.first.offset,
    secondStartOffsetMeters: a.second.offset, secondEndOffsetMeters: b.second.offset,
    commonStart: a.first.point, commonEnd: b.first.point, referenceGeometry: run.map((p) => p.first.point),
    commonDistanceMeters: common, directionCompatible: true, geometryConfidence: confidence,
    comparisonEligible: common >= overlapRules.comparison, ownershipCovered: true,
  };
}
export function findCommonRoads(first: Road, second: Road): Match[] {
  const output: Match[] = [];
  for (const a of roadSamples(first)) for (const b of roadSamples(second)) {
    if (!intersects(bounds(a.samples), bounds(b.samples))) continue;
    const closest = sampleIndex(b.samples), runs: Pair[][] = [];
    let active: Pair[] | null = null;
    for (const sample of a.samples) {
      const candidate = closest(sample);
      const canContinue = candidate && active && candidate.offset + overlapRules.resample >= active[active.length - 1].second.offset;
      if (!candidate || (active && !canContinue)) {
        if (active) runs.push(active);
        active = candidate ? [{ first: sample, second: candidate }] : null;
      } else if (!active) active = [{ first: sample, second: candidate }];
      else active.push({ first: sample, second: candidate });
    }
    if (active) runs.push(active);
    for (const run of runs) { const match = toMatch(first, second, a.id, b.id, run); if (match) output.push(match); }
  }
  return output;
}
export type Trace = {
  id: string; sourcePublishId: string; sourceDriveId: string; validatedRoadId: string;
  matchedSectionId: string; startOffsetMeters: number; endOffsetMeters: number;
  directionKey: string; activeFromGeneration: string; activeToGeneration: string | null;
  processingVersion: number;
};
export type Coverage = {
  trace: Trace; match: Match;
  activeStartOffsetMeters: number; activeEndOffsetMeters: number;
  challengerStartOffsetMeters: number; challengerEndOffsetMeters: number;
  commonDistanceMeters: number; comparisonEligible: boolean;
};
// Same interval interpolation as Dart _clipMatchToTrace. Retain the raw
// geometric match separately; never expose its full span as active coverage.
export function clipMatchToTrace(match: Match, trace: Trace): Coverage | null {
  const clipped = clipActiveCoverage(match, trace.matchedSectionId, trace.startOffsetMeters, trace.endOffsetMeters);
  if (!clipped) return null;
  return { trace, match, activeStartOffsetMeters: clipped.firstStartOffsetMeters,
    activeEndOffsetMeters: clipped.firstEndOffsetMeters,
    challengerStartOffsetMeters: clipped.secondStartOffsetMeters,
    challengerEndOffsetMeters: clipped.secondEndOffsetMeters,
    commonDistanceMeters: clipped.commonDistanceMeters, comparisonEligible: clipped.comparisonEligible };
}
export function analyzeActiveCandidates(challenger: Road, candidates: Trace[], roads: Road[]): Coverage[] {
  const roadById = new Map(roads.map((road) => [road.id, road]));
  const matchesByRoad = new Map<string, Match[]>();
  const output: Coverage[] = [];
  for (const trace of [...candidates].sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0)) {
    const road = roadById.get(trace.validatedRoadId);
    if (!road) throw new Error("candidate_road_missing");
    if (!matchesByRoad.has(road.id)) matchesByRoad.set(road.id, findCommonRoads(road, challenger));
    for (const match of matchesByRoad.get(road.id)!) {
      const coverage = clipMatchToTrace(match, trace); if (coverage) output.push(coverage);
    }
  }
  return output;
}
