import { rules, type MatchingResult } from "./world_validation.ts";

export type PersistedValidationStatus = "validated" | "partially_validated";

// Internal provider/Dart naming is not the persisted Postgres enum contract.
export function serializeValidationStatus(status: MatchingResult["status"]): PersistedValidationStatus {
  switch (status) {
    case "validated": return "validated";
    case "partiallyValidated": return "partially_validated";
    default: throw new Error("validation_status_invalid");
  }
}

export function roadPayload(result: MatchingResult) {
  const sections = result.sections;
  const validationStatus = serializeValidationStatus(result.status);
  const line = (section: MatchingResult["sections"][number]) => section.geometry.map(
    (point) => [point.longitude, point.latitude],
  );
  return {
    road: {
      provider_id: "mapbox-map-matching-v5-driving",
      processing_version: rules.validatedRoadProcessingVersion,
      valid_distance_meters: result.validDistanceMeters,
      validation_status: validationStatus,
      confidence: result.confidence === null ? null
        : Math.min(1, Math.max(0, result.confidence)),
      direction_key: result.directionKey,
      average_heading_degrees: result.averageHeadingDegrees,
      section_count: sections.length,
      geometry: { type: "MultiLineString", coordinates: sections.map(line) },
    },
    sections: sections.map((section, order) => ({
      section_key: section.id,
      section_order: order,
      distance_meters: section.distanceMeters,
      confidence: section.confidence,
      source_trace_index: section.sourceTraceIndex,
      source_chunk_index: section.sourceChunkIndex,
      geometry: { type: "LineString", coordinates: line(section) },
    })),
  };
}
