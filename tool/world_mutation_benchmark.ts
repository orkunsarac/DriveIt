import {readFileSync} from 'node:fs';
import {evaluateScoring} from '../supabase/functions/process-world-publish/world_scoring.ts';
import {planWorldMutation} from '../supabase/functions/process-world-publish/world_mutation.ts';
const scoringCases=JSON.parse(readFileSync('test/fixtures/active_world_scoring.json','utf8'));
const mutationCases=JSON.parse(readFileSync('test/fixtures/active_world_mutation.json','utf8'));
const measurements=[];
const dense=structuredClone(scoringCases[0]);
for(const side of ['first','second']) {
  const pts=dense[side+'Telemetry'];
  dense[side+'Telemetry']=Array.from({length:2001},(_,i)=>{
    const f=i/5,a=pts[Math.floor(f)],b=pts[Math.min(400,Math.ceil(f))],ratio=f-Math.floor(f);
    return {...a,longitude:a.longitude+(b.longitude-a.longitude)*ratio,
      timestamp:new Date(Date.parse(pts[0].timestamp)+i*200).toISOString()};
  });
  const g=dense[side+'Road'].sections[0].geometry;
  dense[side+'Road'].sections[0].geometry=Array.from({length:201},(_,i)=>({
    latitude:g[0].latitude,longitude:g[0].longitude+(g[1].longitude-g[0].longitude)*i/200}));
}
for(const n of [1,3]) {
  const begin=performance.now();let maxHeap=0;
  for(let i=0;i<n;i++){evaluateScoring(dense);maxHeap=Math.max(maxHeap,Deno.memoryUsage().heapUsed);}
  measurements.push({kind:'dense_geometry_scoring',candidateCount:n,telemetryPointsPerDrive:2001,
    sectionPoints:201,milliseconds:performance.now()-begin,sampledHeapMaxBytes:maxHeap,
    sourceJsonBytes:new TextEncoder().encode(JSON.stringify(dense.firstTelemetry)).length,
    rssBytes:Deno.memoryUsage().rss});
}
for(const n of [1,10,25]) {
  const c=scoringCases[0];const memoryBefore=Deno.memoryUsage();let maxHeap=memoryBefore.heapUsed;
  const begin=performance.now();
  for(let i=0;i<n;i++){evaluateScoring(c);maxHeap=Math.max(maxHeap,Deno.memoryUsage().heapUsed);}
  measurements.push({kind:'actual_dart_js_scoring',candidateCount:n,telemetryPointsPerDrive:c.firstTelemetry.length,
    sectionPoints:c.firstRoad.sections[0].geometry.length,windowsPerCandidate:40,
    milliseconds:performance.now()-begin,sampledHeapMaxBytes:maxHeap,rssBytes:Deno.memoryUsage().rss});
}
for(const n of [100,1000,5000]) {
  const c=structuredClone(mutationCases[0]);c.inputs=[];c.snapshot.candidates=[];
  for(let i=0;i<n;i++)c.snapshot.candidates.push({...mutationCases[0].snapshot.candidates[0],
    id:'unaffected-'+i,matchedSectionId:'unaffected-section-'+i});
  const begin=performance.now();const plan=planWorldMutation(c.snapshot,c.challenger,c.publishId,[],c.now);
  measurements.push({kind:'mutation_candidate_snapshot',candidateCount:n,milliseconds:performance.now()-begin,
    planBytes:new TextEncoder().encode(JSON.stringify(plan)).length,closes:plan.closeVersions.length,
    creates:plan.createTraces.length,heapUsedBytes:Deno.memoryUsage().heapUsed,rssBytes:Deno.memoryUsage().rss});
}
console.log(JSON.stringify(measurements));
