# Design: Escrow relay prepare and submit endpoints (#96)

## Technical Approach

Implement api.md Decision A in `puls3_server` with ports and adapters. The `hire/` services own the rules: state guards, idempotency, supersession, and the submit order. They depend on four server-local ports: `EscrowPreparationStore`, `EnvelopeCodec`, `ChainAccounts`, and `SessionWallet`. Adapters wrap Serverpod, Soroban RPC, and `stellar_dart` (or the pure-Dart fallback). `puls3_domain` does not change (ADR-0001 dependency rule). `api.md` is authoritative. Where `openspec/specs/hire-payment/spec.md` disagrees, the delta spec overrides it.

## Architecture Decisions

| # | Topic | Options | Decision and rationale |
|---|---|---|---|
| D1 | Preparation state | `escrow_preparation` table / HMAC token / columns on `hire` | **Table.** Supersession, lookup by `preparationId`, and "re-run verification" all need stored prepared bytes. A token cannot be superseded. |
| D2 | Supersession and race control | Hire pointer with CAS / row locks / flags on the preparation row | **`supersededAt` and `submittedAt` on the preparation, changed only by conditional UPDATEs.** Postgres row locks order `prepare` (`SET supersededAt WHERE hireId=? AND supersededAt IS NULL AND submittedAt IS NULL`) against `submit` (`SET submittedAt WHERE id=? AND supersededAt IS NULL`). Exactly one of them wins, and no explicit lock API is needed. |
| D3 | Atomic claim and record | Separate `insertSubmitted` / one transaction | **One DB transaction:** claim the preparation, then `insertSubmitted`. `ServerpodChainSubmissionStore` gains an optional `Transaction?`. On `ChainSubmissionConflict(preparation)` the transaction is rolled back and the service re-reads `findByPreparation`, so a concurrent identical submit returns that record. A conflict on `transaction` is an `InternalError`. |
| D4 | Envelope build | Extend `xdr_invoke_encoder` / codec | **`EnvelopeCodec.build`** writes `PRECOND_TIME` (minTime 0, maxTime = validUntil), `seq = account.seqNum + 1`, `fee = inclusionFee + minResourceFee`, and splices `transactionData` and `results[0].auth` from `simulateTransaction` as base64 XDR without decoding them. The builder rejects auth entries that are not `SOURCE_ACCOUNT` (`InternalError`). |
| D5 | `EnvelopeMismatch` | Decode and compare / byte equality | **Compare body bytes** (the `Transaction` slice of `ENVELOPE_TYPE_TX`). Only on inequality does a field-offset walk name the first differing field for `details.field`: `source`, `fee`, `sequence`, `timeBounds`, `memo`, `operations`, `sorobanData`, or `envelopeType` (for a v0 envelope). |
| D6 | `InvalidSignedEnvelope` | — | Raised for empty input, non-base64 input, a truncated envelope, trailing bytes after `signatures`, or `ENVELOPE_TYPE_TX_FEE_BUMP`. |
| D7 | Hash and signature | — | `hash = sha256(sha256(passphrase) ‖ uint32(2) ‖ txBytes)`. The signature must be exactly one `DecoratedSignature`: 0 signatures give `missing`; a hint other than the signer key's last 4 bytes, or more than one signature, gives `wrongSigner`; a failed ed25519 check gives `doesNotVerify`. Equal body bytes imply hash equals `preparation.transactionHash`. |
| D8 | Crypto library | `stellar_dart` / crypto+ed25519+hand XDR / TS sidecar | **`stellar_dart` gated by a spike.** The fallback is `package:crypto` plus a pure-Dart ed25519 package with hand-written XDR (a `_XdrReader` next to the existing `_XdrWriter`). **No TypeScript sidecar** (confirmed decision). The `EnvelopeCodec` port isolates the choice. |
| D9 | Session | Serverpod auth now / seam | **`SessionWallet.requireLogin(Session) → StellarAddress`**, injected with the static `@visibleForTesting` setter pattern of `AgentEndpoint`. The production binding until #25 fails closed with `AuthenticationUnavailable`. |
| D10 | Hire lifecycle data | Change the domain port / server port | **Server port `HireLifecycleStore`** handles `requestId`, `input`, `jobId`, and the projection where status is null until a job id exists. The domain `Hire` and `HireRepository` stay unchanged. Wire `status` is null while `hire.jobId` is null, `open` once it is set, and `funded` once a payment exists. |
| D11 | createHire | Insert first / prepare first | **Prepare first** (simulate), **then insert the hire and the preparation in one transaction.** A unique violation on `(consumer, requestId)` re-runs the idempotent lookup. Same `agentId` and `input` return the existing hire with its current unexpired `createJob` preparation, a fresh one, or null once a `createJob` is submitted or confirmed. Anything else raises `IdempotencyKeyReused`. If the preparation fails, nothing is persisted. |
| D12 | `onJobCreated` | — | Inside the repository scope, set `hire.jobId = event.jobId` and `hire.expiredAt = preparation.jobExpiredAt` (the confirmed preparation, located through `submission.preparationId`). The operation is idempotent: the same job id returns ok. A missing hire or preparation violates an invariant and throws; the tracker logs and retries it. `createJob` has no `JobMismatch` code in api.md. |
| D13 | Send outcomes | — | After the claim, `sendTransaction`: `PENDING`/`DUPLICATE` → `recordSend`; `TRY_AGAIN_LATER` or `LedgerUnavailable` → stays `submitted`; `ERROR` or `RpcRequestRejected` → `markFailed(SubmissionRejected)`. Submit never throws for chain outcomes. |
| D14 | Config, with no code defaults | — | New keys: `PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS`, `PULS3_STELLAR_INCLUSION_FEE_STROOPS`, and `PULS3_PLATFORM_FEE_BPS` (the `max_fee_bps` value, 0..1000). The job duration keeps the existing `PULS3_HIRE_JOB_DURATION_SECONDS`. A missing or invalid key raises `ConfigurationUnavailable`. |

