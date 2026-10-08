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
