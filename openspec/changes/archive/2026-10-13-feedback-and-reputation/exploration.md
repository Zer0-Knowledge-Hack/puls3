# Exploration: feedback-and-reputation (issue #21)

Source: Engram `sdd/feedback-and-reputation/explore` (obs 517).

## Findings

1. **Reputation formula (#11)**: absent on this branch (`docs/domain/model.md` says "not a class here"). It is merged on `origin/main` (PR #151: `puls3_domain/lib/src/reputation.dart`, `docs/domain/reputation.md`). Only the `Feedback` entity (score 1-5, comment <= 500) and `Hire.recordFeedback` exist here.
2. **Reputation Registry (#14)**: no contract/crate under `contracts/`; the `testnet.json` slot is null; `StellarConfig` has no reputation contract id; the relay `_draft` hard-codes the escrow contract. Open PR #165 tracks it.
3. **Hire states**: `open/funded/submitted/completed/rejected/expired`. "Rated" is not a state; it is `feedbackReference` being set. Server `HireRow`/`HireRecord` track no completed status and no `feedbackReference`; the tracker has no complete/reject effects, so a completed hire is not reachable server-side yet.
4. **API contract**: `docs/api.md` already defines `FeedbackEndpoint` (`getFeedbackEligibility`, `prepareFeedback`, `submitFeedback`). The consumer wallet signs `give_feedback` (ADR-0001, ADR-0005 D5). The server relay pattern is `EscrowRelayService` prepare/submit; `SubmissionPurpose.giveFeedback` already exists in the enum.
5. **Owner rule**: domain `recordFeedback` checks `client == consumer` but not the owner; `AgentRecord`/`AgentSummary` carry no owner.
6. **Catalog**: `AgentSummary` has no `rating`/`paidHireCount` (planned by `api.md` for #21); Flutter `agent.rating` is hard-coded `0.0`.

## Recommendation

Domain-first slices: reputation function (reuse #11) and `SubmitFeedback` rules with fakes, then a feedback service on the relay pattern with the `giveFeedback` purpose, then catalog fields. Flag #11 and #14 as blockers.
