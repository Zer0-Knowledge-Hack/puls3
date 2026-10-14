# Design: Feedback end to end on testnet through the server (#179)

## Technical Approach

Settlement status is derived on read from confirmed `release`/`claimRefund` submissions (approach A, no migration). Relay exhaustion is labelled when the record is failed, at the single moment we know it is the 3rd failure. The catalog degrades per agent on `list` only. Registry feedback is not bound to a hire, so `Feedback.hireId` becomes nullable. A testnet script proves F7. Docs record unfiltered reads (D5) and the D6 wording.

## Architecture Decisions

| # | Topic | Choice | Rejected (tradeoff) |
|---|---|---|---|
| D1 | Who writes `EscrowCallFailed` | Whoever fails the record (sender on `submissionRejected` at send, tracker on `transactionFailed`/`preparationExpired`/`submissionRejected` at resend) asks one pure function `escrowCallFailureCode(priorFailures, code)`: returns `EscrowCallFailed` when `priorFailures + 1 >= maxEscrowCallAttempts`, else `code`. Sender passes its already-computed `failed` count. Tracker counts failed `listByHire` rows with the same purpose, excluding the current record, only for `release`/`claimRefund`. | Sender only (misses chain failures, which are the common case). A 4th "marker" record (no envelope to insert, breaks `escrowSubmission` = current attempt). Rewriting a failed record (transitions are `submitted`-only by design). |
| D2 | Counting "3 failed attempts" | Attempts = `failed` records of that hire + purpose, any failure code. Preparation errors before insert are not attempts. The sender's existing `failed >= 3` stop is kept. | Counting `sendAttempts` (counts resends of one envelope, not attempts). |
| D3 | `_effectCodes` | Not widened. `EscrowCallFailed` goes through `markFailed` (`checkOutcomeCode` already accepts it); release/refund have no `EscrowEffects` hook under approach A. | Widening it with an `onReleased` effect (approach B, which needs a migration). |
| D4 | Status derivation | `ServerpodHireRepository` gets one private `_settlement(hireId, {transaction})`: `findFirstRow` on `chain_submission` where `hireId`, `state = confirmed`, `purpose IN (release, claimRefund)`, uses `chain_submission_hire_idx`. Applied only over a funded hire: `_row` maps release => `completed`, claimRefund => `expired`; `findById` replays `funded.submit().complete()` / `funded.expire()` after the run replay, so `HireRow` and domain `Hire` agree. Release wins if both exist (impossible on chain). | Persisted status column + effects (migration, generated protocol). Reading `get_job` per read (RPC per read). |
| D5 | Derivation cost and idempotency | +1 indexed query per hire read; `listWithJob` pages (20) cost +20 queries per deadline pass, negligible beside the per-hire `get_job` RPC. Pure function of final rows (`confirmed` never changes), so it is idempotent and safe under concurrent trackers. | Caching (stale status after confirm). |
| D6 | 4a catalog isolation | `ReputationCatalogReader.list` catches `AgentCatalogUnavailable` per agent and returns that agent's inner summary unchanged (wire defaults 4.0 / 0). `get(id)` keeps throwing: one agent, retriable, and F7-6 must not show a fake rating after rating. | Dropping the agent (hides supply). Nullable `rating` (protocol change). Degrading `get` (masks a failed F7 refresh). |
| D7 | 4b hireId | `Feedback.hireId` becomes `HireId?`; null means a registry record not bound to a puls3 hire (D5). `SorobanReputationRegistry` passes null. `SubmitFeedback.matchesHire` and `Hire.recordFeedback` compare with `==`, so null never matches: `FeedbackDoesNotMatchHire`. Pure Dart, ADR-0001 rule holds. | `RegistryFeedback` read model: cleaner, but changes the `ReputationRegistry` port and `reputationOf`, ripples into ~10 files (contract suite, fakes, tools). Revisit with the D5 filter. |
| D8 | F7 script | `puls3_server/tool/e2e_feedback_testnet.dart`, same shape as `e2e_relay_testnet.dart` (Serverpod test-mode session, real wiring, real tracker). Input: a funded hire id from that script. Steps: agent signs `submit` directly (fixture, `PULS3_E2E_AGENT_SECRET`; the server path is out of scope), wait for `approval_deadline`, run `EscrowDeadlineRunner` + tracker until release `confirmed`, assert `getHire` = `completed`, `prepareFeedback` / sign / `submitFeedback`, tracker until `giveFeedback` confirmed, assert `feedbackReference` and `AgentEndpoint.get` rating. Testnet passphrase only; secrets read from env, never printed. Prints tx hashes. | Unit-testing the tool (it is an ops proof, like the relay script). |
| D9 | Docs | ADR-0005 D5: implementation note (reads unfiltered for the MVP, risk, follow-up). D6: note that a rated hire is `completed` + `feedbackReference` (supersedes "Rated" in #21). `api.md`: lines 143-146 (derived `completed`/`expired`, 3rd failure = `EscrowCallFailed`), 266 (unfiltered + per-agent degradation), 460 (prerequisite resolved for release). | — |

## Data Flow

    deadline pass -> RelayEscrowCallSender --insert/markFailed(code')--> chain_submission
    tracker pass  -> lookup -> markConfirmed | markFailed(code') ------> chain_submission
                                    code' = escrowCallFailureCode(prior, code)
    getHire / FeedbackService -> ServerpodHireRepository._row
         -> payment row + _settlement() -> completed | expired | funded

## File Changes

| File | Action | Description |
|---|---|---|
| `puls3_server/lib/src/chain/escrow_deadline.dart` | Modify | `maxEscrowCallAttempts` moves here (pure file) + `escrowCallFailureCode`, so the tracker does not import the sender's Stellar/hire dependencies |
| `puls3_server/lib/src/chain/escrow_server_submit.dart` | Modify | sender uses `escrowCallFailureCode` in both `markFailed` calls; constant removed (it already imports `escrow_deadline.dart`) |
| `puls3_server/lib/src/chain/chain_submission_tracker.dart` | Modify | `_fail` relabels relay purposes; doc comment |
| `puls3_server/lib/src/hire/serverpod_hire_repository.dart` | Modify | `_settlement`, `_row`, `findById` |
| `puls3_server/lib/src/hire/hire_lifecycle_store.dart` | Modify | `HireRow.status` doc |
| `puls3_server/lib/src/agent/reputation_catalog_reader.dart` | Modify | per-agent isolation in `list` |
| `puls3_domain/lib/src/entities.dart` | Modify | `HireId? hireId` + doc |
| `puls3_server/lib/src/ledger/soroban_reputation_registry.dart` | Modify | `hireId: null`, doc |
| `puls3_server/tool/e2e_feedback_testnet.dart` | Create | F7 proof |
| `docs/adr/0005-*.md`, `docs/architecture/api.md` | Modify | D9 |

## Interfaces / Contracts

```dart
/// [code], or EscrowCallFailed when this failure exhausts the attempts.
String escrowCallFailureCode({required int priorFailures, required String code});
```

## Testing Strategy (strict TDD, RED first)

| Layer | What | Where |
|---|---|---|
| Unit | `escrowCallFailureCode` 0/1/2 prior | `test/unit/chain/escrow_deadline_test.dart` |
| Unit | sender: 3rd `submissionRejected` => `EscrowCallFailed`; 1st/2nd keep code | same |
| Unit | tracker: 3rd `transactionFailed`/`preparationExpired` release => `EscrowCallFailed`; `fund` unaffected | `test/unit/chain/chain_submission_tracker_test.dart` |
| Integration (DB) | confirmed release => `completed`; claimRefund => `expired`; failed/submitted release => `funded`; `findById` agrees | `test/integration/hire_repository_test.dart`, `hire_lifecycle_store_test.dart` |
| Integration (DB) | `FeedbackService.eligibility` true on derived `completed` | `test/integration/` (new case) |
| Unit | `list` keeps all agents when one fails; `get` still throws | `test/agent/reputation_catalog_reader_test.dart` |
| Unit | null `hireId` => `FeedbackDoesNotMatchHire`; registry returns null `hireId` | `puls3_domain/test/feedback_test.dart`, `test/unit/ledger/soroban_reputation_registry_test.dart` |
| E2E | F7 script | manual testnet run (ops) |

## PR Slices (400-line budget)

| Slice | Content | Est. lines |
|---|---|---|
| PR1 | D1-D5 + tests | ~300 |
| PR2 | D6-D7 + tests | ~110 |
| PR3 | D8-D9 | ~250 |

Total ~660: 3 chained PRs, each under 400.

## Threat Matrix

N/A: no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. The tool reads secrets from env, testnet only.

## Migration / Rollout

No migration required. Revert restores null/open/funded derivation.

## Open Questions

- [ ] Testnet `approval_deadline` window length bounds the F7 run time (script waits; confirm config).
