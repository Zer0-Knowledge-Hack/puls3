# Hire Feedback Specification

## Purpose

Lets the consumer of a completed hire rate it once. Rules live in the domain (`SubmitFeedback`); the chain is behind a `ReputationRegistry` port, so everything is testable with in-memory fakes. Feedback sets `Hire.feedbackReference`; status stays `completed` (ADR-0005 D6).

## Requirements

### Requirement: SubmitFeedback eligibility rules

`SubmitFeedback` MUST accept a feedback only when ALL hold: hire status is `completed`; the caller is the hire's consumer; the caller is not the agent owner; the hire has no `feedbackReference` yet. Score MUST be 1-5 and comment at most 500 characters (existing `Feedback` entity). Each violation MUST raise a distinct typed domain error and MUST NOT call the registry.

#### Scenario: Happy path

- GIVEN a `completed` hire, caller is its consumer and not the owner, no feedback yet
- WHEN `SubmitFeedback` runs with score 4
- THEN the fake `ReputationRegistry` receives one feedback and a reference is returned

#### Scenario: Non-completed hire rejected

- GIVEN a hire in `open`, `funded`, `submitted`, `rejected` or `expired`
- WHEN `SubmitFeedback` runs
- THEN a not-completed error is raised and the registry is untouched

#### Scenario: Non-hirer rejected

- GIVEN a `completed` hire and a caller who is not its consumer
- WHEN `SubmitFeedback` runs
- THEN a not-consumer error is raised and the registry is untouched

#### Scenario: Owner rating own agent rejected

- GIVEN a `completed` hire whose agent is owned by the caller
- WHEN `SubmitFeedback` runs
- THEN an owner-cannot-rate error is raised and the registry is untouched

#### Scenario: Second feedback rejected

- GIVEN a `completed` hire that already has a `feedbackReference`
- WHEN `SubmitFeedback` runs again
- THEN an already-rated error is raised and the registry receives no second feedback

### Requirement: feedbackReference recorded, status unchanged

On success the hire MUST have `feedbackReference` set to the reference returned by the registry port, and its status MUST remain `completed`. No "rated" status MUST exist.

#### Scenario: Reference set, status completed

- GIVEN the happy path above
- WHEN the feedback is accepted
- THEN `hire.feedbackReference` equals the registry reference
- AND `hire.status` is still `completed`

### Requirement: FeedbackEndpoint prepare/submit relay

The server MUST expose `getFeedbackEligibility`, `prepareFeedback` and `submitFeedback` (per `docs/api.md`). `prepareFeedback` MUST return an unsigned `give_feedback` draft for the consumer to sign, with `SubmissionPurpose.giveFeedback`; it MUST apply the same eligibility rules. `submitFeedback` MUST relay the signed transaction and record `feedbackReference`. `getFeedbackEligibility` MUST return whether the caller may rate and, when not, the reason. Eligibility failures MUST surface as typed errors, never as generic failures.

#### Scenario: Eligibility reports reason

- GIVEN a fake hire store with a `funded` hire
- WHEN `getFeedbackEligibility` is called by its consumer
- THEN it reports not eligible with a not-completed reason

#### Scenario: Prepare then submit

- GIVEN an eligible hire and fake relay and registry
- WHEN `prepareFeedback` then `submitFeedback` are called
- THEN the draft purpose is `giveFeedback`
- AND `feedbackReference` is set and status stays `completed`

#### Scenario: Ineligible prepare

- GIVEN a hire already rated
- WHEN `prepareFeedback` is called
- THEN an already-rated error is thrown and no draft is built

### Requirement: Registry behind a port

The domain MUST define a `ReputationRegistry` port with in-memory fakes. The server MUST provide a Soroban adapter that reads the Reputation Registry of #14 and a `ReputationCalls` that builds its `give_feedback`, both used only when `PULS3_STELLAR_REPUTATION_REGISTRY` is set; while it is unset they MUST be the unwired ones (`prepareFeedback` fails with `HireConfigurationMissing`, no agent has feedback). The fake and the Soroban adapter MUST pass one shared contract suite for reads.

#### Scenario: Offline tests

- GIVEN no network, database or chain
- WHEN the domain and endpoint tests run
- THEN they pass using only the fakes

### Requirement: Hire detail exposes the feedback

`getHire` MUST return the hire's `giveFeedback` submission as `feedbackSubmission`, separate from `escrowSubmission`, and MUST set `hire.feedbackReference` to its transaction unless it `failed`. A relayed `giveFeedback` that succeeds on chain MUST become `confirmed` through the chain tracker.

#### Scenario: Reload after rating

- GIVEN a hire whose `giveFeedback` submission is confirmed
- WHEN `getHire` is called
- THEN `feedbackSubmission.state` is `confirmed` and `hire.feedbackReference` is its transaction
- AND `escrowSubmission` is the latest escrow call, not the rating

#### Scenario: Failed rating

- GIVEN a hire whose only `giveFeedback` submission failed
- WHEN `getHire` is called
- THEN `feedbackSubmission.state` is `failed` and `hire.feedbackReference` is null

### Requirement: Registry feedback carries no fabricated hireId

Feedback read from the Reputation Registry MUST NOT expose the registry `feedback_index` as a `hireId`. A registry read MUST yield score and comment without a hire identity. Feedback submitted for a hire still carries that hire's id. The shared contract suite for reads MUST pass for the fake and the Soroban adapter under this shape.

#### Scenario: Registry read has no hireId

- GIVEN a registry holding feedback at index 7
- WHEN it is read through the adapter
- THEN no hire id is present, and 7 is not used as one

#### Scenario: Reputation unaffected

- GIVEN registry feedback with scores
- WHEN the #11 reputation function consumes them
- THEN `rating` and `paidHireCount` equal the values before this change

### Requirement: Eligibility rules survive the decoupling

Decoupling MUST NOT relax `SubmitFeedback`. A hire not `completed`, a non-consumer caller, the agent owner rating their own agent, and a hire with a `feedbackReference` MUST each still raise their typed error without calling the registry. The hire match MUST use the submitted feedback's own hire id.

#### Scenario: Rejections intact

- GIVEN hires that are not completed, a non-hirer caller, an owner caller, and an already-rated hire
- WHEN `SubmitFeedback` runs for each
- THEN not-completed, not-consumer, owner-cannot-rate and already-rated errors are raised
- AND the registry is untouched

#### Scenario: Real-DB completed hire accepts feedback

- GIVEN a hire made `completed` only by a confirmed `release` submission
- WHEN the consumer submits feedback
- THEN it is accepted, `feedbackReference` is set and status stays `completed`
