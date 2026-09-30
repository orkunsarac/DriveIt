// Server mirror of MyWorldRules, GpsRoutePreprocessor, MapMatchingChunker,
// and MapboxRoadMatchingProvider. Shared fixtures guard these copied constants.
export const rules = Object.freeze({
  sourceSchemaVersion: 1,
  telemetryVersion: 1,
  driveScoreAlgorithmVersion: 1,
  worldRulesVersion: 6,
  validatedRoadProcessingVersion: 3,
  minimumValidDistanceMeters: 5000,
  minimumUsefulPointDistanceMeters: 3,
  maximumPlausiblePointJumpMeters: 500,
  maximumPlausibleGapAverageSpeedMps: 70,
  canonicalRouteAlignmentToleranceMeters: 2,
  mapMatchingMaximumCoordinates: 100,
  mapMatchingChunkOverlap: 3,
  mapMatchingRadiusMeters: 25,
  chunkGeometryMergeToleranceMeters: 15,
  mapMatchingTimeoutMs: 15000,
});

export type Coordinate = { latitude: number; longitude: number };
export type TelemetryPoint = Coordinate & { timestamp: string };
export type Trace = { index: number; points: Coordinate[] };
export type Chunk = { traceIndex: number; chunkIndex: number; points: Coordinate[] };
export type PreprocessingResult = {
  traces: Trace[];
  inputPointCount: number;
  acceptedPointCount: number;
  invalidPointCount: number;
  tooClosePointCount: number;
  jumpSplitCount: number;
  plausibleGapContinuationCount: number;
};
export type MatchedPoint = Coordinate & {
  headingDegrees: number;
  confidence: number | null;
};
export type MatchedSection = {
  id: string;
  geometry: MatchedPoint[];
  distanceMeters: number;
  confidence: number | null;
  sourceTraceIndex: number;
  sourceChunkIndex: number;
};
export type FailureKind =
  | "none" | "missingAccessToken" | "insufficientInput" | "invalidInput"
  | "network" | "timeout" | "authentication" | "rateLimited"
  | "server" | "malformedResponse" | "apiError";
export type MatchingResult = {
  sections: MatchedSection[];
  validDistanceMeters: number;
  status: "validated" | "partiallyValidated" | "failed";
  confidence: number | null;
  directionKey: string;
  averageHeadingDegrees: number | null;
  failureKind: FailureKind;
};

const radians = (degrees: number) => degrees * Math.PI / 180;
export function distanceMeters(a: Coordinate, b: Coordinate): number {
  const lat1 = radians(a.latitude);
  const lat2 = radians(b.latitude);
  const deltaLat = radians(b.latitude - a.latitude);
  const deltaLon = radians(b.longitude - a.longitude);
  const sinLat = Math.sin(deltaLat / 2);
  const sinLon = Math.sin(deltaLon / 2);
  const haversine = sinLat * sinLat +
    Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;
  return 2 * 6371008.8 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, haversine))));
}

