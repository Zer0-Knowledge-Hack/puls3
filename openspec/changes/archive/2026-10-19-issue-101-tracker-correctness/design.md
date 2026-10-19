# Design: Chain submission tracker correctness (#101, PR 1 of 2)

## Technical Approach

All changes stay in `puls3_server` (no ADR-0001 boundary crossing). The tracker keeps its shape; hire-aware logic (event matching, fund reconciliation) lives in `EscrowEffects`, which already owns the hire repository and `EscrowJobReader`. One PR, `size:exception`, six commits in the order of "Work Units".

## Architecture Decisions

| # | Decision | Rejected alternative | Rationale |
|---|----------|----------------------|-----------|
| D1 | Expired-`fund` reconciliation is a new port method `EscrowEffects.reconcileExpiredFund(submission)`; `HireEscrowEffects` reads `hire.jobId`, calls its existing `EscrowJobReader`, and on `funded/submitted/completed/rejected` builds a `JobFundedEvent` from `EscrowJob` (`client`, `budget`, `feeBps`) and runs the existing `_fund`. | Inject `EscrowJobReader` into the tracker (proposal wording). | The tracker has no hire, so it cannot know the job id; marking `confirmed` without `_fund` would leave the hire `open` after funds moved and re-allow `prepareFund`. The decision "reconcile via the job reader" is kept; only the host changes. |
| D2 | Retention coverage comes from the lookup: `getTransaction` returns `oldestLedgerCloseTime` (present in fixtures). Covered iff `oldest <= submission.createdAt`. Fallback when absent: tracker param `rpcRetention`, `const defaultRpcRetention = Duration(hours: 24)` (Soroban RPC default 17280 ledgers); covered iff `chainNow - rpcRetention <= createdAt`. No env var (config is PR 2). | Fixed env-configured window only. | The node reports its own window; no operator guess. |
| D3 | Past `validUntil` + NOT_FOUND: `fund` -> reconcile (Landed -> effect result; NotLanded (job `open`) -> `PreparationExpired`; Unknown (no hire/jobId, job null or `expired`) -> retention rule). Other purposes -> retention rule. Retention rule: covered -> `PreparationExpired`, else `OutcomeUnknown`. | Only `createJob` gets `OutcomeUnknown`. | Any purpose can land unseen (duplicate `give_feedback` is harmful); one rule is simpler to test. |
| D4 | `EscrowRelayService._prepare` throws `Puls3ApiException('OutcomeUnknown')` when any hire record is `failed/OutcomeUnknown`, checked right after `SubmissionInProgress`. Covers every purpose including `prepareFeedback`. | Reuse `SubmissionInProgress`. | Distinct code tells operators it needs manual resolution. |
| D5 | Lookup carries `List<JobCreatedEvent> jobCreated`, `List<JobFundedEvent> jobFunded` (all valid escrow events, in order; `_first` -> `_all`). Effects take the lists. Match rule: `fund` -> `event.jobId == hire.jobId`; `createJob` -> `client`, `agentId`, `budget == hire.price`, `expiredAt == preparation.jobExpiredAt`. Exactly one match -> apply; zero or several -> `JobMismatch` (field `job_id`). Empty list -> D7. | Take the first; fail `JobEvidenceUnavailable` on several. | Matching is the user decision; ambiguity is not provable, and `JobMismatch` on `fund` keeps `_fundReachedChain` blocking re-funding. |
| D6 | `complete`, `reject`, `registerFull` join `release`/`claimRefund`: `markConfirmed`, no effect. `_untrackedPurposes` unchanged. | Wait for #97. | Unblocks `SubmissionInProgress`; caveat documented. |
| D7 | `final _missingEvents = <int, int>{}` keyed by submission id; `const evidencePasses = 3`. Empty list on SUCCESS for `createJob`/`fund`: passes 1-2 leave `submitted` (`summary.waiting++`, warning log), pass 3 fails `JobEvidenceUnavailable`; entry removed when the record settles. | Persisted column. | User decision; no migration; restart resets the count (documented). |
| D8 | `SorobanRpcClient.sendTransaction(envelopeXdr, expectedHash)` compares lowercase hex and throws `LedgerUnavailable` on mismatch; `SubmissionLedger.resend(envelopeXdr, expectedHash)` forwards. | Check in each caller. | Single enforcement point; every caller already treats `LedgerUnavailable` as "outcome unknown, stays submitted". |

