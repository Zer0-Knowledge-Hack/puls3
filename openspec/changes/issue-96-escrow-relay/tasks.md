# Tasks: Escrow relay prepare and submit endpoints (#96)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 2,000-2,800 (about 1,100-1,300 authored, rest tests, fixtures, generated protocol and migration) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes (overridden by user) |
| Suggested split | Single PR with `size:exception`; 7 commits ordered for review |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No (P1-P6 confirmed by the user; `size:exception` chosen, single PR)
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units (one commit each, same PR)

| Unit | Goal | Focused test command | Runtime harness | Rollback boundary |
|------|------|----------------------|-----------------|-------------------|
| C1 | Spike, vectors, dependency | `dart test test/spike` | testnet vectors | pubspec, spike, fixtures |
| C2 | Doc reconciliation | N/A docs | N/A | docs only |
| C3 | Protocol + migration | `dart test test/protocol` | `serverpod generate` | models, migration |
| C4 | Codec + RPC | `dart test test/ledger` | golden vectors | `ledger/` |
| C5 | Stores + claim tx | `dart test test/hire --tags integration` | Postgres | `hire/` stores, chain store |
| C6 | Services | `dart test test/hire` | fakes | services, effects |
| C7 | Endpoint, seam, wiring | `dart test` | seam test | endpoint, README |

## Confirmed by the user (P1-P6; dependent tasks reference these IDs)

- **P1** `EnvelopeMismatch.details.field` = contract, function, arguments, source, timeBounds, other (fee, sequence, Soroban data, memo, envelope type). Reconciles spec (`time_bounds`) and design (source/fee/sequence/...).
- **P2** New config, no code defaults: `PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS`, `PULS3_STELLAR_INCLUSION_FEE_STROOPS`, `PULS3_PLATFORM_FEE_BPS` (must equal `NetworkConfig.platformFeeBps`).
- **P3** `prepareFund` without USDC balance -> `ChainUnavailable`, `details.reason = simulationFailed`, no new code.
- **P4** Repeated submit after `validUntil` -> `PreparationExpired` (api.md literal).
- **P5** `create_job` `description` = empty string.
- **P6** Fix api.md ~66 (`prepareCreateJob` needs null status) and sidecar mentions (api.md ~133, 421, 451; ADR-0003 lines 37, 70 via dated amendment; ADR-0001 line 127).

## C1: Spike (all in `puls3_server`)

- [x] 1.1 RED: `test/spike/envelope_spike_test.dart` decode/re-encode, hash, ed25519 verify against `test/fixtures/escrow_relay/*.json` (recorded create_job and fund vectors). Covers: Spike passes/fails, Golden vectors.
- [x] 1.2 GREEN: add `stellar_dart` (or `crypto` + ed25519 fallback) in `pubspec.yaml`; record result in test header. Outcome: stellar_dart 2.3.0 passed decode/re-encode, network hash, and ed25519 verify; fallback not needed. Fixtures: `test/fixtures/escrow_relay/get_transaction_{create,fund}_job_3_xdr.json` (real testnet `envelopeXdr`, fetched read-only).

## C2: Doc reconciliation (depends on 1.2, P6)

- [x] 2.1 Fix `docs/architecture/api.md` line ~66 and sidecar lines ~133, 421, 451 (P6).
- [x] 2.2 Dated amendment in `docs/adr/0003-payment-rail-and-custody.md` (lines 37, 70); fix `docs/adr/0001-system-architecture.md` line 127.
- [x] 2.3 Align `specs/escrow-relay/spec.md` and `design.md` field names to final P1 (`time_bounds` vs `timeBounds`, `other`).

## C3: Protocol and migration