export function bearing(a: Coordinate, b: Coordinate): number {
  const lat1 = radians(a.latitude);
  const lat2 = radians(b.latitude);
  const deltaLon = radians(b.longitude - a.longitude);
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

function timestampMicros(value: string): number {
  const match = /^(.*?)(?:\.(\d+))?(Z|[+-]\d\d:\d\d)$/.exec(value);
  if (!match) return Number.NaN;
  const seconds = Date.parse(match[1] + match[3]);
  if (!Number.isFinite(seconds)) return Number.NaN;
  return seconds * 1000 + Number((match[2] ?? "").padEnd(6, "0").slice(0, 6));
}

function valid(point: Coordinate): boolean {
  return Number.isFinite(point.latitude) && Number.isFinite(point.longitude) &&
    point.latitude >= -90 && point.latitude <= 90 &&
    point.longitude >= -180 && point.longitude <= 180;
}

export function preprocess(
  route: Coordinate[],
  telemetry: TelemetryPoint[] = [],
): PreprocessingResult {
  const traces: Trace[] = [];
  let current: Coordinate[] = [];
  let invalid = 0;
  let tooClose = 0;
  let jumpSplits = 0;
  let accepted = 0;
  let plausibleGaps = 0;
  let previousAcceptedRouteIndex: number | null = null;
  const aligned: (TelemetryPoint | null)[] = Array(route.length).fill(null);
  if (telemetry.length) {
    let telemetryIndex = 0;
    for (let routeIndex = 0; routeIndex < route.length; routeIndex++) {
      while (telemetryIndex < telemetry.length) {
        const candidate = telemetry[telemetryIndex++];
        if (distanceMeters(route[routeIndex], candidate) <=
          rules.canonicalRouteAlignmentToleranceMeters) {
          aligned[routeIndex] = candidate;
          break;
        }
      }
    }
  }
  function closeTrace() {
    if (current.length >= 2) traces.push({ index: traces.length, points: current });
    current = [];
  }
  for (let routeIndex = 0; routeIndex < route.length; routeIndex++) {
    const point = route[routeIndex];
    if (!valid(point)) {
      invalid++;
      closeTrace();
      continue;
    }
    const candidate = { latitude: point.latitude, longitude: point.longitude };
    if (!current.length) {
      current.push(candidate);
      accepted++;
      previousAcceptedRouteIndex = routeIndex;
      continue;
    }
    const distance = distanceMeters(current[current.length - 1], candidate);
    if (distance < rules.minimumUsefulPointDistanceMeters) {
      tooClose++;
      continue;
    }
    if (distance > rules.maximumPlausiblePointJumpMeters) {
      const previous = previousAcceptedRouteIndex === null
        ? null : aligned[previousAcceptedRouteIndex];
      const next = aligned[routeIndex];
      const elapsed = previous && next
        ? (timestampMicros(next.timestamp) - timestampMicros(previous.timestamp)) / 1e6
        : Number.NaN;
      const speed = distance / elapsed;
      if (elapsed > 0 && Number.isFinite(elapsed) &&
        Number.isFinite(speed) &&
        speed <= rules.maximumPlausibleGapAverageSpeedMps) {
        plausibleGaps++;
      } else {
        jumpSplits++;
        closeTrace();
      }
    }
    current.push(candidate);
    accepted++;
    previousAcceptedRouteIndex = routeIndex;
  }
  closeTrace();
  return {
    traces, inputPointCount: route.length, acceptedPointCount: accepted,
    invalidPointCount: invalid, tooClosePointCount: tooClose,
    jumpSplitCount: jumpSplits, plausibleGapContinuationCount: plausibleGaps,
  };
}

export function chunk(traces: Trace[]): Chunk[] {
  const chunks: Chunk[] = [];
  for (const trace of traces) {
    let start = 0;
    let chunkIndex = 0;
    while (start < trace.points.length) {
      const end = Math.max(0, Math.min(
        start + rules.mapMatchingMaximumCoordinates, trace.points.length,
      ));
      const points = trace.points.slice(start, end);
      if (points.length >= 2) {
        chunks.push({ traceIndex: trace.index, chunkIndex: chunkIndex++, points });
      }
      if (end === trace.points.length) break;
      start = end - rules.mapMatchingChunkOverlap;
    }
  }
  return chunks;
}

export function retryable(kind: FailureKind): boolean {
  return ["missingAccessToken", "network", "timeout", "rateLimited", "server"]
    .includes(kind);
}

function httpFailure(status: number): FailureKind {
  if (status >= 200 && status < 300) return "none";
  if (status === 401 || status === 403) return "authentication";
  if (status === 429) return "rateLimited";
  if (status >= 500) return "server";
  return "invalidInput";
}

export type MapboxTransport = (
  uri: string, formBody: URLSearchParams, timeoutMs: number,
) => Promise<{ status: number; body: string }>;

function geometryDistance(points: Coordinate[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) total += distanceMeters(points[i - 1], points[i]);
  return total;
}

function overlapLength(previous: MatchedPoint[], incoming: MatchedPoint[]): number {
  const maximum = Math.min(
    rules.mapMatchingChunkOverlap * 8, previous.length, incoming.length,
  );
  for (let count = maximum; count >= 1; count--) {
    let matches = true;
    for (let i = 0; i < count; i++) {
      if (distanceMeters(previous[previous.length - count + i], incoming[i]) >
        rules.chunkGeometryMergeToleranceMeters) {
        matches = false;
        break;
      }
    }
    if (matches) return count;
  }
  return 0;
}

function weightedPair(a: MatchedSection, b: MatchedSection): number | null {
  if (a.confidence === null) return b.confidence;
  if (b.confidence === null) return a.confidence;
  const total = a.distanceMeters + b.distanceMeters;
  return total <= 0 ? null :
    (a.confidence * a.distanceMeters + b.confidence * b.distanceMeters) / total;
}

function appendOrMerge(sections: MatchedSection[], incoming: MatchedSection) {
  const previous = sections[sections.length - 1];
  if (!previous || previous.sourceTraceIndex !== incoming.sourceTraceIndex ||
    incoming.sourceChunkIndex !== previous.sourceChunkIndex + 1) {
    sections.push(incoming);
    return;
  }
  const overlap = overlapLength(previous.geometry, incoming.geometry);
  if (!overlap) {
    sections.push(incoming);
    return;
  }
  const geometry = [...previous.geometry, ...incoming.geometry.slice(overlap)];
  sections[sections.length - 1] = {
    id: previous.id, geometry, distanceMeters: geometryDistance(geometry),
    confidence: weightedPair(previous, incoming),
    sourceTraceIndex: previous.sourceTraceIndex,
    sourceChunkIndex: incoming.sourceChunkIndex,
  };
}

function parseSections(body: string, chunk: Chunk):
  { sections: MatchedSection[]; kind: FailureKind } {
  let decoded: Record<string, unknown>;
  try {
    decoded = JSON.parse(body);
    if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) {
      return { sections: [], kind: "malformedResponse" };
    }
  } catch {
    return { sections: [], kind: "malformedResponse" };
  }
  if ((decoded.code ?? "") !== "Ok") return { sections: [], kind: "apiError" };
  const matchings = Array.isArray(decoded.matchings) ? decoded.matchings : [];
  const sections: MatchedSection[] = [];
  try {
    for (let m = 0; m < matchings.length; m++) {
      const matching = matchings[m];
      const coordinates = matching?.geometry?.coordinates;
      if (!Array.isArray(coordinates)) continue;
      const parsed = coordinates.filter((c: unknown) =>
        Array.isArray(c) && c.length >= 2).map((c: number[]) => {
          if (typeof c[0] !== "number" || typeof c[1] !== "number") {
            throw new TypeError("Invalid Mapbox coordinate");
          }
          return { longitude: c[0], latitude: c[1] };
        });
      if (parsed.length < 2) continue;
      const confidence = typeof matching.confidence === "number"
        ? matching.confidence as number : null;
      const geometry: MatchedPoint[] = parsed.map((point: Coordinate, i: number) => {
        const neighbor = i < parsed.length - 1 ? parsed[i + 1] : parsed[i - 1];
        const heading = i < parsed.length - 1
          ? bearing(point, neighbor) : bearing(neighbor, point);
        return { ...point, headingDegrees: heading, confidence };
      });
      sections.push({
        id: `t${chunk.traceIndex}:c${chunk.chunkIndex}:m${m}`,
        geometry, distanceMeters: geometryDistance(geometry), confidence,
        sourceTraceIndex: chunk.traceIndex,
        sourceChunkIndex: chunk.chunkIndex,
      });
    }
  } catch {
    return { sections: [], kind: "malformedResponse" };
  }
  return { sections, kind: sections.length ? "none" : "apiError" };
}

