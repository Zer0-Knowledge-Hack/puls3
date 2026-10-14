# Tasks: Feedback and Reputation (issue #21)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated authored lines | ~650-750 (generated code excluded) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Single PR needs `size:exception`; or PR 1 feedback (units 1-2) then PR 2 catalog (unit 3) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

Trim to approach 400: defer `docs/api.md`, the TTL cache and stale fallback in D6, and the shared contract suite (~200 lines). That still leaves ~450-500, so a split or exception remains needed.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Domain rule + ports | PR 1 | `dart test puls3_domain/test/feedback_test.dart` | N/A: pure domain | `feedback.dart`, `ports.dart`, export |
| 2 | Feedback endpoint relay | PR 1 | `dart test puls3_server/test/feedback` | N/A: fakes only (#14 pending) | `feedback/`, relay and ledger edits |
| 3 | Catalog reputation | PR 2 | `dart test puls3_server/test/agent/reputation_catalog_reader_test.dart` | N/A: fake registry | reader, wiring, `AgentSummary` fields |

## Phase 0: Gate

- [x] 0.1 (done by the orchestrator, user-approved: fresh branch from `origin/main`) User-approved git step, apply must ask. Option A: rebase or merge `origin/main` onto `feat/136-wallet-sessions-02-flutter` (the working tree has uncommitted edits, so stash first). Option B: a fresh branch from `origin/main`. Identity must be moises-cisneros <moisescisnerosdl@gmail.com>; no AI attribution.
- [x] 0.2 Confirm #11 API in `puls3_domain/lib/src/reputation.dart` (read-only): `reputationOf`, `isSelfRating`, `rejectSelfRating` -> `FeedbackFromAgentOwner`. No `OwnerCannotRate`; `errors.dart` is untouched.

## Phase 1: Domain (unit 1)

- [x] 1.1 RED: `puls3_domain/test/feedback_test.dart`. Cover the order completed, already rated, `FeedbackDoesNotMatchHire`, `FeedbackFromAgentOwner`; the happy path; no registry call on violation; reference set, status `completed`.
- [x] 1.2 GREEN: `puls3_domain/lib/src/feedback.dart` with `checkFeedbackAllowed` (owner step via `rejectSelfRating`), `SubmitFeedback`, and `ReputationRegistry` (`giveFeedback`, `feedbacksOf -> List<Feedback>`).
- [x] 1.3 GREEN: `AgentOwnerReader` in `puls3_domain/lib/src/ports.dart`; export in `puls3_domain/lib/puls3_domain.dart`.

## Phase 2: Server feedback (unit 2)

- [x] 2.1 RED: `puls3_server/test/feedback/feedback_service_test.dart` using `relay_rig.dart`. Cover eligibility reason (funded -> not completed), prepare purpose `giveFeedback` and contract, already rated with no draft, owner rejected, null owner -> `ChainDataUnavailable`, submit sets the reference.
- [x] 2.2 RED: `puls3_server/test/feedback/escrow_relay_feedback_test.dart`. `_draft` accepts a contract and `_allows` permits `giveFeedback` only when `completed`.
- [x] 2.3 GREEN: `puls3_server/lib/src/hire/escrow_relay_service.dart` (D4: contract param, `prepareFeedback`).
- [x] 2.4 GREEN: `puls3_server/lib/src/feedback/reputation_calls.dart` (`ContractCall`, port, `UnwiredReputationCalls` -> `HireConfigurationMissing`).
- [x] 2.5 GREEN: `puls3_server/lib/src/ledger/soroban_ledger.dart` `ownerOf` (error 3 -> null), with a small test.
- [x] 2.6 GREEN: `puls3_server/lib/src/feedback/feedback_service.dart` (reference from the non-failed `giveFeedback` submission hash).
- [x] 2.7 GREEN: `feedback_eligibility.spy.yaml` and `feedback_endpoint.dart` (3 methods); run `serverpod generate` and commit the generated code and `puls3_client`.

## Phase 3: Catalog reputation (unit 3)

- [x] 3.1 RED: `puls3_server/test/agent/reputation_catalog_reader_test.dart`. Values equal a direct `reputationOf` call; empty input -> 4.0, listed; source failure -> stale values or `AgentCatalogUnavailable`, never fabricated; TTL with an injected clock.
- [x] 3.2 GREEN: `puls3_server/lib/src/agent/agent_summary.spy.yaml` (`rating`, `paidHireCount`, defaulted); regenerate.
- [x] 3.3 GREEN: `puls3_server/lib/src/agent/reputation_catalog_reader.dart` (decorator, 60 s cache); `UnwiredReputationRegistry` returns empty, so the result is 4.0.
- [x] 3.4 GREEN: wrap the reader in `puls3_server/lib/src/agent/agent_catalog_wiring.dart`.
- [x] 3.5 Reconcile the catalog default of `0.0` and the Flutter mapper `rating` (`lib/`) with 4.0; fix the affected tests.

## Phase 4: Verify and docs

- [x] 4.1 `dart analyze` and `dart test` in `puls3_domain` and `puls3_server`; the generated client matches (spec "Offline tests").
- [x] 4.2 REFACTOR: dedupe the test fakes into `puls3_server/test/support/`.
- [x] 4.3 Docs (first trim candidate): `docs/architecture/api.md` (reason field, `rating`/`paidHireCount` no longer planned).
