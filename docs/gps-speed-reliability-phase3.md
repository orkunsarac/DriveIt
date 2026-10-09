# GPS reliability Phase 3

## Verified software defects

The Phase 2 selector considered native zero valid and preferred it when geometry
speed differed by no more than max(8 m/s, 75% of geometry speed). A straight
7 m/s drive with native zero therefore persisted 243 zeros in the independent
legacy regression. At 5 Hz, a 14 m/s drive also locked at zero: rejecting the
median's acceleration wrote the previous zero back into the measurement window.
These are verified code paths, not proof of the missing raw inputs from the
28 September drive. Existing real telemetry is not reprocessed.

## Acquisition contract

Keep the five-measurement median and existing plausibility limits. Keep candidate
measurements independent of filtered outputs. Native speed must be finite,
nonnegative, <=70 m/s, with speed accuracy <=2 m/s when provided. Platform zero
speed-accuracy means unavailable, not proof of reliable speed for the first fix.
TaskHandler now supplies the native speedAccuracy measurement.

Geometry fallback needs >=3 points, >=1 second, displacement exceeding both
10 m and summed endpoint accuracy, and net/path coherence >=0.8. Evidence is
bounded at 15 seconds / 80 points; this allows moderate-speed movement under
poorer position accuracy without an unbounded history. Recent stationary
evidence uses a separate 3-second, 10-metre bound. Single displacement or a
native-zero value alone is not proof of movement or a confirmed stop.

`speedSource` distinguishes native, geometry_estimate, held_estimate, unavailable
and legacy (historical provenance unknown). Scalar zero for unavailable speed
is not a measured stop. Geometry-based values are explicitly estimates.

An implausible derivative is not fabricated by ramping at the acceleration cap.
Hold speed until measurements corroborate a rebaseline; then use the supported
speed with accelerationReliable=false. Unknown speed/bootstrap derivatives are
also unreliable. Numeric acceleration is zero at these boundaries, and consumers
reset derivative/event context rather than interpreting it as a measured event.

## Persistence and consumers

Checkpoint version 2 stores the bounded raw evidence window plus existing median,
previous point and distance anchor. Version 1 remains readable and warms new
evidence prospectively. Current checkpoints restore exactly through JSON/native
SQLite; no journal table, WAL setting, session ID or sequence change.

Quality goes into existing point JSON and the already available record metadata
field 4 (`canonicalQualityV1`). No Hive field IDs added/reused. Record reads
hydrate quality; no historical box migration or automatic writes.

DriveFeatureExtractor resets smoothing and duration/heading context at unknown
derivatives and gap boundaries. DriveTelemetryAnalyzer consumes the canonical
derivative when supplied instead of deriving it a second time; its legacy raw
input behavior stays available. Score weights, coefficients and N/A rules are
unchanged. No sample exclusion/coverage redesign was introduced; unreliable
intervals do not supply derivative-event evidence.

Unknown/held speed cannot establish or bridge an event/traffic interval, and
cannot support a validated maximum-speed measurement. These are acquisition
qualification guards, not changes to category thresholds or scoring formulae.

Diagnostic export exposes quality. The existing Planet source contract still
does not transmit these additional flags: no server or publish schema change is
part of this task. Server consumption of quality is a separate follow-up.

## Remaining limits

- GPS uncertainty cannot prove all slow movement vs drift. Evidence criteria
  deliberately prefer unavailable over invented speed; tight curves and weak
  fixes can delay fallback. Native/position accuracy calibration needs real A55
  movement acceptance, not just a stationary emulator.
- The median retains its existing lag, which can attenuate short genuine events.
  Sustained hard acceleration/braking is covered synthetically.
- Old checkpoint/committed-only recovery cannot reconstruct old raw/native
  measurements that were never stored. No historical correction is performed.
- Speed-source indicates acquisition provenance; scalar speed remains the median
  estimate, not an unfiltered Doppler reading.
- Emulator tests use named synthetic DBs and actual MethodChannel/headless engine.
  No physical phone install, live-drive experiment, cloud change or Git push.
