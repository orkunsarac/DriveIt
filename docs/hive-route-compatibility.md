# RoutePoint Hive compatibility

## Evidence and limits

- Reachable Git history for `route_point.dart` and its adapter contains commit
  `2062d2e37712686ac52bfe784aabdcb0cbf27408`: typeId 1, field 0 latitude double,
  field 1 longitude double. No historical field 2 declaration is available.
- The real A55 release crash establishes field 2 as a DateTime in a deployed
  record. Its historical semantic name cannot be recovered from this Git history.
- Uncommitted Phase 2 reused field 2 as bool, causing a startup cast failure.
- Field 254 is unused in the available history. Field 2 is now reserved; all
  other unrecognized fields are retained as opaque values, not reinterpreted.

## Contract

- New breakBefore writes use field 254 only. Missing breakBefore defaults false.
- A transitional field-2 bool supplies breakBefore only when 254 is absent.
- A field-2 DateTime never becomes a bool. It is preserved through ordinary
  read/write together with other opaque legacy fields.
- No box migration, bulk rewrite, skipped record, cleanup or fallback catch.
- The compatibility adapter in route_point.g.dart is deliberately maintained;
  generic regeneration is insufficient because it discards unknown fields.
  Run the binary compatibility tests whenever regenerating adapters.

## Other Phase 2 fields

- CanonicalTelemetryPoint typeId 2 keeps timestamp at field 2; its previous
  adapter used 0-8. New breakBefore 9 and gapDurationMicros 10 are additive.
- DriveTelemetryRecord typeId 3 previously used 0-3. Metadata 4 is additive.
- DriveSession typeId 0 remains unchanged; removed fields 8-11 remain reserved.
- My World and score adapters are not changed by this fix. Field numbers are
  scoped by typeId: sharing a number across different models is not a collision.
- This audit cannot prove layouts of unavailable pre-Git releases.

## Tests and safety

Independent legacy models/adapters produce actual Hive binary values and frames
with DateTime field 2, missing field 2 and transitional bool field 2. Tests open
them with production adapters, check nested/mixed boxes, read-only file bytes,
and explicit rewrite preservation. Fixtures use only synthetic data.

The emulator-only integration test seeds the test application's sandbox and
calls real main(), then displays the decoded drive detail and poster. Never run
that fixture seeding test on a user's physical device. Native GPS tests use
separate named synthetic SQLite databases. No user's Hive/SQLite/preferences are
read-write targets for these tests.
