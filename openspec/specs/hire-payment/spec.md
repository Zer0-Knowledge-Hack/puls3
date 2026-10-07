# Hire Payment Specification

## Purpose

Lets the server create hires and verify, from chain evidence, that an escrow job funded by a relayed `fund` transaction pays exactly one hire. The server never custodies or signs: the consumer signs `create_job` and `fund`, the server relays them, and the chain tracker (`ChainSubmissionTracker`) applies the verified outcome to the hire.

> **Status:** there is no public hire endpoint. A client-supplied transaction hash let anyone claim a public funding transaction, so payments follow the server relay (Decision A in `docs/architecture/api.md`), delivered in #96 and #97. The server-internal parts live here: hire creation, the funding checks of `docs/architecture/api.md` (`HireEscrowEffects.onFunded`, `verifyFunding`), and the `hire_payment` unique indexes.

## Requirements

### Requirement: Create an open hire

`HireService.createHire` MUST accept an `agent_id` and the consumer Stellar address, persist a hire in status `open` with the agent's price and manifest version, and store the `expired_at` the server prepares `create_job` with. It MUST NOT move funds, sign, or submit any transaction, and it MUST NOT return payment instructions: the prepared `create_job` envelope belongs to the relay (#96). The agent MUST have a wallet and a manifest version (`puls3.manifestVersion`, ADR-0004) of at least 1; the system MUST NOT invent a fallback version.

#### Scenario: Hire created

- GIVEN a registered agent with a wallet, a price and a manifest version of at least 1
- AND a configured `PULS3_HIRE_JOB_DURATION_SECONDS`
- WHEN `createHire` is called with the agent id and a consumer address
- THEN a hire exists with status `open`, the agent's price and the consumer
- AND the stored `expired_at` equals now plus the configured duration

#### Scenario: Unknown agent

- GIVEN an agent id that is not in the registry or has no wallet
- WHEN `createHire` is called
- THEN no hire is persisted
- AND the call fails with the typed error `AgentUnavailable` naming the agent

#### Scenario: Ledger unavailable on create

- GIVEN a ledger read for the catalog or the agent metadata fails with a ledger error
- WHEN `createHire` is called
- THEN no hire is persisted
- AND the failure surfaces as the typed error `HireLedgerUnavailable`

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