function weightedConfidence(sections: MatchedSection[]): number | null {
  let weighted = 0;
  let distance = 0;
  for (const section of sections) {
    if (section.confidence === null) continue;
    weighted += section.confidence * section.distanceMeters;
    distance += section.distanceMeters;
  }
  return distance > 0 ? weighted / distance : null;
}

function directionKey(sections: MatchedSection[]): string {
  const first = sections[0].geometry[0];
  const last = sections[sections.length - 1].geometry.at(-1)!;
  const key = (point: Coordinate) =>
    `${point.latitude.toFixed(5)},${point.longitude.toFixed(5)}`;
  return `${key(first)}>${key(last)}`;
}

function averageHeading(sections: MatchedSection[]): number | null {
  const headings = sections.flatMap((section) => section.geometry.map(
    (point) => point.headingDegrees,
  ));
  if (!headings.length) return null;
  let x = 0;
  let y = 0;
  for (const heading of headings) {
    x += Math.cos(radians(heading));
    y += Math.sin(radians(heading));
  }
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

export async function matchRoad(
  route: Coordinate[],
  telemetry: TelemetryPoint[],
  token: string,
  transport: MapboxTransport,
): Promise<MatchingResult> {
  if (!token.trim()) return failure("missingAccessToken");
  const cleaned = preprocess(route, telemetry);
  const chunks = chunk(cleaned.traces);
  if (!chunks.length) return failure("insufficientInput");
  const sections: MatchedSection[] = [];
  let failureKind: FailureKind = "none";
  let unmatchedChunks = 0;
  for (const current of chunks) {
    const coordinates = current.points.map((p) => `${p.longitude},${p.latitude}`).join(";");
    const radiuses = Array(current.points.length)
      .fill(rules.mapMatchingRadiusMeters.toFixed(0)).join(";");
    const form = new URLSearchParams({
      coordinates, geometries: "geojson", overview: "full",
      steps: "false", tidy: "true", radiuses,
    });
    let response: { sections: MatchedSection[]; kind: FailureKind };
    try {
      const http = await transport(
        `https://api.mapbox.com/matching/v5/mapbox/driving?access_token=${encodeURIComponent(token)}`,
        form, rules.mapMatchingTimeoutMs,
      );
      const kind = httpFailure(http.status);
      response = kind === "none" ? parseSections(http.body, current) :
        { sections: [], kind };
    } catch (error) {
      response = {
        sections: [],
        kind: error instanceof DOMException && error.name === "TimeoutError"
          ? "timeout" : "network",
      };
    }
    if (!response.sections.length) {
      unmatchedChunks++;
      if (failureKind === "none" || retryable(response.kind)) failureKind = response.kind;
      if (response.kind === "authentication" || retryable(response.kind)) break;
      continue;
    }
    for (const section of response.sections) appendOrMerge(sections, section);
  }
  if (!sections.length) return failure(failureKind === "none" ? "apiError" : failureKind);
  const validDistanceMeters = sections.reduce((sum, section) => sum + section.distanceMeters, 0);
  return {
    sections, validDistanceMeters,
    status: unmatchedChunks > 0 || sections.length > cleaned.traces.length
      ? "partiallyValidated" : "validated",
    confidence: weightedConfidence(sections),
    directionKey: directionKey(sections),
    averageHeadingDegrees: averageHeading(sections),
    failureKind,
  };
}

function failure(kind: FailureKind): MatchingResult {
  return {
    sections: [], validDistanceMeters: 0, status: "failed",
    confidence: null, directionKey: "", averageHeadingDegrees: null,
    failureKind: kind,
  };
}