## Data Flow

```
createHire/prepareX ─▶ guard(state, SubmissionInProgress, PaymentAlreadySubmitted)
   └▶ ChainAccounts.seq ─▶ EnvelopeCodec.build ◀─ simulateTransaction(base64)
   └▶ tx{ supersede current ; insert escrow_preparation } ─▶ PreparedTransaction

submitEscrowCall:
 requireLogin → hire (InvalidHireId/NotFound/NotOwned) → preparation (NotFound: id/hire/signer)
 → superseded? / now ≥ validUntil? (PreparationExpired) → state guard by purpose
 → codec.parse → body bytes == prepared? → signature → findByPreparation ─(hit)→ HireDetail
 → tx{ claim submittedAt ; insertSubmitted } ─(0 rows)→ PreparationExpired(superseded)
 → sendTransaction → recordSend | markFailed(SubmissionRejected) | leave submitted → HireDetail

Tracker: createJob SUCCESS → HireEscrowEffects.onJobCreated → hire.jobId, expiredAt
```

## File Changes

| File | Action | Description |
|---|---|---|
| `puls3_server/pubspec.yaml` | Modify | `stellar_dart`, or `crypto` plus ed25519 (from the spike) |
| `puls3_server/test/spike/envelope_spike_test.dart`, `test/fixtures/escrow_relay/*.json` | Create | Spike and golden vectors |
| `lib/src/hire/escrow_preparation.spy.yaml` | Create | `preparationId` (unique), `hireId` (index), `purpose`, `signer`, `unsignedEnvelopeXdr`, `transactionHash`, `sequence`, `validUntil`, `jobExpiredAt?`, `rejectReason?`, `createdAt`, `supersededAt?`, `submittedAt?` |
| `lib/src/hire/hire.spy.yaml` | Modify | `requestId?`, `input?`, `jobId?` (unique). Unique `(consumer, requestId)`. Nullable because rows may already exist |
| `lib/src/protocol/*.spy.yaml` (`puls3_api_exception`, `prepared_transaction`, `create_hire_result`, `hire_detail`) | Create | Wire models from the api.md drafts |
| `migrations/<ts>/` | Create | Generated by `serverpod create-migration` |
| `lib/src/ledger/envelope_codec.dart` (+ `stellar_envelope_codec.dart` or `xdr_envelope_codec.dart`) | Create | Port plus adapter: build, parse, hash, verify, mismatch field |
| `lib/src/ledger/soroban_rpc_client.dart` | Modify | `getLedgerEntries` (account sequence), base64 simulation variant |
| `lib/src/hire/chain_accounts.dart`, `escrow_preparation_store.dart` (+ Serverpod impls) | Create | Ports and adapters |
| `lib/src/chain/serverpod_chain_submission_store.dart` | Modify | Optional `Transaction?` on `insertSubmitted` |
| `lib/src/hire/escrow_relay_service.dart` | Create | `prepare*`, `submitEscrowCall` orchestration |
| `lib/src/hire/hire_service.dart`, `hire_lifecycle_store.dart`, `serverpod_hire_repository.dart` | Modify/Create | `createHire` returns `CreateHireResult` |
| `lib/src/hire/hire_escrow_effects.dart`, `chain/chain_tracker_wiring.dart` | Modify | Real `onJobCreated` |
| `lib/src/hire/hire_endpoint.dart`, `session_wallet.dart` | Create | `HireEndpoint` and the seam |
| `docs/architecture/api.md`, `docs/adr/0003-…md`, `docs/adr/0001-…md`, `puls3_server/README.md` | Modify | Sidecar reconciliation and new config keys |