## Data Flow

    pass -> lookup(hash) -> NOT_FOUND, past validUntil
             fund? -> effects.reconcileExpiredFund -> Landed(result) | NotLanded | Unknown
             Unknown/other -> covered(oldestLedgerCloseTime|rpcRetention, createdAt)
                               ? PreparationExpired : OutcomeUnknown
           -> SUCCESS -> lists empty? -> _missingEvents++ (fail at 3)
                       -> effects.onX(submission, list) -> match -> EffectResult

## Interfaces

```dart
sealed class ExpiredFund {}
final class ExpiredFundLanded extends ExpiredFund { final EffectResult result; }
final class ExpiredFundNotLanded extends ExpiredFund {}
final class ExpiredFundUnknown extends ExpiredFund {}
// TransactionLookup gains: DateTime? oldestLedgerCloseTime;
```
`NoopEscrowEffects.reconcileExpiredFund` returns `ExpiredFundUnknown`.

## File Changes

| File | Change |
|------|--------|
| `lib/src/ledger/soroban_rpc_client.dart` | `sendTransaction(xdr, expectedHash)` + mismatch |
| `lib/src/chain/submission_ledger.dart` | lists, `oldestLedgerCloseTime`, `resend(xdr, hash)` |
| `lib/src/ledger/soroban_submission_ledger.dart` | parse oldest; `jobCreatedEvents`/`jobFundedEvents` |
| `lib/src/ledger/escrow_events.dart` | `_first` -> `_all` returning lists |
| `lib/src/chain/escrow_effects.dart` | list params, `reconcileExpiredFund`, `ExpiredFund` |
| `lib/src/hire/hire_escrow_effects.dart` | matching, reconciliation |
| `lib/src/chain/chain_submission_tracker.dart` | D2, D3, D6, D7, D8; doc comment |
| `lib/src/chain/submission_values.dart` | `outcomeUnknown` in `all` (store `checkOutcomeCode` follows) |
| `lib/src/hire/escrow_relay_service.dart` | D4; `_send` passes `record.transactionHash` |
| `lib/src/studio/studio_deploy_service.dart` | `_send(xdr, hash)` at 3 call sites |
| `lib/src/chain/escrow_server_submit.dart` | `send` typedef gains hash; passes `record.transactionHash` |
| `tool/e2e_feedback_testnet.dart` | `resend(signed, prepared.hashHex)` |
| `lib/src/protocol/puls3_api_exception.spy.yaml` | `#` comment adds `OutcomeUnknown` (not emitted; no `serverpod generate`) |
| `docs/architecture/api.md`, `puls3_server/README.md` | catalog row, tracker table, caveats |
| `test/support/fake_submission_ledger.dart` | default send hash = `expectedHash`; record pairs |
| `test/support/fake_escrow_effects.dart` | lists + reconcile answer |

## Testing Strategy (strict TDD, RED first)

| Test file | Coverage |
|-----------|----------|
| `unit/ledger/soroban_rpc_client_test.dart` | mismatch throws; match (case-insensitive) passes |
| `unit/ledger/soroban_submission_ledger_test.dart` | resend forwards hash; lists; `oldestLedgerCloseTime` |
| `unit/ledger/escrow_events_test.dart` | several valid events all returned; malformed/foreign skipped |
| `unit/chain/chain_submission_tracker_test.dart` | rewrite pins (~L594, 632, 706, 778, 813) to confirm; reconcile 3 branches; covered vs uncovered; fallback window; 3-pass counter; resend hash |
| `unit/hire/hire_escrow_effects_test.dart` | one/zero/several matches; reconciliation per job state |
| `unit/chain/escrow_effects_test.dart`, `unit/chain/submission_values_test.dart` | Noop reconcile; 7 codes |
| `hire/escrow_relay_submit_test.dart` | rewrite L678-725; `OutcomeUnknown` blocks every prepare; `_ObservingLedger` |
| `unit/chain/escrow_server_submit_test.dart`, `studio/studio_deploy_service_test.dart` | `send`/`_Sender` hash |
| `integration/chain_submission_store_test.dart` | `markFailed(OutcomeUnknown)` accepted |

## Work Units (commits)

1. D8 hash check + every caller/fake. 2. D6. 3. D5 lists + matching. 4. D7. 5. D1-D4 + relay block. 6. Docs.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration; `errorCode` is free text checked in Dart. Rollback: reset `OutcomeUnknown` rows to `PreparationExpired` first.

## Open Questions

- [ ] App copy for the new `OutcomeUnknown` API code (frontend out of scope; falls back to generic error).
