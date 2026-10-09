# GPS flow safety — Phase 2

This is acquisition/session safety, not a new GPS speed filter, Drive Score or
World ownership algorithm. Existing filter constants and formulas are unchanged.
Previous Hive drives are not migrated or recalculated.

## Producer

The foreground isolate owns one `GpsStreamSupervisor`. UI subscriptions are
presentation-only and cannot append to the GPS journal. Service availability and
permission are polled in the already-running task. No supervisor operation starts
an Android foreground service. Permission checks never request permissions.

15 seconds without a fresh timestamp changes presentation to GPS waiting. A
silent stream is renewed after 30 seconds. Errors/done retry with bounded backoff
(1/2/4/8/16/30 seconds, then at most once per minute). A valid fresh fix resets
backoff. Cancelled epochs, duplicate timestamps and concurrent polls cannot
produce parallel writes or reset the freshness watchdog. Permission/service-off
states suspend subscriptions without closing the session.

## Gaps

Existing diagnostics use >5s and >15s sample-gap thresholds. New accepted points
carry `gapDurationMicros` for >5s and `breakBefore` for >15s. A long gap starts a
fresh canonicalizer continuity context, using the existing first-point behavior
(no distance/acceleration inferred across the gap). No coordinates are invented.
The resumed point is retained even with zero distance, becomes the next distance
anchor, and begins a separate route segment. The flag survives checkpoint,
SQLite payload and backward-compatible Hive adapters.

Live/detail maps, summary/card previews and poster paths consume segment breaks.
My World's input preprocessor honors the explicit boundary before applying its
unchanged matching/ownership rules. Legacy recordings have default false flags.

Score formulas are unchanged. Gaps still mean incomplete observations, not a
measurement of zero driving performance. All gap-specific score coverage/event
eligibility policy remains a follow-up topic. Planet source schema/server are
unchanged and do not yet transport the new explicit route-boundary flag; parity
for newly recorded interrupted drives must be addressed separately before claiming
that Planet's inferred geometry is equally gap-safe.

## Finish

SQLite schema v2 only adds `session_events`; existing sessions/points/append-only
triggers stay untouched. A stop-request event is durable/idempotent before drain.
`stopped_us` denotes that real request time, while `drained` records completion
time and final committed sequence. Recording start time stays `started_us`.

Closing the supervisor synchronously fences callbacks, then cancels subscription.
All accepted writer work drains before an atomic tail-sequence check and stopped
transition. UI verifies the receipt/tail again before summary and Hive transfer.
Repeated stop requests share a local in-flight operation. Restart after a durable
stop request drains the existing journal instead of subscribing again.

If draining exceeds the existing 15s UI deadline, the session/producer state is
not cleared. The user gets a recoverable error; durable points remain available.
There is no forced final GPS fetch: the last actually accepted coordinate is used.
Hive telemetry stores optional acquisition metadata and event times. Only a
successful existing save callback releases the active pointer; archived points
are never deleted. `DriveSession.date` remains the summary save timestamp.

## Verification limits

Unit/FFI tests use fake clocks/streams and temporary SQLite/Hive databases. Native
Android tests use uniquely named synthetic databases on emulator-5558, including
v1→v2 upgrade and a headless foreground FlutterEngine recreation. These are not
physical A55 lock/tunnel/battery-policy acceptance tests. No real phone install,
GPS recording, backend processing, or GitHub upload is part of this phase.

Persistent disk failure plus process death can still lose samples never committed
to disk; no local-only architecture can guarantee those bytes. Committed prefixes
and pending stop requests survive. Android forcibly killing the foreground service
may require a user foreground recovery, rather than prohibited background restart.
