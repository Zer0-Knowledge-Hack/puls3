# Proposal: Chain submission tracker correctness (#101, PR 1 of 2)

## Intent

`ChainSubmissionTracker` can record wrong outcomes: a landed `fund` failed as `PreparationExpired` after an RPC outage (re-prepare while funds moved), extra valid events ignored, `complete`/`reject`/`registerFull` stuck `submitted` forever, an unchecked resend hash, and one-shot `JobEvidenceUnavailable`. Fix correctness only.

## Scope

### In Scope
1. Expired `fund`: reconcile via `EscrowJobReader` (job `Funded` or later = landed). New `OutcomeUnknown` when past `validUntil`, past RPC retention, and unreconcilable (`createJob`). Update enum, store check, `docs/architecture/api.md`, `.spy.yaml` comment, `submission_values_test`.
2. Lookup carries all valid `job_created`/`job_funded` events; tracker/effects pick the one matching the submission (job id / hire binding).
3. `complete`, `reject`, `registerFull` SUCCESS -> `confirmed`, no domain effect. Caveat documented in README tracker paragraph and tracker doc comment.
4. `sendTransaction(envelopeXdr, expectedHash)` throws `LedgerUnavailable` on mismatch; `SubmissionLedger.resend` and fakes follow.
5. SUCCESS without parsable event: 3 attempts (one per pass), in-memory counter, lost on restart (documented).

### Out of Scope
- Backoff, pacing, `TrackerLoopConfig` ordering, ledger types into ports, log wording, README stderr line (PR 2).
- `setAgentWallet`/`submit` tracking; #97 domain effects.

## Capabilities

### New Capabilities
- `chain-submission-tracking`: tracker outcomes for NOT_FOUND/expiry, event matching, SUCCESS without event, resend hash check.

### Modified Capabilities
- `escrow-relay`: "Settlement of complete and reject depends on #97" changes to confirm-without-effect; re-prepare scenarios gain `OutcomeUnknown`.
- `soroban-rpc-ledger-adapter`: `sendTransaction` verifies the expected hash.

## Approach

Strict TDD per item; rewrite pinning tests first (`chain_submission_tracker_test` ~L594-813, `escrow_relay_submit_test` L678-725). Item 1 injects `EscrowJobReader` into the tracker. Item 2 changes `TransactionLookup` to lists. Item 5 keeps a `Map<hash,int>` in the tracker. No DB migration. No ADR-0001 domain boundary crossing (all in `puls3_server`); `OutcomeUnknown` touches the protocol `.spy.yaml` comment and generated client only if regenerated.

## Affected Areas

| Area | Impact |
|------|--------|
| `puls3_server/lib/src/chain/chain_submission_tracker.dart` | Modified |
| `.../ledger/submission_ledger.dart`, `soroban_submission_ledger.dart`, `escrow_events.dart` | Modified |
| `.../soroban_rpc_client.dart` + callers (`escrow_relay_service`, `studio_deploy_service`, `escrow_server_submit`, `tool/e2e_feedback_testnet.dart`) | Modified |
| Outcome enum, store check, `.spy.yaml` | Modified |
| `docs/architecture/api.md`, `README.md` | Modified |
| Tests (tracker, relay submit, events, values, fakes) | Modified |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Re-prepare policy after `OutcomeUnknown` not decided | Med | Resolve in spec; default must not allow silent re-prepare |
| `prepareComplete` re-offered until #97 | High (accepted) | Documented; contract rejects as `TransactionFailed` |
| Counter lost on restart | Low (accepted) | Documented |
| Exceeds 400-line budget | Med | See estimate |

## Size Estimate

~420-480 changed lines (item1 ~140, item2 ~90, item3 ~70, item4 ~70, item5 ~50, docs ~25). Likely over 400. Recommendation: keep single PR with an explicit `size:exception`; fallback split items 3+4+5 / 1+2.

## Rollback Plan

Revert the PR commit. No migration; `OutcomeUnknown` rows (if any) need a manual reset to `failed/PreparationExpired` before reverting.

## Success Criteria

- [ ] Landed expired `fund` confirms; unreconcilable `createJob` yields `OutcomeUnknown`.
- [ ] Multi-event, malformed-then-valid, other-contract-first tests pass.
- [ ] `complete`/`reject`/`registerFull` confirm with no hire change.
- [ ] Hash mismatch raises `LedgerUnavailable`.
- [ ] Missing event fails only after 3 passes.
- [ ] `dart analyze --fatal-infos` and `dart test` green.
