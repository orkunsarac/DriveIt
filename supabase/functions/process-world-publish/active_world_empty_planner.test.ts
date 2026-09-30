import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { planEmptyWorld } from "./active_world_empty_planner.ts";
import { sectionDistanceMeters } from "./validated_section_geojson.ts";

const fixture = JSON.parse(readFileSync(
  new URL("../../../test/fixtures/active_world_empty_parity.json", import.meta.url),
  "utf8",
));

for (const scenario of fixture.cases) {
  test(`server empty-world parity: ${scenario.name}`, () => {
    const plan = planEmptyWorld({
      generation: 0,
      driveScoreAlgorithmVersion: 1,
      sourceDriveSessionId: scenario.drive_id,
      validatedRoadId: scenario.road_id,
      directionKey: scenario.direction_key,
      processingVersion: scenario.processing_version,
      sections: scenario.sections.map((section: Record<string, unknown>) => ({
        id: section.id as string,
        distanceMeters: section.distance_meters_exact === undefined
          ? section.distance_meters as number
          : sectionDistanceMeters(section.distance_meters_exact)!,
        geometry: (section.geometry as number[][]).map(([latitude, longitude]) => ({
          latitude, longitude,
        })),
      })),
    });
    const expected = scenario.expected;
    assert.equal(plan.baseGeneration, 0);
    assert.equal(plan.generation, expected.generation);
    assert.equal(plan.operationId, expected.operation_id);
    assert.equal(plan.operationReason, "recordProcessing");
    assert.deepEqual(plan.processedDriveSessionIds, [scenario.drive_id]);
    assert.equal(plan.driveScoreAlgorithmVersion, 1);
    assert.equal(plan.validatedRoadProcessingVersion, 6);
    assert.equal(plan.traces.length, expected.trace_count);
    assert.deepEqual(plan.traces.map((trace) => ({
      id: trace.id,
      source_drive_id: trace.sourceDriveSessionId,
      validated_road_id: trace.validatedRoadId,
      section_id: trace.matchedSectionId,
      start_offset_meters: trace.startOffsetMeters,
      end_offset_meters: trace.endOffsetMeters,
      direction_key: trace.directionKey,
      bounds: [trace.minLatitude, trace.maxLatitude, trace.minLongitude, trace.maxLongitude],
      processing_version: trace.processingVersion,
    })), expected.traces);
  });
}
