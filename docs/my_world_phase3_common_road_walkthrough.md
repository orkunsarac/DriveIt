# Benim Dünyam — Phase 3 Common Road Detection

## Scope

Phase 3 adds only a pure geometry-domain comparison between two validated
roads. It does not call Drive Score, create World records, persist overlap
results, modify validation, draw neon routes, or select record owners.

## Same-road algorithm

`WorldRoadOverlapService` accepts two `ValidatedRoad` instances. It uses their
continuous `MatchedRoadSection` geometry when available and falls back to the
validated road's flattened geometry only for legacy-compatible input. Section
bounding boxes provide a coarse early rejection. Candidate sections are then
temporarily resampled every 25 metres and matched through a small spatial grid
rather than comparing every point against every other point.

For each first-road sample, the closest second-road sample must be within 15
metres and must have a tangent direction within 30 degrees. Matched samples
must progress forward on both geometries; a break in geometric continuity
closes the current result rather than joining unrelated parts. This preserves
separate overlaps and protects U-turns or self-intersections from arbitrary
first-index matching.

## Direction and parallel-road safety

Direction is derived from the travel-ordered geometry tangents, not a single
heading field. Reverse geometry therefore fails the direction check even when
the physical street centre line is identical. The 15 metre distance tolerance,
30 degree direction threshold, forward-progress requirement, minimum 100
metre continuous reported match, relative length consistency check, and
confidence threshold work together to prefer false negatives over false
positive matches for parallel carriageways, service roads, and junctions.

## Offsets and multiple matches

Every `CommonRoadMatch` reports start/end offsets in metres on both source
validated roads, source section identifiers, ordered reference geometry,
common distance, direction compatibility, and deterministic geometry
confidence. These offsets are based on the travel order and can later select
corresponding canonical telemetry ranges without calling Drive Score in this
phase. Multiple disconnected common blocks are returned as separate results.

## Eligibility

`MyWorldRules.minimumCommonWorldDistanceMeters` centrally defines the 1000 m
future-comparison threshold. The matcher still reports shorter real overlap;
only `comparisonEligible` is false below 1000 m. No 100 m or 500 m persistent
segment structure is created.

## Examples

| Case | Result |
| --- | --- |
| 300 m same-direction common road | Match is returned; `comparisonEligible=false`. |
| 2.4 km same-direction common road | One match is returned; `comparisonEligible=true`. |
| 2.4 km identical geometry in reverse order | No common World-road match is returned. |

## Validation

The Phase 3 tests cover full and partial overlap, offsets, reverse direction,
300 m and 1 km eligibility boundaries, parallel roads, short intersections,
small Mapbox geometry variation, differing point density, disconnected
sections, and empty/insufficient geometry. Full test, static analysis, and
whitespace validation are run after implementation.

## Intentional next boundary

Common geometry is intentionally not persisted or scored. Future phases may
consume `CommonRoadMatch` offsets for local canonical-telemetry scoring, then
apply score comparison and ownership rules separately.
