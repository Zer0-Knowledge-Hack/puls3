# Apply progress: issue-96-escrow-relay

## Batch 1 (C1 Spike): tasks 1.1, 1.2 complete

- Spike outcome: stellar_dart 2.3.0 passes decode and byte-identical re-encode, network transaction hash, and ed25519 verification. Fallback not needed.
- Test: `cd puls3_server && dart test test/spike` -> 6 passed.
- Files: `puls3_server/test/spike/envelope_spike_test.dart`, `puls3_server/test/fixtures/escrow_relay/get_transaction_{create,fund}_job_3_xdr.json`, `puls3_server/pubspec.yaml`, root `pubspec.lock` (16 added lines).
- P1-P6 marked confirmed in `tasks.md`.
- Not committed; remaining: C2 to C7.