- [ ] 3.1 RED: protocol round-trip tests in `test/protocol/` for `Puls3ApiException`, `PreparedTransaction`, `CreateHireResult`, `HireDetail`.
- [ ] 3.2 GREEN: create the four `lib/src/protocol/*.spy.yaml` models, `lib/src/hire/escrow_preparation.spy.yaml`; modify `lib/src/hire/hire.spy.yaml` (`requestId?`, `input?`, `jobId?`, unique indexes).
- [ ] 3.3 Run `serverpod generate` and `serverpod create-migration`; commit `migrations/<ts>/`.

## C4: Codec and RPC (P1, P2)

- [ ] 4.1 RED: `test/ledger/envelope_codec_test.dart`, one test per field/reason: malformed (empty, non-base64, truncated, trailing, fee-bump), mismatch contract/function/arguments/source/timeBounds/other (P1), signature missing/wrongSigner/doesNotVerify, non-SOURCE_ACCOUNT auth. Covers: Malformed, Body differs x6, Unsigned, Signed by another key, Signature does not verify.
- [ ] 4.2 GREEN: `lib/src/ledger/envelope_codec.dart` port + adapter file (build, parse, firstDifference, verify).
- [ ] 4.3 RED/GREEN: `lib/src/ledger/soroban_rpc_client.dart` `getLedgerEntries` (sequence) and base64 simulate; tests with recorded responses.
- [ ] 4.4 RED/GREEN: `lib/src/hire/chain_accounts.dart` port + adapter, ChainUnavailable on failure (P3 `simulationFailed`).

## C5: Preparation store and claim

- [ ] 5.1 RED: integration test: conditional-UPDATE race prepare vs submit; claim 0 rows -> superseded; `ChainSubmissionConflict` re-read. Covers: Superseded, Concurrent submits.
- [ ] 5.2 GREEN: `lib/src/hire/escrow_preparation_store.dart` + Serverpod impl; add optional `Transaction?` to `lib/src/chain/serverpod_chain_submission_store.dart`.

## C6: Services (P2-P5)

- [ ] 6.1 RED: `test/hire/escrow_relay_service_test.dart` with port fakes: prepare fund/complete/reject, config missing (P2, no literal defaults), `SubmissionInProgress`, `PaymentAlreadySubmitted`, `InvalidHireTransition`, `InvalidRejectReason`, supersession reuses sequence, `prepareFund` no balance (P3), `description` empty (P5). Covers: Prepare, Preparation validity, One in flight.
- [ ] 6.2 RED: submit order tests: ownership, `PreparationNotFound`, timeBounds/superseded expiry, repeated submit after validUntil (P4), verification before persistence, persist-then-send, RPC reject/unreachable never throw, repeat returns record, `complete`/`reject` stay `submitted`.
- [ ] 6.3 GREEN: `lib/src/hire/escrow_relay_service.dart`.
- [ ] 6.4 RED/GREEN: `createHire` returns `CreateHireResult` in `lib/src/hire/hire_service.dart`, `hire_lifecycle_store.dart`, `serverpod_hire_repository.dart`: requestId idempotency, `IdempotencyKeyReused`, per-wallet scope, prepare-first rollback.
- [ ] 6.5 RED/GREEN: real `onJobCreated` in `lib/src/hire/hire_escrow_effects.dart` (idempotent, job id bound once, jobMismatch).
- [ ] 6.6 REFACTOR: remove duplication across services; keep tests green.

## C7: Endpoint, seam, wiring

- [ ] 7.1 RED: `test/hire/hire_endpoint_test.dart` fake `SessionWallet`: every method calls `requireLogin` once first; `WalletMismatch`; not logged in. Covers: Seam enforced, Not logged in.
- [ ] 7.2 GREEN: `lib/src/hire/session_wallet.dart` (fail-closed `AuthenticationUnavailable`), `lib/src/hire/hire_endpoint.dart`, wire `lib/src/chain/chain_tracker_wiring.dart`.
- [ ] 7.3 Document the three config keys (P2) in `puls3_server/README.md`; run full `dart test` and `dart analyze`.
