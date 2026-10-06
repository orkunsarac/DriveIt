# Active World Phase 2B

## Implementation choice

| Approach | Parity / precision | Cost / maintenance | Testability / Phase 2C |
|---|---|---|---|
| Hand-port all Dart score engines to TypeScript | Two implementations of ~2,500 lines; microsecond timestamps need explicit handling | Same Storage costs, greater drift risk | Independent oracle required for every category and calibration |
| Native fixtures + independent TS implementation | Fixtures detect covered differences, not all future drift | Same network costs, still duplicate scoring formulas | Useful regression oracle but not a substitute for source-of-truth |
| Compile the existing pure Dart services to JS (selected) | Same extractor, calculator, category/N-A rules and winning-region service; native-vs-Deno fixtures verify microseconds | ~128 KB production artifact, no runtime compiler; transitive source/artifact SHA256 guard | Typed TS adapter and request loader; no mutation responsibilities |

The production bundle does **not** import the scripted boundary calculator.
That test-only seam follows the existing My World Phase 5 test pattern.
Actual calculator fixtures test challenger/owner wins, N/A categories and
native-vs-JS totals/contributions. Scripted-score fixtures exercise exact 1%,
200/300 m gaps and 1900/2000 m winning-region boundaries without inventing scores.

## Source semantics and adapter boundary

- 35 m projection, 60 degree heading; selected samples must be strictly chronological.
- All nine canonical fields are constructed directly; no `fromMap` defaults,
  timestamp millisecond conversion, rounding, resampling or downsampling.
- Stage 2A clipped offsets replace the match's full-section endpoints.
- A strict outer extraction (zero offset tolerance) precedes the unchanged
  window service. Its existing +/-5 m boundary tolerance therefore cannot
  escape the active trace/common-road span.
- 100 m windows, >=1% improvement, <=200 m bridged gaps, >=2000 m regions.
  Region length includes bridged gaps, as in Dart. Scores are retained per
  window, not turned into a new region-average score.
- <3000 m overlap preserves geometry coverage but never loads or scores sources.
- Unsupported schema/telemetry/score/world versions produce typed failures.

**Source-of-truth risk, not changed here:** the extractor sums provider section
distances for preceding sections, then measures offsets inside the selected
section from geometry. Stage 2A overlap uses provider-normalized section offsets.
Where provider and geometric lengths differ, extracted samples can shift or
be omitted. Tests preserve this native behavior; do not normalize it silently
before Stage 2C. Floating-point projection can also exclude a boundary sample
by a sub-ULP difference; no arbitrary offset rounding/widening was added.

## Storage, security and performance

One metadata query for distinct challenger/overlapping incumbent publish IDs.
One private Storage download per unique source publish per request; a source
already downloaded during new validation is seeded rather than re-downloaded.
Failures are cached too. Identity, deterministic owner/id path, source readiness,
counts, versions and all canonical fields are checked before scoring.
No historical scan, mobile source access, token/geometry/telemetry logging or
new database schema. Only counts and a typed STOP code reach the client.

For U distinct sources there are U Storage downloads (U-1 with challenger seed),
one metadata batch; repeated traces from the same incumbent cost no new download.
Candidates run sequentially. The unchanged Dart implementation projects each
subset for each window: roughly O(sum(windows * telemetryPoints * sectionSegments)).
Large candidate/telemetry loads still need CPU/memory budgeting before production
ownership mutation; synthetic tests are not a hosted-load benchmark.

## Reproducibility

```powershell
./tool/build_world_scoring.ps1 -DartExecutable <path-to-dart.exe>
deno run --allow-write=test/fixtures tool/world_scoring_fixtures.ts
dart tool/world_scoring_oracle.dart test/fixtures/active_world_scoring.json test/fixtures/active_world_scoring_oracle.json
deno test --allow-read --allow-env supabase/functions/process-world-publish
flutter test test/active_world_scoring_parity_test.dart
```

The compiler script builds both production and test-only artifacts and hashes
all transitive Dart inputs with platform-independent line endings. Regenerate
after changing a source algorithm; native oracle fixtures still must pass.

## Deliberate stop

Non-empty flow ends at `world_ownership_mutation_not_implemented` (HTTP 409).
No split/removal/insertion, generation creation/pointer switch, publish final
state or ownership transaction is implemented. Generation 1 is not mutated.
ValidatedRoad reuse still short-circuits Mapbox; new validation persistence and
empty-world Stage 1 remain unchanged. Real challenger invocation is not part
of this phase's verification.
