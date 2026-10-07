import {
  type PublishSourceMetadata,
  sourceMatches,
} from "../process-world-publish/source_contract.ts";
import "./score.generated.js";
import { rules } from "../process-world-publish/world_validation.ts";

export type Context = {
  generation: string;
  trace_id: string;
  ownership_distance_meters: number;
  display_name: string | null;
  username: string | null;
  publish: PublishSourceMetadata & {
    user_id: string;
    source_path: string;
    source_ready_at: string;
  };
};
export type Summary = {
  drive_date: string;
  distance_meters: number;
  duration_seconds: number;
  average_speed_kmh: number;
  maximum_speed_kmh: number;
  score: unknown;
};
export class DetailFailure extends Error {
  constructor(public code: string, public status = 503) {
    super(code);
  }
}
type Entry = { until: number; value: Promise<Summary> };
export class SummaryCache {
  private entries = new Map<string, Entry>();
  constructor(
    private limit = 16,
    private ttl = 300000,
    private now = () => Date.now(),
  ) {}
  get(key: string, load: () => Promise<Summary>): Promise<Summary> {
    const previous = this.entries.get(key);
    if (previous && previous.until > this.now()) {
      this.entries.delete(key);
      this.entries.set(key, previous);
      return previous.value;
    }
    const value = load();
    const entry = { until: this.now() + this.ttl, value };
    this.entries.delete(key);
    this.entries.set(key, entry);
    while (this.entries.size > this.limit) {
      this.entries.delete(this.entries.keys().next().value!);
    }
    value.catch(() => {
      if (this.entries.get(key) === entry) this.entries.delete(key);
    });
    return value;
  }
}
export function summarize(source: unknown, context: Context): Summary {
  if (!sourceMatches(source, context.publish)) {
    throw new DetailFailure("source_invalid", 422);
  }
  const s = source as typeof source & {
    recorded_distance_meters: number;
    started_at: string;
    ended_at: string;
    drive_score_algorithm_version: number;
  };
  if (s.drive_score_algorithm_version !== rules.driveScoreAlgorithmVersion) {
    throw new DetailFailure("score_version_unsupported", 422);
  }
  const duration = Math.floor(
    (Date.parse(s.ended_at) - Date.parse(s.started_at)) / 1000,
  );
  if (duration <= 0 || s.recorded_distance_meters < 0) {
    throw new DetailFailure("source_invalid", 422);
  }
  const bridge = (globalThis as unknown as {
    driveItPlanetDetailScore: (s: string) => string;
  }).driveItPlanetDetailScore;
  let score: unknown;
  try {
    const raw = JSON.parse(
      bridge(JSON.stringify({ canonical_telemetry: s.canonical_telemetry })),
    );
    score = raw == null ? null : {
      displayScore: raw.displayScore,
      totalScore: raw.totalScore,
      categories: raw.categories,
    };
  } catch {
    throw new DetailFailure("score_unavailable", 422);
  }
  return {
    drive_date: s.ended_at,
    distance_meters: s.recorded_distance_meters,
    duration_seconds: duration,
    // Same total-time average as MapScreen.finalize -> DriveSummaryDialog.
    average_speed_kmh: s.recorded_distance_meters / duration * 3.6,
    maximum_speed_kmh: s.canonical_telemetry.reduce(
      (n, p) => Math.max(n, p.speed_mps * 3.6),
      0,
    ),
    score,
  };
}
export interface DetailGateway {
  context(id: string): Promise<Context | null>;
  download(path: string): Promise<unknown>;
}
export async function readDetail(
  id: string,
  gateway: DetailGateway,
  cache: SummaryCache,
) {
  const context = await gateway.context(id);
  if (!context) throw new DetailFailure("trace_retired", 410);
  const p = context.publish;
  if (!p.source_ready_at || p.source_path !== `${p.user_id}/${p.id}.json`) {
    throw new DetailFailure("source_unavailable", 422);
  }
  const summary = await cache.get(
    `${p.id}:${p.source_ready_at}:${p.drive_score_algorithm_version}`,
    async () => summarize(await gateway.download(p.source_path), context),
  );
  // Revalidate after expensive work: ownership may have changed while reading.
  const current = await gateway.context(id);
  if (!current) throw new DetailFailure("trace_retired", 410);
  if (
    current.publish.id !== p.id ||
    current.ownership_distance_meters !== context.ownership_distance_meters
  ) {
    throw new DetailFailure("trace_changed", 409);
  }
  return {
    ok: true,
    trace_id: id,
    generation: current.generation,
    display_name: current.display_name,
    username: current.username,
    ownership_distance_meters: current.ownership_distance_meters,
    ...summary,
  };
}
