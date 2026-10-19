# Tasks: Chain submission tracker correctness (#101, PR 1 of 2)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 420-480 (U1 ~90, U2 ~30, U3 ~110, U4 ~40, U5 ~130, U6 ~40) |
| 400-line budget risk | High |
| Chained PRs recommended | No (size:exception approved) |
| Suggested split | Single PR, six commits |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | D8 hash check, all callers/fakes | PR 1 commit 1 | `dart test test/unit/ledger test/unit/chain/escrow_server_submit_test.dart` | N/A: unit fakes only | revert commit 1 |
| 2 | D6 confirm complete/reject/registerFull | commit 2 | `dart test test/unit/chain/chain_submission_tracker_test.dart` | N/A | revert commit 2 |
| 3 | D5 event lists + matching | commit 3 | `dart test test/unit/ledger/escrow_events_test.dart test/unit/hire/hire_escrow_effects_test.dart` | N/A | revert commit 3 |
| 4 | D7 three-pass evidence counter | commit 4 | `dart test test/unit/chain/chain_submission_tracker_test.dart` | N/A | revert commit 4 |
| 5 | D1-D4 reconcile, retention, OutcomeUnknown block | commit 5 | `dart test test/unit/chain test/unit/hire test/hire` | N/A | revert commit 5 (reset OutcomeUnknown rows first) |
| 6 | Docs | commit 6 | `dart analyze --fatal-infos` | N/A: docs | revert commit 6 |

Each unit ends with `dart analyze --fatal-infos` and `dart test` green in `puls3_server`. Conventional commits, no AI attribution.

## Unit 1: D8 hash check (commit 1)

- [x] 1.1 RED: `test/unit/ledger/soroban_rpc_client_test.dart` mismatch throws `LedgerUnavailable`; case-insensitive match passes.
- [x] 1.2 RED: `test/unit/ledger/soroban_submission_ledger_test.dart` resend forwards hash; tracker test asserts resend uses `record.transactionHash`.
- [x] 1.3 GREEN: `lib/src/ledger/soroban_rpc_client.dart` `sendTransaction(xdr, expectedHash)`; `lib/src/chain/submission_ledger.dart` and `lib/src/ledger/soroban_submission_ledger.dart` `resend(xdr, hash)`.
- [x] 1.4 GREEN callers: `lib/src/hire/escrow_relay_service.dart`, `lib/src/studio/studio_deploy_service.dart` (3 sites), `lib/src/chain/escrow_server_submit.dart`, `tool/e2e_feedback_testnet.dart`.
- [x] 1.5 Update fakes/tests: `test/support/fake_submission_ledger.dart` (default hash = expectedHash), `test/unit/chain/escrow_server_submit_test.dart`, `test/studio/studio_deploy_service_test.dart`. REFACTOR.

## Unit 2: D6 (commit 2)

- [x] 2.1 RED: rewrite pins in `test/unit/chain/chain_submission_tracker_test.dart` (~L594, 632, 706, 778, 813) and `test/hire/escrow_relay_submit_test.dart` (L678-725): complete/reject/registerFull become `confirmed`, no effect, no `SubmissionInProgress`.
- [x] 2.2 GREEN: `lib/src/chain/chain_submission_tracker.dart` joins them to release/claimRefund; keep `_untrackedPurposes`.

## Unit 3: D5 lists and matching (commit 3)

- [x] 3.1 RED: `test/unit/ledger/escrow_events_test.dart` several valid events returned in order; malformed/foreign skipped; `soroban_submission_ledger_test.dart` lists.
- [x] 3.2 RED: `test/unit/hire/hire_escrow_effects_test.dart` fund matches `jobId`; createJob matches client, agent, budget, `expiredAt`; zero/several matches give `JobMismatch` (`job_id`).
- [x] 3.3 GREEN: `lib/src/ledger/escrow_events.dart` (`_first` to `_all`), `lib/src/chain/submission_ledger.dart` and `lib/src/ledger/soroban_submission_ledger.dart` lists, `lib/src/chain/escrow_effects.dart` list params, `lib/src/hire/hire_escrow_effects.dart` matching, `test/support/fake_escrow_effects.dart`. REFACTOR.

## Unit 4: D7 (commit 4)

- [x] 4.1 RED: tracker test: empty list on SUCCESS for createJob/fund stays `submitted` on passes 1-2 (waiting++), fails `JobEvidenceUnavailable` on pass 3; counter cleared on settle.
- [x] 4.2 GREEN: `lib/src/chain/chain_submission_tracker.dart` `_missingEvents`, `evidencePasses = 3`, warning log.

## Unit 5: D1-D4 (commit 5)

- [x] 5.1 RED: `test/unit/chain/submission_values_test.dart` 7 codes; `test/unit/chain/escrow_effects_test.dart` Noop returns `ExpiredFundUnknown`; `test/integration/chain_submission_store_test.dart` accepts `OutcomeUnknown`.
- [x] 5.2 RED: `hire_escrow_effects_test.dart` reconcile per job state (funded/submitted/completed/rejected Landed; open NotLanded; null/expired/no jobId Unknown).
- [x] 5.3 RED: tracker tests: fund Landed/NotLanded->`PreparationExpired`/Unknown->retention; covered vs uncovered via `oldestLedgerCloseTime`; `rpcRetention` fallback (24h); createJob past retention `OutcomeUnknown`; reconcile throw stays `submitted`.
- [x] 5.4 RED: `test/hire/escrow_relay_submit_test.dart` any `OutcomeUnknown` record blocks every prepare incl. feedback, after `SubmissionInProgress`.
- [x] 5.5 GREEN: `lib/src/chain/escrow_effects.dart` (`ExpiredFund`, `reconcileExpiredFund`), `lib/src/hire/hire_escrow_effects.dart`, `lib/src/chain/submission_ledger.dart` + `soroban_submission_ledger.dart` (`oldestLedgerCloseTime`), `lib/src/chain/submission_values.dart`, `lib/src/chain/chain_submission_tracker.dart`, `lib/src/hire/escrow_relay_service.dart`, fakes. REFACTOR.
- [x] 5.6 `lib/src/protocol/puls3_api_exception.spy.yaml` comment adds `OutcomeUnknown` (no generate).

## Unit 6: Docs (commit 6)

- [x] 6.1 Align spec with D3: in `openspec/changes/101-tracker-correctness/specs/chain-submission-tracking/spec.md` replace "missing or not Funded" (L30, L59) and the OutcomeUnknown requirement text for `fund` with: job `open` gives `PreparationExpired`; Unknown (no jobId, null, `expired`) gives retention rule.
- [x] 6.2 `docs/architecture/api.md` (catalog row `OutcomeUnknown`, tracker table) and `puls3_server/README.md` (D6 caveat, restart resets D7 count); update tracker doc comment.
