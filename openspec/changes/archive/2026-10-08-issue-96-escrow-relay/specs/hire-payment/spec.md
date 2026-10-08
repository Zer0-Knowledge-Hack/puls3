# Delta for Hire Payment

`docs/architecture/api.md` is authoritative; this delta supersedes the stale `createHire` text in `openspec/specs/hire-payment/spec.md`.

## MODIFIED Requirements

### Requirement: Create an open hire

`HireEndpoint.createHire(agentId, consumer, input, requestId)` MUST require a session (`SessionWallet.requireLogin`), require `consumer` to equal the session wallet (`WalletMismatch`), and persist a hire with the agent's price, manifest version and the `input`. The hire status MUST be null (no status) until its `create_job` is confirmed by the tracker; only then does it become `open`. The result MUST be `CreateHireResult{hire, preparedCreateJob?}`, where `preparedCreateJob` is the unsigned `create_job` envelope prepared by the escrow relay (see `escrow-relay`). `createHire` MUST NOT move funds, sign, or submit any transaction. The agent MUST have a wallet and a manifest version of at least 1; no fallback version is invented. `HireService.createHire` MUST NOT return `HireView`.

#### Scenario: Hire created with a prepared create_job

- GIVEN a registered active agent with a wallet, a price and a manifest version of at least 1
- AND a configured `PULS3_HIRE_JOB_DURATION_SECONDS` and preparation validity window
- WHEN `createHire` is called with the agent id, the session wallet as consumer, an input and a new `requestId`
- THEN a hire exists with status null, the agent's price, the consumer and the input
- AND the stored `expired_at` equals now plus the configured duration
- AND the result carries `preparedCreateJob` with purpose `createJob`, the consumer as source, the agent wallet as provider, the consumer as evaluator, the USDC SAC as token, `Hire.price` as budget and that `expired_at`

#### Scenario: Retry with the same requestId

- GIVEN a hire created with `requestId` R, agent A and input I by the session wallet
- WHEN `createHire` is called again with R, A and I
- THEN the existing hire is returned and no second hire is persisted
- AND `preparedCreateJob` is the current unexpired preparation, or a fresh superseding one when the previous expired unused

#### Scenario: Retry after the create_job was submitted

- GIVEN the hire's `create_job` has a `ChainSubmission` in state `submitted` or `confirmed`
- WHEN `createHire` is called again with the same `requestId`, agent and input
- THEN the existing hire is returned with `preparedCreateJob` null

#### Scenario: requestId reused with different content

- GIVEN a hire created with `requestId` R, agent A and input I by the session wallet
- WHEN `createHire` is called with R and a different agent or a different input
- THEN it fails with `IdempotencyKeyReused` and nothing changes

#### Scenario: requestId scoped per wallet

- GIVEN two session wallets using the same `requestId` string
- WHEN each calls `createHire`
- THEN each gets its own hire

#### Scenario: Unknown or inactive agent

- GIVEN an agent id that is invalid, not in the registry, has no wallet, or is inactive
- WHEN `createHire` is called
- THEN no hire is persisted
- AND the call fails with `InvalidAgentId`, `AgentNotFound` or `AgentInactive` respectively

#### Scenario: Input too long or invalid hire

- GIVEN an `input` longer than the contract allows, or a hire that violates domain invariants
- WHEN `createHire` is called
- THEN it fails with `InputTooLong` or `InvalidHire` and no hire is persisted

#### Scenario: First preparation fails

- GIVEN the account sequence, latest ledger or simulation fails
- WHEN `createHire` is called
- THEN it fails with `ChainUnavailable` and no hire is persisted
- AND a retry with the same `requestId` creates the hire then

#### Scenario: Ledger unavailable on create

- GIVEN a ledger read for the catalog or agent metadata fails
- WHEN `createHire` is called
- THEN no hire is persisted and the failure surfaces as `ChainUnavailable`

## ADDED Requirements

### Requirement: create_job confirmation records the job id and opens the hire

When the tracker sees a successful `create_job` submission, `HireEscrowEffects.onJobCreated` MUST record the job id from the `JobCreated` event on the hire named by `submission.hireId` and move the hire from null status to `open`. Applying it again to the same submission MUST be a no-op that succeeds. A job id already bound to another hire MUST NOT be bound twice. Until the effect has applied, `HireDetail` status MUST remain null and `prepareFund` MUST NOT be possible.

#### Scenario: create_job confirmed

- GIVEN a hire with null status and a successful `create_job` submission naming it and a `JobCreated` event with job id J
- WHEN `onJobCreated` is applied
- THEN the hire records job id J and its status is `open`

#### Scenario: Applied twice

- GIVEN the effect already applied for the submission
- WHEN it is applied again
- THEN the result is success and the job id is stored once

#### Scenario: Job id already bound

- GIVEN another hire already holds job id J
- WHEN `onJobCreated` is applied for this hire
- THEN the submission is marked failed with a job mismatch and the hire status stays null

#### Scenario: Funding before confirmation

- GIVEN a hire whose `create_job` is not yet confirmed
- WHEN `prepareFund` is called
- THEN it fails with `InvalidHireTransition`

### Requirement: Every hire method requires the session wallet

Every `HireEndpoint` method (`createHire`, `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject`, `submitEscrowCall`) MUST obtain the wallet through the injectable `SessionWallet` seam and MUST use it for ownership. Real session binding replaces the seam in #25; until then ownership is proven only against a fake.

#### Scenario: Seam enforced on every method

- GIVEN a fake `SessionWallet` that records invocations
- WHEN each hire method is called
- THEN each calls `requireLogin` exactly once before touching a store or the chain

### Requirement: Settlement by complete and reject awaits #97

A hire MUST NOT move to `completed` or `rejected` as a result of this change. `complete` and `reject` relays record their `ChainSubmission` and leave it `submitted`; the corresponding hire effects are specified and delivered by #97.

#### Scenario: Status unchanged after complete or reject relay

- GIVEN a funded hire and a relayed `complete` or `reject` submission
- WHEN the tracker polls it
- THEN the hire status is unchanged and the submission stays `submitted`
