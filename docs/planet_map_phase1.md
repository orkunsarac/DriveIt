# Planet Map Phase 1

Dedicated authenticated `read_planet_viewport` RPC was chosen over exposing
base tables/RLS columns or using a service-role read Edge proxy. It returns
only generation, safety state, opaque trace/style identity, active length and
clipped GeoJSON; no publish/user identifiers, Storage paths or telemetry.
The mobile client uses its existing Supabase session. Logged out/unconfigured
states are explicit and do not impact local My World.

STABLE PostgreSQL function uses one statement snapshot. Current partial GiST
predicate excludes retired versions; generation metadata and traces are not
mixed across a concurrent commit. A trace introduced in an earlier generation
is correctly included if still active. No historical drive scan occurs.

Section prefixes use ordered float8 addition. Positive provider length is
canonical, spherical geometry length is fallback. Canonical fractions map to
spherical segment cumulative lengths followed by the same coordinate
interpolation as the Dart geometry resolver, not planar ST_LineSubstring.
The resulting geometry is only the active span, never the whole source section.
Ownership/source geometry is not modified.

Zoom >=10, <=1 degree lat/lon span, <=200 coarse candidates, <=100000 source
vertices and <=1MiB JSON bounds work/payload. Crossing the dateline queries two
GiST envelopes separately, avoiding a whole-world bounding box. Large/dense
views return zoom_in with no silently truncated traces. This conservative
policy may eventually need tiles or pagination when density is high.

Flutter controller debounces idle 300ms, caches identical viewports 15s, sequences
requests and rejects older generations. Dispose invalidates pending callbacks.
Viewport changes replace geometry rather than merging old/current generations.
Shared WorldTracePresentationService keeps +/-3m offsets, stable tangents and
corner scaling presentation-only. Dark GoogleMap style, palette, line/glow,
start/end circles and visibility policy match My World. No local Hive/GPS/
scoring business logic is used by Planet. Planet currently has no local drive
detail drilldown, intro tour or telemetry-derived reverse-direction metadata;
opposite presentation uses geometry-local direction. It never downloads source
telemetry for that purpose.

SQL tests create an isolated synthetic namespace in one rollback transaction,
testing current/future/retired versions, viewport intersections, active clipping,
4000 geometry / 5000 canonical mismatch, cumulative prefix, auth, dateline,
limits, determinism and index selection. Real DEV acceptance is read-only.
Flutter platform map is substituted only in widget tests; native GoogleMap
rendering requires separate device acceptance.

Observed synthetic DB workload: 20102 traces, 100 visible, GiST index scan,
~27.2ms full read, 21949 byte payload. Real generation 2: one incumbent trace,
573 points, 13861 byte JSONB text. Management API roundtrip (~798ms) is not a
mobile RPC latency measurement. Real geometry/telemetry is not committed as
a fixture. Source geometry density and repeated per-section clipping may need
batching/tiles/caching later; current bounds are deliberate Phase 1 safeguards.

Migration 202610060004 replaces segment-by-segment PL/pgSQL clipping with
ordered set-based spherical clipping. Dense/corner synthetic parity passes;
real RPC execution fell from ~292ms to ~93ms cold/~45ms warm, with identical
real response size/point count. A one-row live world reasonably uses seq scan;
the 20k synthetic workload uses the corresponding current-only GiST predicate.
Desktop Flutter synthetic 50x573 points (~571KB): parsing ~22ms, drawing set
construction ~35ms; these exclude native GoogleMap rendering and A55 frame cost.
