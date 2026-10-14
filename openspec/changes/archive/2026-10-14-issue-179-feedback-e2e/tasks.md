# Tasks: Feedback end to end on testnet (#179)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~660 (PR1 ~300, PR2 ~110, PR3 ~250) |
| 400-line budget risk | High (as one PR) |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 -> PR 2 -> PR 3 |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

Note: session is `single-pr`, so a single ~660-line PR needs `size:exception`; otherwise pick stacked-to-main or feature-branch-chain (PR1 base = tracker/main, PR2 base = PR1, PR3 base = PR2).

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Settlement derivation + EscrowCallFailed labelling | PR 1 | `dart test test/unit/chain test/integration/hire_repository_test.dart` (puls3_server) | DB integration tests (hire_repository_test) | chain/ + hire repo files, no migration |
| 2 | Catalog per-agent degrade + nullable Feedback.hireId | PR 2 | `dart test test/agent test/feedback` (server); `dart test test/feedback_test.dart` (domain) | N/A, unit-level | reader + domain entity + registry |
| 3 | F7 testnet script + docs | PR 3 | `dart analyze --fatal-infos` | Manual testnet run (post-merge ops) | tool/ script + docs only |

## Phase 1 (PR1): Failure labelling (D1-D3)

- [x] 1.1 RED: `puls3_server/test/unit/chain/escrow_deadline_test.dart` add `escrowCallFailureCode` cases (priorFailures+1 >= max => EscrowCallFailed, else code passthrough).
- [x] 1.2 GREEN: `puls3_server/lib/src/chain/escrow_deadline.dart` move `maxEscrowCallAttempts` here, add pure `escrowCallFailureCode`.
- [x] 1.3 RED: `puls3_server/test/unit/chain/escrow_server_submit_test.dart` 3rd `submissionRejected` release => failed + EscrowCallFailed; fund unaffected.
- [x] 1.4 GREEN: `puls3_server/lib/src/chain/escrow_server_submit.dart` use `escrowCallFailureCode` with precomputed failed count; import the moved constant.
- [x] 1.5 RED: `puls3_server/test/unit/chain/chain_submission_tracker_test.dart` 3rd `transactionFailed`/`preparationExpired`/`submissionRejected` release/claimRefund => EscrowCallFailed; fund unaffected; 2nd keeps code.
- [x] 1.6 GREEN: `puls3_server/lib/src/chain/chain_submission_tracker.dart` count failed same-purpose rows (excluding current) via listByHire; label on markFailed.

## Phase 2 (PR1): Settlement derivation (D4-D5)

- [x] 2.1 RED: `puls3_server/test/integration/hire_repository_test.dart` confirmed release => completed, claimRefund => expired, failed/submitted => funded, release wins, findById agrees.
- [x] 2.2 GREEN: `puls3_server/lib/src/hire/serverpod_hire_repository.dart` add `_settlement` (chain_submission_hire_idx), apply in `_row` and `findById` replay.
- [x] 2.3 RED/GREEN: `puls3_server/test/feedback/feedback_service_test.dart` eligibility holds on derived completed. (Covered by the existing `completed` eligibility cases plus the DB `findById`/`findHire` agreement tests in 2.1; no production change needed.)
- [x] 2.4 Doc-comment the derivation exception in `puls3_server/lib/src/hire/hire_lifecycle_store.dart`.
- [x] 2.5 REFACTOR + verify PR1 (commands below).

## Phase 3 (PR2): Catalog + nullable hireId (D6-D7)

- [x] 3.1 RED: `puls3_server/test/agent/reputation_catalog_reader_test.dart` list isolates one unreadable agent (default values, no cache), all-fail => AgentCatalogUnavailable, `get` still throws.
- [x] 3.2 GREEN: `puls3_server/lib/src/agent/reputation_catalog_reader.dart` per-agent catch in `list`.
- [x] 3.3 RED: `puls3_domain/test/feedback_test.dart` null hireId => FeedbackDoesNotMatchHire; rejections unchanged.
- [x] 3.4 GREEN: `puls3_domain/lib/src/entities.dart` `Feedback.hireId` -> `HireId?`, `==` matching.
- [x] 3.5 RED/GREEN: `puls3_server/test/unit/ledger/soroban_reputation_registry_test.dart` + `lib/src/ledger/soroban_reputation_registry.dart` pass null hireId.
- [x] 3.6 Verify PR2 (commands below).

## Phase 4 (PR3): Script + docs (D8-D9)

- [x] 4.1 Create `puls3_server/tool/e2e_feedback_testnet.dart` (shape of `e2e_relay_testnet.dart`): release via deadline runner + tracker, assert completed, feedback submit, assert feedbackReference + rating; no secrets printed.
- [x] 4.2 Docs: `docs/adr/0005-align-agent-commerce-with-erc-8183-and-erc-8004.md` D5 (unfiltered reads, risk, follow-up) and D6 (rated = completed + feedbackReference) notes.
- [x] 4.3 Docs: `docs/architecture/api.md` lines ~143-146, 266, 460 (and a README section).
- [x] 4.4 `dart analyze --fatal-infos` clean on the script.

## Verification (each PR)

- `dart analyze --fatal-infos`
- `dart test test/unit test/hire test/feedback test/agent test/ledger test/protocol` (puls3_server); `dart test` (puls3_domain)

## Post-merge ops (not tasks)

- Deploy server; fund a testnet hire; run F7 script after approval_deadline; confirm feedback via AgentEndpoint.get.
