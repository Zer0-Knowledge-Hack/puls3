# Hire Payment Specification

## Purpose

Lets the server create hires and verify, from chain evidence, that an escrow job funded by a relayed `fund` transaction pays exactly one hire. The server never custodies or signs: the consumer signs `create_job` and `fund`, the server relays them, and the chain tracker (`ChainSubmissionTracker`) applies the verified outcome to the hire.

> **Status:** there is no public hire endpoint. A client-supplied transaction hash let anyone claim a public funding transaction, so payments follow the server relay (Decision A in `docs/architecture/api.md`), delivered in #96 and #97. The server-internal parts live here: hire creation, the funding checks of `docs/architecture/api.md` (`HireEscrowEffects.onFunded`, `verifyFunding`), and the `hire_payment` unique indexes.

## Requirements

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

### Requirement: expired_at is required with no default

The server MUST set `expired_at` to `now + PULS3_HIRE_JOB_DURATION_SECONDS`. That job duration is required and has no default, because ADR-0005 D3 defers the timeout values. If it is missing or invalid, `createHire` MUST fail before persisting a hire. The system MUST NOT invent a duration, fallback, or placeholder.

#### Scenario: Missing job duration

- GIVEN `PULS3_HIRE_JOB_DURATION_SECONDS` is not configured, not a whole number, or not positive
- WHEN `createHire` is called
- THEN it fails with the typed error `HireConfigurationMissing` naming the setting
- AND no hire is persisted

### Requirement: Verify a funded job against its hire

When the tracker sees a successful `fund` submission, `HireEscrowEffects.onFunded(submission, JobFundedEvent)` MUST load the hire named by `submission.hireId`, read the job named by the event from the escrow, and check, in this order and with the first failure winning: state exactly `Funded`; client and evaluator equal to `Hire.consumer`; provider equal to the agent wallet; agent id equal to the hire's; token equal to the configured USDC SAC; budget equal to `Hire.price`; `expired_at` equal to the value stored when the hire was created. Only when every check passes MUST it build the `Payment` from the job (payer = client, payee = provider, amount = budget, transaction = the submission's hash), move the hire `open -> funded` through `Hire.fund`, and store the payment with the job id. The check is the pure domain function `verifyFunding`; the fee is never checked (ADR-0005 D7). The transaction status and the `JobFunded` event are the tracker's evidence, read with the shared parser (`firstJobFunded`).

#### Scenario: Valid funding pays the hire

- GIVEN a `open` hire for consumer `C`, agent wallet `P`, price `B` and prepared `expired_at` `E`
- AND a successful `fund` submission for that hire whose job is `Funded` with client and evaluator `C`, provider `P`, the hire's agent id, the USDC SAC, budget `B` and `expired_at` `E`
- WHEN the effect is applied
- THEN the result is `EffectOk`
- AND the hire is `funded` and a payment is stored with payer `C`, payee `P`, amount `B`, the transaction hash and the job id

#### Scenario: A job field does not match

- GIVEN a successful `fund` submission whose job fails one check
- WHEN the effect is applied
- THEN the result is `JobMismatch` with `details.field` naming the field (`state`, `client`, `evaluator`, `provider`, `agent_id`, `token`, `budget` or `expired_at`)
- AND the hire stays `open` and nothing is stored

#### Scenario: Only Funded is accepted

- GIVEN a job in state `Open`, `Submitted`, `Completed`, `Rejected` or `Expired`
- WHEN the effect is applied
- THEN the result is `JobMismatch` with field `state`

#### Scenario: The escrow has no such job

- GIVEN the escrow returns no job for the event's job id
- WHEN the effect is applied
- THEN the result is `JobEvidenceUnavailable` and nothing is stored

#### Scenario: The submission has no usable hire

- GIVEN a successful `fund` submission with no `hireId`, or whose `hireId` names no stored hire
- WHEN the effect is applied
- THEN the result is `JobMismatch` without a field, the submission is marked `failed` and the tracker does not retry it, because no retry can make the hire appear

#### Scenario: The chain cannot be read

- GIVEN reading the job or the agent wallet fails with a ledger error
- WHEN the effect is applied
- THEN the error propagates, the submission stays `submitted` and the tracker retries it

### Requirement: Applying the effect is idempotent and replay-safe

The effect MUST be safe to apply again to the same submission (a crash can happen between storing the payment and confirming the submission). It MUST NOT bind a job, a transaction or a hire twice.

#### Scenario: Same submission applied twice

- GIVEN a hire already `funded` by the submission's transaction
- WHEN the effect is applied again
- THEN the result is `EffectOk`, without reading the chain, and no second payment is stored

#### Scenario: Hire funded by another transaction

- GIVEN a hire already `funded` by a different transaction
- WHEN the effect is applied
- THEN the result is `JobMismatch` with field `job_id`

#### Scenario: Job already bound to another hire

- GIVEN another hire already holds the job id
- WHEN the effect is applied
- THEN the result is `JobMismatch` with field `job_id` and the hire stays `open`

`details.field` is `job_id` for every case where the funding cannot be bound to this hire although the job itself may be valid: replay of a funding transaction against an already funded hire, a transaction already bound to another hire (wrong transaction) and a job id already bound to another hire (duplicate job). The contract defines only the job fields, so the three cases share one field and the effect does not report which of them applied.

#### Scenario: Hire not payable

- GIVEN a hire that is not `open`
- WHEN the effect is applied
- THEN the result is `JobMismatch` without a field

### Requirement: Payments are unique per hire, transaction and job

The `hire_payment` table MUST have unique indexes on `hireId`, `transactionHash` and `jobId`. `HireRepository.recordPayment` MUST store the payment in one insert and map a violation (SQLSTATE `23505`) of one of those three indexes, by constraint name, to `HirePaymentConflict` naming the index. A retry of the same hire and transaction MUST return the stored hire. Any other database error, including a unique violation of another constraint, MUST be rethrown.

#### Scenario: Unique violation of a known index

- GIVEN a payment that repeats the hire, the transaction or the job of a stored payment
- WHEN `recordPayment` is called
- THEN it throws `HirePaymentConflict` naming `hireId`, `transactionHash` or `jobId`

#### Scenario: Unknown constraint

- GIVEN the database reports a unique violation of a constraint that is not one of the three
- WHEN `recordPayment` is called
- THEN the database error is rethrown unchanged

### Requirement: Hire state changes only through the domain

The effect and the repository MUST change a hire's status only through the domain state machine (`Hire.fund`). The server MUST NOT write a status directly.
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
