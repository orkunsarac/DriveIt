export type SectionCoordinate = { latitude: number; longitude: number };

/** Decode the round-trip float8 text contract, never a lossy JSON number. */
export function sectionDistanceMeters(value: unknown): number | null {
  if (typeof value !== "string") return null;
  // Preserve the planner's existing geometry fallback for non-finite lengths.
  if (value === "NaN") return Number.NaN;
  if (value === "Infinity") return Number.POSITIVE_INFINITY;
  if (value === "-Infinity") return Number.NEGATIVE_INFINITY;
  if (!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(value)) return null;
  const distance = Number(value);
  return Number.isFinite(distance) ? distance : null;
}

/** Parse the JSONB GeoJSON projection returned by the server-only read RPC. */
export function sectionCoordinates(value: unknown): SectionCoordinate[] | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const line = value as { type?: unknown; coordinates?: unknown };
  if (line.type !== "LineString" || !Array.isArray(line.coordinates) || line.coordinates.length < 2) {
    return null;
  }

  const coordinates: SectionCoordinate[] = [];
  for (const pair of line.coordinates) {
    if (!Array.isArray(pair) || pair.length < 2) return null;
    const [longitude, latitude] = pair;
    if (typeof longitude !== "number" || typeof latitude !== "number" ||
        !Number.isFinite(longitude) || !Number.isFinite(latitude) ||
        longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
      return null;
    }
    coordinates.push({ longitude, latitude });
  }
  return coordinates;
}
