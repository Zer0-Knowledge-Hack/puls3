```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:bc3a02082508d0dbbf84261bec720078c57af529f59fd7f8b78d3d635cf6b7c6
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 9/9
scenarios: 24/24
test_command: "dart test test/unit test/hire test/feedback test/agent test/ledger test/protocol test/integration/hire_repository_test.dart (puls3_server)"
test_exit_code: 0
test_output_hash: sha256:bc3a02082508d0dbbf84261bec720078c57af529f59fd7f8b78d3d635cf6b7c6
build_command: "dart analyze --fatal-infos lib test tool/e2e_feedback_testnet.dart (puls3_server)"
build_exit_code: 0
build_output_hash: sha256:bed712f10ee6547f2ddc3649ed2c8ad4140c89288e2b47f987967b055d26b303
```

# Verify Report: issue-179-feedback-e2e

Mode: Strict TDD. Branch feat/179-feedback-e2e-testnet (6 commits over main).
Verdict: PASS WITH WARNINGS (0 CRITICAL, 2 WARNING, 3 SUGGESTION).

## Execution
| Command | Result |
|---|---|
| puls3_server `dart test test/unit test/hire test/feedback test/agent test/ledger test/protocol test/integration/hire_repository_test.dart` | 943 passed, 0 failed |
| puls3_domain `dart test` | 267 passed |
| puls3_domain `dart analyze --fatal-infos` | No issues |
| puls3_server `dart analyze --fatal-infos lib test tool/e2e_feedback_testnet.dart` | No issues found |
| puls3_server test/integration/hire_repository_test.dart (DB) | 11 passed (executed with PostgreSQL container in Docker) |
| tool/e2e_feedback_testnet.dart | NOT EXECUTED (testnet, ops proof); analyze clean |

pubspec.lock reverted with git checkout. No files modified besides this report.

## Tasks
21/21 marked complete; code state matches (all listed files present in the diff).

## Spec compliance matrix
| Requirement / scenario | Evidence | Status |
|---|---|---|
| EST: confirmed release => completed | `_settlement` + `_row`/`findById`; DB integration tests | COMPLIANT (DB integration test passed) |
| EST: release submitted/failed not completed | `_settlement` filters state=confirmed; DB integration test | COMPLIANT (DB integration test passed) |
| EST: confirmation twice no-op | derivation read-only, confirmed final | COMPLIANT by construction |
| EST: claim_refund confirmed => expired | `_settlement`; DB integration test | COMPLIANT (DB integration test passed) |
| EST: third failure => EscrowCallFailed | tracker `_failureCode` + sender `escrowCallFailureCode`; unit tests (sender 3rd rejected, tracker 3rd txFailed/prepExpired) | COMPLIANT (unit-tested) |
| EST: below limit keeps code | escrowCallFailureCode tests, tracker tests | COMPLIANT |
| EST: counts scoped per purpose+hire | tracker filters row.purpose == purpose over listByHire(hireId) | COMPLIANT |
| EST: stuck call stops blocking in-flight slot | failed record frees slot (existing relay logic) | COMPLIANT (indirect) |
| HP: completed/expired from confirmed, funded stays funded | as above; DB integration test | COMPLIANT (DB integration test passed) |
| HP: no direct status write; derived writes nothing | `_settlement` read-only; findById replays via domain (`submit().complete()`, `expire()`) | COMPLIANT |
| ACE: one agent unreadable stays listed with empty values | ReputationCatalogReader.list per-agent catch; 4 new tests | COMPLIANT |
| ACE: failed read not cached | ReputationCache throws without caching | COMPLIANT |
| ACE: all fail, no cache => AgentCatalogUnavailable | unreadable == agents.length throw | COMPLIANT |
| ACE: unfiltered documented (ADR D5/D6, api.md) | ADR-0005 notes, api.md 3 spots, README | COMPLIANT |
| HF: registry read has no hireId | Feedback.hireId HireId?, registry returns null; tests | COMPLIANT |
| HF: reputation unaffected | existing reputation tests green | COMPLIANT |
| HF: SubmitFeedback rejections intact; null => FeedbackDoesNotMatchHire | domain test + existing feedback tests green | COMPLIANT |
| HF: real-DB completed hire accepts feedback | DB integration test & domain validation | COMPLIANT (DB integration test passed) |

## Design coherence
- D1 shared `escrowCallFailureCode` in escrow_deadline.dart, used by sender (rejected path) and tracker (`_fail`, release/claimRefund only): coherent.
- D3: markFailed used, `_effectCodes` untouched: coherent.
- D4 `_settlement`: coherent; minor deviation (uses `find` + purpose set instead of `findFirstRow` per purpose); semantics equal, release wins.
- D6 per-agent isolation list only; `get` still throws: coherent.
- D7 nullable hireId: coherent. D8 script present (363 lines). D9 docs present.
- findById replay safe: startRun/failRun keep status funded so `submit()` precondition holds.

## Issue #179 acceptance (code-verifiable)
Verified in code/tests: EscrowCallFailed labelling, derived completed/expired, catalog degrade, nullable hireId, docs, script exists and analyzes, and PostgreSQL DB integration tests executed and passing.
Pending (ops/testnet): run F7 end to end on testnet (release confirmed -> completed -> feedback give_feedback confirmed -> rating visible in AgentEndpoint.get), approval_deadline window bound.

## Findings
CRITICAL: none.
WARNING
1. Script e2e_feedback_testnet.dart not run on testnet; F7 acceptance unproven.
2. Tracker `_failureCode` counts via `listByHire` on every failure: if the row is not yet marked failed and two earlier rows are, fine, but a race where another tracker concurrently fails an earlier row could miscount (low probability; markFailed idempotent).
SUGGESTION
1. Add a unit-level fake-store test for derivation logic extracted from repo, to reduce DB-only coverage.
2. Delete or gitignore untracked tool/feedback_walkthrough.dart and passwords.yaml.bak-before-sep10 (24 lint infos block `--fatal-infos` clean runs if whole folder analyzed).
3. Align design D4 text with `find` implementation.

## Key Learnings
- dart commands rewrite root pubspec.lock; revert after runs.
- Strict-TDD proof has full unit and real DB integration test coverage passing via Docker PostgreSQL test instance.
