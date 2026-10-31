# PROD deployment record and security acceptance

Target: `arwnbogcswisfesayosy`. On the deployment verification, migration history contained 25 entries, Group Drive gate was false, signup disabled, and Auth users and Storage objects were zero. Nine approved functions were active; both approved buckets were private. The group publish and cleanup endpoints rejected unauthenticated requests with HTTP 401.

P-GR5 source-contract comparison completed: 18 public tables, 11 public/Storage/Realtime policies and 39 application functions matched the expected catalog built from the hash-pinned 25 migrations, including definitions, table privileges, EXECUTE rights and search_path. See [per-object evidence](prod_pgr5_policy_audit.md).

P-GR5B local real-service acceptance completed: 185 SQL checks and three service integration tests passed with exit code 0. Auth/profile, A/B isolation, drive upload/download/retry, Planet publish/read, private Storage and group gate/Realtime were exercised. The external Mapbox provider was a deterministic local fixture; live Mapbox and real-device/two-device acceptance remain separate beta gates. See [integration evidence and limits](prod_pgr5b_integration_acceptance.md). Signup and Group Drive remain closed on PROD; no production activation is implied.

The temporary broad PAT has not been revoked. Revocation requires a separate approved action; no token or key material belongs in Git. SMTP/domain/redirect, account/data deletion orchestration and Planet retention/legal decisions also remain beta gates.
