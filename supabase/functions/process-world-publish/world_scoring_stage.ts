import { sourceMatches, type PublishSourceMetadata, type PublishedSource } from "./source_contract.ts";
import { rules } from "./world_validation.ts";
import { evaluateScoring, type ScoringResult, type WinningRegion } from "./world_scoring.ts";
import type { Coverage, Road } from "./world_road_overlap.ts";

export type SourceRow = PublishSourceMetadata & {
  user_id: string; source_path: string | null; source_ready_at: string | null;
};
export type SourceFailure = "world_source_lookup_failed" | "world_source_missing" |
  "world_source_mismatch" | "world_source_invalid" | "world_source_download_failed" |
  "world_score_version_unsupported";
export class ScoringSourceError extends Error {
  constructor(readonly code: SourceFailure) { super(code); }
}
export interface SourceGateway {
  metadata(ids: string[]): Promise<SourceRow[]>;
  download(path: string): Promise<unknown>;
}
// One metadata batch, one cached promise per source publish (including failures).
// Caller supplies only sources of exact overlaps, not a historical scan.
export class RequestSourceLoader {
  private rows = new Map<string, SourceRow>();
  private loaded = new Map<string, Promise<PublishedSource>>();
  constructor(private gateway: SourceGateway, private seeds = new Map<string, unknown>()) {}
  async prepare(ids: string[]): Promise<void> {
    let rows: SourceRow[];
    try { rows = await this.gateway.metadata([...new Set(ids)]); }
    catch { throw new ScoringSourceError("world_source_lookup_failed"); }
    this.rows = new Map(rows.map((r) => [r.id, r]));
  }
  load(id: string, driveId: string): Promise<PublishedSource> {
    const row = this.rows.get(id);
    if (!row) return Promise.reject(new ScoringSourceError("world_source_missing"));
    if (row.local_drive_id !== driveId || !row.source_ready_at ||
      row.source_path !== `${row.user_id}/${row.id}.json`) {
      return Promise.reject(new ScoringSourceError("world_source_mismatch"));
    }
    if (row.drive_score_algorithm_version !== rules.driveScoreAlgorithmVersion ||
      row.telemetry_version !== rules.telemetryVersion || row.source_schema_version !== rules.sourceSchemaVersion ||
      row.world_rules_version !== rules.worldRulesVersion) {
      return Promise.reject(new ScoringSourceError("world_score_version_unsupported"));
    }
    if (!this.loaded.has(id)) this.loaded.set(id, (async () => {
      let source: unknown;
      if (this.seeds.has(id)) source = this.seeds.get(id);
      else {
        try { source = await this.gateway.download(row.source_path!); }
        catch { throw new ScoringSourceError("world_source_download_failed"); }
      }
      if (!sourceMatches(source, row)) throw new ScoringSourceError("world_source_invalid");
      return source;
    })());
    return this.loaded.get(id)!;
  }
}

export type RegionInput = WinningRegion & { winnerDriveId: string; comparisonEligible: boolean;
  bridgedDistanceMeters: number; comparisons: { start: number; end: number;
    incumbentScore: number | null; challengerScore: number | null;
    improvementRatio: number | null; state: string }[] };
export type MutationInput = { traceId: string; sourcePublishId: string;
  coverage: Coverage; scoring: ScoringResult; regions: RegionInput[] };
export type ScoringStage = { state: "world_ownership_mutation_not_implemented";
  inputs: MutationInput[] } | { state: "failure"; errorCode: SourceFailure | "world_scoring_failed" };
export async function analyzeWorldScoring(challengerPublishId: string, challenger: Road,
  roads: Road[], overlaps: Coverage[], loader: RequestSourceLoader): Promise<ScoringStage> {
  const eligible = overlaps.filter((c) => c.comparisonEligible);
  try {
    if (eligible.length) await loader.prepare([challengerPublishId, ...eligible.map((c) => c.trace.sourcePublishId)]);
    const roadById = new Map(roads.map((r) => [r.id, r]));
    const inputs: MutationInput[] = [];
    // Sequential candidates bound peak memory/CPU; promise cache still avoids N+1
    // downloads when multiple traces belong to the same owner source.
    for (const coverage of overlaps) {
      let scoring: ScoringResult = { status: "notEligible", windows: [], winningRegions: [] };
      if (coverage.comparisonEligible) {
        const incumbent = roadById.get(coverage.trace.validatedRoadId);
        if (!incumbent || incumbent.driveId !== coverage.trace.sourceDriveId) throw new Error("identity");
        const first = await loader.load(coverage.trace.sourcePublishId, incumbent.driveId);
        const second = await loader.load(challengerPublishId, challenger.driveId);
        const match = { ...coverage.match,
          firstStartOffsetMeters: coverage.activeStartOffsetMeters,
          firstEndOffsetMeters: coverage.activeEndOffsetMeters,
          secondStartOffsetMeters: coverage.challengerStartOffsetMeters,
          secondEndOffsetMeters: coverage.challengerEndOffsetMeters,
          commonDistanceMeters: coverage.commonDistanceMeters,
          comparisonEligible: coverage.comparisonEligible };
        scoring = evaluateScoring({ algorithmVersion: rules.driveScoreAlgorithmVersion, match,
          firstRoad: incumbent, secondRoad: challenger,
          firstTelemetry: first.canonical_telemetry, secondTelemetry: second.canonical_telemetry });
      }
      const regions = scoring.winningRegions.map((r): RegionInput => {
        const windows = scoring.windows.filter((w) =>
          w.commonStartOffsetMeters >= r.commonStartOffsetMeters && w.commonEndOffsetMeters <= r.commonEndOffsetMeters);
        const supported = windows.filter((w) => w.state === "challengerBetter")
          .reduce((n,w) => n + w.commonEndOffsetMeters - w.commonStartOffsetMeters,0);
        return { ...r, winnerDriveId: r.challengerDriveId, comparisonEligible: coverage.comparisonEligible,
          bridgedDistanceMeters: r.winningDistanceMeters - supported,
          // Scores remain per physical window, never an invented region average.
          comparisons: windows.map((w) => ({ start: w.commonStartOffsetMeters, end: w.commonEndOffsetMeters,
            incumbentScore: w.comparison.firstLocalScore?.totalScore ?? null,
            challengerScore: w.comparison.secondLocalScore?.totalScore ?? null,
            improvementRatio: w.comparison.relativeDifference, state: w.state })) };
      });
      inputs.push({ traceId: coverage.trace.id, sourcePublishId: coverage.trace.sourcePublishId, coverage, scoring, regions });
    }
    // Intentionally no DB mutation, final publish state, ownership split or CAS.
    return { state: "world_ownership_mutation_not_implemented", inputs };
  } catch (e) {
    return { state: "failure", errorCode: e instanceof ScoringSourceError ? e.code : "world_scoring_failed" };
  }
}
