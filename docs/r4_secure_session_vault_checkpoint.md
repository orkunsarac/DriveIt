# R4 secure session vault checkpoint

Android callback cold/warm isolated emulator acceptance remains PASS as recorded in `r4_callback_shared_emulator_acceptance.md`; it is not a physical-device or real-email acceptance.

This checkpoint adds an Android `flutter_secure_storage` adapter and session serialization vault. The vault excludes provider credentials, rejects malformed session data and mismatched JWT subject/user id, and does not log credentials. Its JWT payload parsing is structural validation only, not signature verification or evidence of server authentication. Bad stored data is not automatically erased. Tests use an in-memory storage adapter and synthetic data: 2/2 PASS; targeted Dart analysis clean. Android keystore persistence and process restart were not tested.

Restore: NOT COMPLETE. The vault is not connected to app startup or the owner/GPS lifecycle. Refresh: NOT COMPLETE. No controlled refresh scheduler, session rotation or post-refresh scoped cloud/Planet acceptance was added. No production activation or feature gate was changed. These are outstanding implementation and test tasks, not an assertion of an external SDK limitation. Do not enable Play Auth based on this checkpoint.