## Interfaces / Contracts

```dart
abstract interface class EnvelopeCodec {
  PreparedEnvelope build(EnvelopeSpec spec, SimulationData sim); // body bytes + hash
  SignedEnvelope parse(String base64); // throws InvalidSignedEnvelope(reason)
  String? firstDifference(Uint8List preparedBody, Uint8List signedBody);
  SignatureCheck verify(SignedEnvelope e, StellarAddress signer, Uint8List hash);
}
abstract interface class SessionWallet { Future<StellarAddress> requireLogin(Session s); }
```

## Testing Strategy (Strict TDD, RED first)

| Layer | What | Approach |
|---|---|---|
| Spike gate | `stellar_dart` decodes the recorded signed testnet envelope and re-encodes it byte-identically, the hash equals the on-chain hash, ed25519 verifies, and the build with spliced sim data is stable | Pass → adapter on `stellar_dart`. Any fail → fallback, recorded in the docs |
| Golden vectors | Recorded `create_job` and `fund` pairs (unsigned, signed, passphrase, hash, signer) plus derived negatives: tampered fee, sequence, or time bounds, a trailing byte, a fee-bump wrap, no signature, a foreign signer, a corrupted signature | Codec unit tests, one per `details.field` and `details.reason` |
| Unit | Every api.md error code of the six methods; submit order; supersession; `SubmissionInProgress`; `PaymentAlreadySubmitted`; send outcomes; config without defaults; `complete`/`reject` stay `submitted` (#97 pin) | Fakes for every port |
| Integration | Conditional-UPDATE race (prepare vs submit), `ChainSubmissionConflict` re-read, `(consumer, requestId)` race, migration | `withServerpod` against Postgres |
| Seam | Every `HireEndpoint` method calls `requireLogin` and rejects another wallet | Fake `SessionWallet` |

## Threat Matrix

N/A: no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. Rejecting the sidecar removes the only subprocess candidate.

## Migration / Rollout

One additive Serverpod migration: a new `escrow_preparation` table and nullable `hire` columns with unique indexes. Rollback is a PR revert plus dropping the table and columns. Single PR with `size:exception`, ordered commits:
1. Spike, golden vectors, dependency.
2. Doc reconciliation (wording depends on the spike result).
3. Protocol models and migration.
4. `EnvelopeCodec` and RPC additions.
5. Preparation store and claim transaction.
6. Relay service, `createHire`, `onJobCreated`.
7. `HireEndpoint`, `SessionWallet`, wiring, README.

**Doc reconciliation (flagged):** `docs/architecture/api.md` line 133, line 421, and line 451, `docs/adr/0003-payment-rail-and-custody.md` lines 37 and 70, and `docs/adr/0001-system-architecture.md` line 127 still name the TypeScript sidecar as the fallback. Proposal: replace that text with "pure-Dart fallback: `package:crypto` plus an ed25519 package with hand-written XDR, behind the same adapter". For ADR-0003, add a dated amendment note instead of rewriting the decision.

## Open Questions

- [ ] api.md line 66 says that `prepareCreateJob` needs `open`, but the state table (line 182) and the confirmed decision use null status. The design follows null and proposes fixing line 66.
- [ ] Simulating `fund` without a USDC balance fails. `prepareFund` has no catalog code for this case other than `ChainUnavailable`. Do we map it, or add a code?
- [ ] A repeated submit after `validUntil` re-runs the expiry check (api.md "re-runs step 3") and raises `PreparationExpired`, even though a record exists. The design applies api.md as written.
- [ ] `create_job` `description`: its content is not documented. The design uses an empty string unless the spec fixes it.
- [ ] The source of `PULS3_PLATFORM_FEE_BPS` must match `ConfigEndpoint.getNetworkConfig` once that endpoint exists.
