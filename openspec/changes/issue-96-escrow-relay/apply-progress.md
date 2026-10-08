# Apply progress: issue-96-escrow-relay

## Batch 1 (C1 Spike): tasks 1.1, 1.2 complete

- Spike outcome: stellar_dart 2.3.0 passes decode and byte-identical re-encode, network transaction hash, and ed25519 verification. Fallback not needed.
- Test: `cd puls3_server && dart test test/spike` -> 6 passed.
- Files: `puls3_server/test/spike/envelope_spike_test.dart`, `puls3_server/test/fixtures/escrow_relay/get_transaction_{create,fund}_job_3_xdr.json`, `puls3_server/pubspec.yaml`, root `pubspec.lock` (16 added lines).
- P1-P6 marked confirmed in `tasks.md`.
- Not committed; remaining: C2 to C7.

## Batch 2 (C2 Doc reconciliation): tasks 2.1, 2.2, 2.3 complete

- api.md: prepareCreateJob needs null-status hire (or createJob failed); sidecar text replaced with spike-passed + pure-Dart fallback (3 places); EnvelopeMismatch details.field (P1) and ChainUnavailable simulationFailed (P3) documented.
- ADR-0003 decision 5 and consequence amended 2026-10-07; ADR-0001 alternative 4 amended.
- spec.md and design.md aligned to P1 (timeBounds, other).
- Docs-only: structural rg checks used instead of tests. Not committed; remaining: C3 to C7.

## Batch 3 (C3 Protocol and migration): tasks 3.1, 3.2, 3.3 complete

- RED: `test/protocol/relay_protocol_test.dart` (8 tests) failed to compile (classes undefined). GREEN after generation: `dart test test/protocol` -> 8 passed.
- Models: protocol `puls3_api_exception`, `prepared_transaction`, `create_hire_result`, `hire_detail` plus `Hire` and `Payment` (copied from the docs drafts; HireDetail/CreateHireResult need them); `hire/escrow_preparation.spy.yaml`; `hire.spy.yaml` gains `requestId?`, `input?`, `jobId?`, unique indexes `(consumer, requestId)` and `jobId`.
- Name clash: protocol `Hire`/`Payment` collide with the domain entities; `serverpod_hire_repository.dart` now imports `protocol.dart hide Hire, Payment`. C6 files that import both must do the same.
- Generation: global CLI 3.4.13 (`~/AppData/Local/Pub/Cache/bin/serverpod.bat generate` / `create-migration --force`; `dart run serverpod_cli` does not resolve). `--force` needed only for the false-positive unique-index warning (new columns are all NULL).
- Migration `20261008012344930` (no DB needed). Unit+protocol+spike: 311 passed; `dart analyze` clean. pubspec.lock restored after each run.
- Not committed; remaining: C4 to C7.
