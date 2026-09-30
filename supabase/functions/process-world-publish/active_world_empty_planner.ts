// Empty-snapshot port of WorldIndexMutationPlanner. Keep IDs, cumulative
// offsets, section bounds, and the 1 km trace filter in parity with Dart.
export const minimumActiveTraceMeters = 1000;
export const worldRulesVersion = 6;

export type ActiveWorldSection = {
  id: string;
  distanceMeters: number;
  geometry: { latitude: number; longitude: number }[];
};

export type EmptyWorldTrace = {
  id: string;
  sourceDriveSessionId: string;
  validatedRoadId: string;
  matchedSectionId: string;
  startOffsetMeters: number;
  endOffsetMeters: number;
  directionKey: string;
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
  processingVersion: number;
};

export type EmptyWorldPlan = {
  baseGeneration: number;
  generation: number;
  operationId: string;
  operationReason: "recordProcessing";
  sourceDriveSessionId: string;
  driveScoreAlgorithmVersion: number;
  validatedRoadProcessingVersion: number;
  processedDriveSessionIds: string[];
  traces: EmptyWorldTrace[];
};

export function planEmptyWorld(input: {
  generation: number;
  driveScoreAlgorithmVersion: number;
  sourceDriveSessionId: string;
  validatedRoadId: string;
  directionKey: string;
  processingVersion: number;
  sections: ActiveWorldSection[];
}): EmptyWorldPlan {
  let offset = 0;
  const traces: EmptyWorldTrace[] = [];
  for (const section of input.sections) {
    const declared = section.distanceMeters;
    const length = Number.isFinite(declared) && declared > 0
      ? declared
      : geometryLength(section.geometry);
    const start = offset;
    const end = start + length;
    offset = end;
    if (end - start < minimumActiveTraceMeters) continue;
    const bounds = sectionBounds(section.geometry);
    traces.push({
      id: `${input.sourceDriveSessionId}:${input.validatedRoadId}:${section.id}:${start.toFixed(3)}:${end.toFixed(3)}`,
      sourceDriveSessionId: input.sourceDriveSessionId,
      validatedRoadId: input.validatedRoadId,
      matchedSectionId: section.id,
      startOffsetMeters: start,
      endOffsetMeters: end,
      directionKey: input.directionKey,
      ...bounds,
      processingVersion: input.processingVersion,
    });
  }
  traces.sort((first, second) => {
    const firstId = first.matchedSectionId;
    const secondId = second.matchedSectionId;
    const idOrder = firstId < secondId ? -1 : firstId > secondId ? 1 : 0;
    return idOrder || first.startOffsetMeters - second.startOffsetMeters;
  });
  return {
    baseGeneration: input.generation,
    generation: input.generation + 1,
    operationId: `world:${input.sourceDriveSessionId}:v${input.driveScoreAlgorithmVersion}`,
    operationReason: "recordProcessing",
    sourceDriveSessionId: input.sourceDriveSessionId,
    driveScoreAlgorithmVersion: input.driveScoreAlgorithmVersion,
    validatedRoadProcessingVersion: worldRulesVersion,
    processedDriveSessionIds: [input.sourceDriveSessionId],
    traces,
  };
}

function geometryLength(points: ActiveWorldSection["geometry"]): number {
  let length = 0;
  for (let index = 1; index < points.length; index++) {
    length += distanceMeters(points[index - 1], points[index]);
  }
  return length;
}

function distanceMeters(a: { latitude: number; longitude: number }, b: { latitude: number; longitude: number }): number {
  const radians = (value: number) => value * Math.PI / 180;
  const lat1 = radians(a.latitude);
  const lat2 = radians(b.latitude);
  const deltaLat = radians(b.latitude - a.latitude);
  const deltaLon = radians(b.longitude - a.longitude);
  const sinLat = Math.sin(deltaLat / 2);
  const sinLon = Math.sin(deltaLon / 2);
  const haversine = sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;
  return 2 * 6371008.8 * Math.asin(Math.sqrt(Math.max(0, Math.min(1, haversine))));
}

function sectionBounds(points: ActiveWorldSection["geometry"]) {
  if (!points.length) {
    return { minLatitude: 0, maxLatitude: 0, minLongitude: 0, maxLongitude: 0 };
  }
  let minLatitude = points[0].latitude;
  let maxLatitude = minLatitude;
  let minLongitude = points[0].longitude;
  let maxLongitude = minLongitude;
  for (const point of points.slice(1)) {
    minLatitude = Math.min(minLatitude, point.latitude);
    maxLatitude = Math.max(maxLatitude, point.latitude);
    minLongitude = Math.min(minLongitude, point.longitude);
    maxLongitude = Math.max(maxLongitude, point.longitude);
  }
  return { minLatitude, maxLatitude, minLongitude, maxLongitude };
}
