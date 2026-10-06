// Generated from the shared My World/Drive Score Dart services. No parallel
// scoring formula. Regeneration and native-vs-JS checks: tool/world_scoring_*.
import "./world_scoring.generated.js";
import type { CanonicalSourcePoint } from "./source_contract.ts";
import type { Match, Road } from "./world_road_overlap.ts";

export type Score = { totalScore: number; displayScore: number; algorithmVersion: number;
  overallConfidence: number; categories: Record<string, { score: number; maximum: number;
    applicable: boolean; sampleSufficient: boolean }>;
  contributions: Record<string, { contribution: number; source: string }> };
export type Comparison = { outcome: string; comparisonValid: boolean;
  firstLocalScore: Score | null; secondLocalScore: Score | null;
  scoreDifference: number | null; relativeDifference: number | null };
export type Window = { commonStartOffsetMeters: number; commonEndOffsetMeters: number;
  existingStartOffsetMeters: number; existingEndOffsetMeters: number;
  challengerStartOffsetMeters: number; challengerEndOffsetMeters: number;
  state: string; comparison: Comparison };
export type WinningRegion = { existingDriveId: string; challengerDriveId: string;
  startOffsetOnExistingMeters: number; endOffsetOnExistingMeters: number;
  startOffsetOnChallengerMeters: number; endOffsetOnChallengerMeters: number;
  commonStartOffsetMeters: number; commonEndOffsetMeters: number;
  winningDistanceMeters: number; algorithmVersion: number;
  confidence: number; supportingWindowCount: number };
export type ScoringResult = { status: "success" | "notEligible" | "insufficientConfidence" |
  "unsupportedAlgorithmVersion" | "telemetryUnavailable";
  comparison?: Comparison; windows: Window[]; winningRegions: WinningRegion[];
  firstExtraction?: { status: string; count: number; startIndex: number; endIndex: number; timestamps: string[] };
  secondExtraction?: { status: string; count: number; startIndex: number; endIndex: number; timestamps: string[] } };
export type ScoringInput = { algorithmVersion: number; match: Match;
  firstRoad: Road; secondRoad: Road; firstTelemetry: CanonicalSourcePoint[];
  secondTelemetry: CanonicalSourcePoint[] };
export function evaluateScoring(input: ScoringInput): ScoringResult {
  const bridge = (globalThis as unknown as { driveItWorldScoring: (s: string) => string }).driveItWorldScoring;
  return JSON.parse(bridge(JSON.stringify(input)));
}
export type ActiveCoverage = { firstStartOffsetMeters: number; firstEndOffsetMeters: number;
  secondStartOffsetMeters: number; secondEndOffsetMeters: number;
  commonDistanceMeters: number; comparisonEligible: boolean };
export function clipActiveCoverage(match: Match, sectionId: string, start: number, end: number): ActiveCoverage | null {
  const bridge = (globalThis as unknown as { driveItActiveCoverage: (s: string) => string }).driveItActiveCoverage;
  return JSON.parse(bridge(JSON.stringify({ match, sectionId, start, end })));
}
