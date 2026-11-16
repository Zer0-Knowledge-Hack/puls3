# 01 · Issue analysis

## What the issue says

Issue #201 (audit of 2026-10-25, finding R-2a, Medium, P2, after HackMeridian):

- **Problem:** "only a real paying customer can rate" is enforced by the backend
  only. The reputation contract has no notion of a hire and accepts feedback
  from anyone, at any time. On-chain data alone cannot prove that a score came
  from a real paid job.
- **Fix direction given by the issue:** embed the job/hire reference in the
  feedback written on chain, using the existing `feedback_uri` /
  `feedback_hash` arguments of `give_feedback`, so that the link
  rating → paid job is verifiable on chain, without trusting the backend and
  without breaking the Stellar 8004 ABI.

## Acceptance criteria, read literally

| # | Criterion | What it really requires |
|---|---|---|
| A1 | A rating submitted through the app carries a verifiable reference to its paid job on-chain | The transaction the app builds must contain a job reference that a third party can resolve to an on-chain paid job. A reference that only the puls3 database can resolve is not enough |
| A2 | The one-rating-per-hire and rate-only-after-completion rules are still enforced | The server rules of `FeedbackService` stay. The issue does not require the contract to enforce them |
| A3 | No Stellar 8004 ABI break (ADR-0002 notes any deviation) | Same function names, argument order and types, events and error codes. A behavioral deviation is allowed if ADR-0002 records it |
| A4 | Tests on both sides: domain rules and contract behavior | Tests in `puls3_domain` (and the server that applies them) and in the contract crate(s) |

## What the issue does not say, and must be decided

1. **Who verifies.** "Verifiable on chain" is satisfied if any reader can check
   the reference against chain state. It does not say the contract must reject
   a rating without a paid job. ADR-0005 D5 already decided that the paid-hire
   rule "leaves the registry" and is "applied by readers"; #201 completes that
   decision rather than reversing it (see [07](07-stellar-8004-compatibility.md)).
2. **What happens to ratings without a reference.** Today every counted record
   lacks one (see [05](05-domain-and-backend-analysis.md)). Whether readers stop
   counting them changes served ratings.
3. **Where the reference lives.** `feedback_uri`/`feedback_hash` are not stored
   by the contract, only emitted (see [04](04-contract-analysis.md)). The issue
   assumes they are enough; the analysis shows they are verifiable but not
   durably readable with the reads the rating uses.

## Related work

| Item | Relation |
|---|---|
| ADR-0005 D5 | Moved the paid-hire rule out of the registry: "proven by a completed ERC-8183 escrow job … readers filter feedback by clients with completed jobs". Its implementation note (#179) accepts unfiltered reads as an MVP risk and names the follow-up |
| ADR-0002 | Records the Stellar 8004 subset and deviations (#199 added one) |
| #202 (closed, merged in #230) | Made the served rating recomputable from raw records with public exclusion rules (`exclusionOf`). #201 would add one more public rule |
| #200 (R-3, open) | An agent can rate itself through its payout wallet. Overlaps with self-dealing through a paid job (see [06](06-security-analysis.md)) |
| #203 (open) | Decision: reputation formula on chain vs off chain. A contract-enforced gate (alternative C in [09](09-technical-proposal.md)) depends on it |
| #211 (open) | The app screen to rate a completed hire (F7). The Flutter app has no rating screen yet, so A1 is reached through the server's `FeedbackEndpoint` and, later, #211 |
| #205 (open) | Contract hardening (loops, responses). Not overlapping, but touches the same contract |
