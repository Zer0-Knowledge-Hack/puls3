# Proposal: Feedback and Reputation (issue #21)

## Intent

Consumers cannot rate a paid hire and the catalog shows no reputation (Flutter `rating` is hard-coded `0.0`). Issue #21 asks for a feedback flow and reputation in the catalog. Build it domain-first so it ships now, with the on-chain Reputation Registry (#14, PR #165) behind a port.

## Scope

### In Scope
- Domain `SubmitFeedback` use case: hire must be `completed`, client == consumer, one feedback per hire, and a new owner rule (owner cannot rate own agent) with a domain error and test.
- `ReputationRegistry` port plus in-memory fakes; no Soroban adapter.
- Server `FeedbackEndpoint` (`getFeedbackEligibility`, `prepareFeedback`, `submitFeedback`, per `docs/api.md`) on the existing prepare/relay pattern with `SubmissionPurpose.giveFeedback`.
- `AgentSummary` gains `rating` and `paidHireCount` in list/detail, computed with the #11 reputation function.
- Feedback sets `Hire.feedbackReference`; status stays `completed` (ADR-0005 D6, `docs/domain/hire-lifecycle.md`). The issue's "Rated" maps to this.

### Out of Scope
- Rating UI, edit/delete feedback.
- Real on-chain Reputation Registry adapter (#14).
- Server persistence of `completed` status and tracker complete/reject effects.
- Testnet e2e acceptance criterion: deferred, blocked by #14 and persistence.

## Capabilities

### New Capabilities
- `hire-feedback`: feedback eligibility, owner/consumer/status rules, prepare/submit relay, `feedbackReference` recording.

### Modified Capabilities
- `agent-catalog-endpoint`: `AgentSummary` exposes `rating` and `paidHireCount`.

## Approach

Approach 2, "domain-first, chain behind a port". Rebase on `origin/main` to get #11 (`puls3_domain/lib/src/reputation.dart`); it is the formula source of truth and is not reimplemented. Domain rules live in `puls3_domain` (ADR-0001 boundary respected: no Serverpod/Stellar SDK). The server adapts the relay service for `give_feedback`; the registry contract id is read through the port, so only fakes are wired until #14.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `puls3_domain/lib/src/` | Modified/New | `SubmitFeedback`, owner error, port |
| `puls3_server/lib/src/feedback/` | New | `FeedbackEndpoint`, service |
| `puls3_server/lib/src/hire/escrow_relay_service.dart` | Modified | `giveFeedback` draft target |
| `puls3_server/lib/src/agent/` | Modified | `rating`, `paidHireCount` |
| `puls3_server/lib/src/protocol/*.spy.yaml`, `puls3_client` | Modified | Model fields (generated) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Forecast exceeds 400 authored lines (domain + endpoint + catalog + tests) | High | `sdd-tasks` forecasts; generated code excluded; trim scope or request `size:exception` |
| No server-side `completed` hire, so eligibility is only exercised with fakes | High | Port-level fakes; document the gap |
| Owner identity not on `AgentSummary`; owner source undecided (registry owner vs wallet) | Med | Resolve in design |
| Branch lacks #11 | Med | Rebase on `origin/main` before apply |
| Domain boundary crossing | Low | Port lives in domain, adapter in server |

## Rollback Plan

Revert the single PR. New endpoint and fields are additive; regenerate the client and drop the new model fields. No migrations or on-chain state are touched.

## Dependencies

- #11 (merged, PR #151), required via rebase.
- #14 (PR #165) for the real adapter (deferred).

## Success Criteria

- [ ] Domain tests cover completed-only, consumer-only, single-feedback, and owner-cannot-rate rules.
- [ ] `FeedbackEndpoint` prepare/submit is tested with fakes and sets `feedbackReference`, with status still `completed`.
- [ ] Catalog list/detail return `rating` and `paidHireCount` from the #11 function.
- [ ] Analyze and tests pass for domain and server; generated client committed.
