# Exploration: 101-tracker-correctness

Scope: PR 1 of 2 for issue #101, correctness items only, against `origin/main` b65c62e.
Engram: `sdd/101-tracker-correctness/explore` (id 553).

## Findings per item

### 1. NOT_FOUND past `validUntil`
- `_notFound` in `chain_submission_tracker.dart` fails the record as `PreparationExpired` once chain time passes `validUntil`.
- After an outage longer than the RPC retention window, a confirmed transaction also answers NOT_FOUND, so a confirmed `fund` can be failed. `PreparationExpired` lets `prepareFund` run again while funds already moved.
- `SubmissionOutcomeCode` has 6 codes, enforced by `isKnown` and the store's `checkOutcomeCode`. A new code touches the enum, the store check, `docs/architecture/api.md`, the `.spy.yaml` comment and `submission_values_test`.
- `EscrowJobReader.escrowJob(jobId)` returns null for a missing job. `fund` has a job id, so it can reconcile; `createJob` has no job id before its event, so it cannot.

### 2. Only the first matching event reaches the effects
- `_first` in `escrow_events.dart` already skips malformed and foreign-contract events. Malformed-then-valid and other-contract-first are covered by tests.
- Real gap: several valid `job_created` / `job_funded` events in one transaction deliver only the first.

### 3. `complete`, `reject`, `registerFull` on SUCCESS
- They fall to `default` in `_succeeded`, stay `submitted`, and the relay rejects every later prepare with `SubmissionInProgress`.
- Minimal fix: confirm with no domain effect, like `release` / `claimRefund`.
- Existing tests pin the old behavior and must be rewritten first: `chain_submission_tracker_test.dart` (~L594, L632, L706, L778, L813) and `escrow_relay_submit_test.dart` (L678-725).
- Caveat: the hire status does not change until #97, so the app may offer `prepareComplete` again; the contract then rejects it as `TransactionFailed`.
- `setAgentWallet` and `submit` keep their own codes and stay out of scope.

### 4. `sendTransaction` expected hash
- Reached through `SorobanSubmissionLedger.resend`, `escrow_relay_service._send`, `studio_deploy_service._send`, `tool/e2e_feedback_testnet.dart` and `escrow_server_submit.dart`.
- Approach: pass the stored `transactionHash` and throw `LedgerUnavailable` on mismatch. This changes `SubmissionLedger.resend` and every fake.

### 5. SUCCESS without a parsable event
- A null event goes straight to `JobEvidenceUnavailable`. The store has no attempt counter column.

## Open decisions (pending, asked to the user)
1. Item 1: A2+A1 (reconcile `fund` through `get_job`, plus a distinct `OutcomeUnknown` code for `createJob`), or A1 alone.
2. Item 2: with several valid events, fail with `JobEvidenceUnavailable`, take the first, or match by submission.
3. Item 3: accept confirm-with-no-effect and the documented "can be offered again" caveat.
4. Item 5: in-memory counter or persisted column.

Item 4 is a design detail (pass the stored hash) and is settled in the design phase.

## Resolved decisions (user, after exploration)
Item 1: A2 + A1. Item 2: match by submission. Item 3: accepted. Item 5: in-memory.

## Pending after proposal (asked to the user)
- Is `prepare...` allowed after `OutcomeUnknown`? (`escrow-relay` spec L294-298 allows it only after `SubmissionRejected` or `PreparationExpired`.)
- The estimate is 420-480 changed lines against the 400-line budget: `size:exception` or split into two PRs.
