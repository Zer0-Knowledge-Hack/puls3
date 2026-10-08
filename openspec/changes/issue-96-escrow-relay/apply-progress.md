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

## Batch 4 (C4 Codec and RPC): tasks 4.1, 4.2, 4.3, 4.4 complete

- Mode: Strict TDD. size:exception, single PR (one commit per phase, parent commits). Not committed; remaining: C5 to C7.
- 4.1/4.2 RED: `test/ledger/envelope_codec_test.dart` (48 tests) and the new ScArg group in `test/unit/ledger/xdr_invoke_encoder_test.dart` failed to compile (codec files and ScArg members missing). GREEN: `dart test test/ledger/envelope_codec_test.dart` -> 48 passed; encoder test 14 passed.
- Codec: port + value types in `lib/src/ledger/envelope_codec.dart` (`EnvelopeCodec`, `EnvelopeSpec`, `SimulationData`, `PreparedEnvelope`, `SignedEnvelope`, `InvalidSignedEnvelope(reason: empty|notBase64|truncated|trailingBytes|feeBump)`, `UnsupportedAuthorization`, `SignatureCheck`, `EnvelopeField`); adapter `lib/src/ledger/stellar_envelope_codec.dart` (`StellarEnvelopeCodec.forPassphrase`). Body is hand-written XDR (PRECOND_TIME, seq = account + 1, fee = inclusion + minResourceFee) with the simulation transactionData and auth spliced as base64-decoded bytes; stellar_dart only decodes, hashes and verifies.
- `xdr_invoke_encoder.dart`: `_XdrWriter` made public `XdrWriter` (+ `raw`, `uint64`), new `encodeInvokeHostFunction`, new `ScArg.address/i128/voidValue` (needed to rebuild the real create_job and fund args).
- 4.3 RED: `test/ledger/soroban_rpc_client_relay_test.dart` (17 tests) failed to compile. GREEN: `accountSequence(StellarAddress)` (getLedgerEntries, null when the account is absent) and `simulateTransactionBase64` (returns `SimulationData`; contract error -> LedgerContractError, restorePreamble/other -> LedgerUnavailable). `contractErrorCode` helper moved to `ledger_errors.dart` and reused by `SorobanLedger`.
- 4.4 RED: `test/hire/chain_accounts_test.dart` (8 tests) failed to compile. GREEN: `lib/src/hire/chain_accounts.dart` (`ChainAccounts`: `sequenceOf`, `simulate(EnvelopeSpec)`; `RpcChainAccounts`). Every failure (absent account, node down, rejected simulation) -> `Puls3ApiException(ChainUnavailable, details.reason = simulationFailed)` per api.md and P3.
- Fixtures (all real read-only testnet answers recorded 2026-10-07, soroban-testnet.stellar.org): `get_ledger_entries_account.json`, `get_ledger_entries_missing_account.json`, `simulate_create_job_3_base64.json`, `simulate_fund_job_3_error_base64.json` (job 3 already funded -> Error(Contract, #2)). The fund Soroban data and auth for the build golden come from the recorded fund transaction because its fresh simulation fails. Negatives are derived by mutating real bytes (bit flips, stripped or duplicated signature, fee-bump wrap, added bytes, removed or added response fields); none invented.
- Findings: `Envelope.fromXdr` ignores trailing bytes (detected by comparing the re-encoded length) and reports truncation as RangeError; `toXDR()` of a bare ScVal/ScAddress/Preconditions fails in stellar_dart 2.3.0 so group comparison uses `toVariantLayoutStruct()`; a fresh create_job simulation has different Soroban data than the one recorded on chain (ledger moved), so the build golden compares with the simulation, not with the old transaction.
- Verification: `cd puls3_server && dart test test/unit test/protocol test/spike test/ledger test/hire` -> 389 passed (was 311); `dart analyze --fatal-infos` -> no issues; pubspec.lock restored (32/56 churn removed after every run).
- Deviation from design: `UnsupportedAuthorization` is a codec exception (service maps it to InternalError in C6) instead of the codec raising InternalError itself; `StellarEnvelopeCodec` takes a Stellar network passphrase (public, test or future) because stellar_dart has no custom network id.
