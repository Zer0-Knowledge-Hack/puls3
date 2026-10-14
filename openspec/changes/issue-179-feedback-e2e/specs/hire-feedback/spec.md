# Delta for Hire Feedback

## ADDED Requirements

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
