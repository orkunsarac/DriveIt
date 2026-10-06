import "./world_scoring.generated.js";
import type { CandidateSnapshot } from "./active_world_overlap_stage.ts";
import type { MutationInput } from "./world_scoring_stage.ts";
import type { Road, Trace } from "./world_road_overlap.ts";

export type PersistedTrace = Trace & { minLatitude: number; maxLatitude: number;
  minLongitude: number; maxLongitude: number; createdAt: string; updatedAt: string };
export type PlannedTrace = { id: string; sourceDriveId: string; sourcePublishId: string;
  validatedRoadId: string; matchedSectionId: string; directionKey: string;
  startOffsetMeters: string; endOffsetMeters: string; minLatitude: string;
  maxLatitude: string; minLongitude: string; maxLongitude: string;
  processingVersion: number; createdAt: string; updatedAt: string };
export type MutationPlan = { operationId: string; baseGeneration: string; generation: string;
  closeVersions: { id: string; fromGeneration: string }[]; createTraces: PlannedTrace[] };
const fields = ['sourceDriveId','validatedRoadId','matchedSectionId','directionKey','processingVersion',
  'startOffsetMeters','endOffsetMeters','minLatitude','maxLatitude','minLongitude','maxLongitude'] as const;

export function planWorldMutation(snapshot: CandidateSnapshot, challenger: Road,
  publishId: string, inputs: MutationInput[], now: string): MutationPlan {
  if (!challenger.directionKey || !Number.isInteger(challenger.processingVersion)) throw new Error('mutation_identity_invalid');
  for (const t of snapshot.candidates) {
    const v=t as PersistedTrace;
    if (![v.minLatitude,v.maxLatitude,v.minLongitude,v.maxLongitude].every(Number.isFinite) ||
      !v.createdAt || !v.updatedAt) throw new Error('mutation_snapshot_invalid');
  }
  const bridge=(globalThis as unknown as {driveItWorldMutation:(s:string)=>string}).driveItWorldMutation;
  const output=JSON.parse(bridge(JSON.stringify({challenger,traces:snapshot.candidates,now,
    inputs:inputs.map(i=>({traceId:i.traceId,match:{...i.coverage.match,
      firstStartOffsetMeters:i.coverage.activeStartOffsetMeters,firstEndOffsetMeters:i.coverage.activeEndOffsetMeters,
      secondStartOffsetMeters:i.coverage.challengerStartOffsetMeters,secondEndOffsetMeters:i.coverage.challengerEndOffsetMeters,
      commonDistanceMeters:i.coverage.commonDistanceMeters,comparisonEligible:i.coverage.comparisonEligible},
      regions:i.regions}))}))) as {operationId:string;traces:Omit<PlannedTrace,'sourcePublishId'>[]};
  const byId=new Map(snapshot.candidates.map(t=>[t.id,t as PersistedTrace]));
  const resultingIds=new Set(output.traces.map(t=>t.id));
  if (resultingIds.size!==output.traces.length) throw new Error('mutation_duplicate_trace');
  const retained=new Set<string>();
  const createTraces:PlannedTrace[]=[];
  for (const t of output.traces) {
    const previous=byId.get(t.id);
    if (previous && fields.every(f=>['sourceDriveId','validatedRoadId','matchedSectionId','directionKey'].includes(f)
      ? previous[f]===t[f] : Number(previous[f])===Number(t[f]))) { retained.add(t.id); continue; }
    const source= t.validatedRoadId===challenger.id ? publishId : snapshot.candidates
      .find(c=>c.validatedRoadId===t.validatedRoadId && c.sourceDriveId===t.sourceDriveId)?.sourcePublishId;
    if (!source) throw new Error('mutation_source_missing');
    createTraces.push({...t,sourcePublishId:source});
  }
  return {operationId:output.operationId,baseGeneration:snapshot.generation,
    generation:(BigInt(snapshot.generation)+1n).toString(),
    closeVersions:snapshot.candidates.filter(t=>!retained.has(t.id))
      .map(t=>({id:t.id,fromGeneration:t.activeFromGeneration})),createTraces};
}

// RPC outcomes are server-authoritative; a lost response may be retried safely.
export async function commitWorldMutation(plan: MutationPlan, publishId: string,
  invoke: (name:string,args:Record<string,unknown>)=>Promise<{data:unknown;error:unknown}>): Promise<Record<string,unknown>> {
  const result=await invoke('commit_active_world_mutation',{
    p_publish_id:publishId,p_expected_generation:plan.baseGeneration,p_plan:plan});
  if(result.error || !result.data || typeof result.data!=='object') throw new Error('active_world_commit_failed');
  return result.data as Record<string,unknown>;
}
