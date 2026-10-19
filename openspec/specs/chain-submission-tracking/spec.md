# Chain Submission Tracking Specification

## Purpose

Defines how the server-side `ChainSubmissionTracker` turns the chain state of a stored `ChainSubmission` into a final outcome (`confirmed` or `failed` with an outcome code), so that a recorded outcome never contradicts what happened on chain.

## ADDED Requirements

### Requirement: Expired fund is reconciled through the escrow job

When the chain answers NOT_FOUND for a `submitted` `fund` record and chain time is past the envelope `validUntil`, the tracker MUST read the escrow job (`EscrowJobReader.escrowJob(jobId)`). If the job exists in state `Funded` or any later state, the transaction MUST be treated as landed and the record MUST follow the confirm path (the same effects as a `fund` SUCCESS). If the job is `Open` (the fund never landed), the record MUST fail with `PreparationExpired`. If the escrow cannot establish either way (the hire has no job id, the job is missing, or the job is `Expired`), the record follows the retention rule: `PreparationExpired` while the node still retains the ledgers since the record was created, `OutcomeUnknown` otherwise. If the job reader is unavailable, the record MUST stay `submitted` for a later pass.

#### Scenario: Landed fund after an RPC outage

- GIVEN a `submitted` `fund` record past `validUntil` whose hash is NOT_FOUND on RPC
- AND the escrow job for its job id is `Funded`
- WHEN the tracker runs
- THEN the record becomes `confirmed` through the fund confirm path
- AND it is NOT failed as `PreparationExpired`

#### Scenario: Job in a later state

- GIVEN the same record and the escrow job is `Completed` (or any state after `Funded`)
- WHEN the tracker runs
- THEN the record becomes `confirmed`

#### Scenario: Expired fund that never landed, within retention

- GIVEN a `submitted` `fund` record past `validUntil`, within the RPC retention window, NOT_FOUND on RPC
- AND the escrow job is `Open`, or the escrow cannot establish the job (no job id, job missing or `Expired`)
- WHEN the tracker runs
- THEN the record becomes `failed` with `errorCode = PreparationExpired`

#### Scenario: Job reader unavailable

- GIVEN an expired `fund` record and the job lookup throws an infrastructure error
- WHEN the tracker runs
- THEN the record stays `submitted` and is retried on a later pass

### Requirement: Unreconcilable expiry fails as OutcomeUnknown

`SubmissionOutcomeCode` MUST include `OutcomeUnknown`. A `submitted` record that is NOT_FOUND, past `validUntil` AND past the RPC retention window, and for which no reconciliation is possible, MUST fail with `OutcomeUnknown` and MUST NOT fail with `PreparationExpired`. Reconciliation is impossible for `createJob` (no job id exists before its event). For `fund`, an `Open` job proves the fund never landed and gives `PreparationExpired` whatever the retention window; `OutcomeUnknown` applies only if the escrow cannot establish the job (no job id, job missing or `Expired`) while the transaction can no longer be queried. `OutcomeUnknown` MUST be accepted by the code validator (`isKnown`), the store outcome-code check, `docs/architecture/api.md`, and the `.spy.yaml` protocol comment.

#### Scenario: createJob past retention

- GIVEN a `submitted` `createJob` record past `validUntil` and past the retention window, NOT_FOUND on RPC
- WHEN the tracker runs
- THEN the record becomes `failed` with `errorCode = OutcomeUnknown`

#### Scenario: createJob expired within retention

- GIVEN a `submitted` `createJob` record past `validUntil` but within the retention window, NOT_FOUND on RPC
- WHEN the tracker runs
- THEN the record becomes `failed` with `errorCode = PreparationExpired`

#### Scenario: fund past retention without proof

- GIVEN a `submitted` `fund` record past `validUntil` and past retention
- AND the escrow cannot establish the job (no job id, job missing or `Expired`)
- WHEN the tracker runs
- THEN the record becomes `failed` with `errorCode = OutcomeUnknown`

#### Scenario: Code is persistable

- GIVEN a record failing with `OutcomeUnknown`
- WHEN the store writes it
- THEN the store check accepts the code and `isKnown('OutcomeUnknown')` is true

### Requirement: No re-prepare after OutcomeUnknown

While any escrow record of a hire is `failed` with `OutcomeUnknown`, every `prepare...` method MUST be rejected and the hire MUST stay blocked until the outcome is resolved manually. This differs from `SubmissionRejected` and `PreparationExpired`, after which a new preparation is allowed. The tracker MUST NOT clear the block automatically.

#### Scenario: Prepare is blocked

- GIVEN a hire with an escrow record `failed` with `OutcomeUnknown`
- WHEN any `prepare...` method is called
- THEN it is rejected and no preparation is created

#### Scenario: Contrast with PreparationExpired

- GIVEN a hire whose last escrow record is `failed` with `PreparationExpired`
- WHEN the same prepare method is called
- THEN a new preparation is returned

### Requirement: Valid chain events are matched to the submission

When a transaction result carries several valid `job_created` or `job_funded` events from the escrow contract, the lookup MUST expose all of them and the tracker/effects MUST select the one belonging to the submission (the expected job id for `fund`, the hire binding for `createJob`). Malformed events and events from other contracts MUST be skipped, wherever they appear in the list. If no valid event matches the submission, the record MUST fail with `JobMismatch` when valid events exist but none match, and follow the no-event path when no valid event exists.

#### Scenario: Several valid events

- GIVEN a SUCCESS transaction with two valid `job_created` events for different jobs
- WHEN the tracker processes it
- THEN the effects use the event whose binding matches the submission, not the first one

#### Scenario: Matching event is not first

- GIVEN a SUCCESS `fund` with valid `job_funded` events for job 7 then job 9, and the submission expects job 9
- WHEN the tracker processes it
- THEN the record is confirmed using the job 9 event

#### Scenario: Malformed then valid

- GIVEN a malformed event followed by a valid matching event
- WHEN the tracker processes it
- THEN the valid matching event is used

#### Scenario: Other contract first

- GIVEN an event from another contract followed by a valid matching escrow event
- WHEN the tracker processes it
- THEN the escrow event is used

#### Scenario: Valid events, none matching

- GIVEN valid events that all belong to other jobs or hires
- WHEN the tracker processes the SUCCESS
- THEN the record fails with `JobMismatch`

### Requirement: complete, reject and registerFull confirm without domain effect

On chain SUCCESS, `complete`, `reject` and `registerFull` records MUST become `confirmed` and MUST NOT change the hire or any other domain state. The tracker doc comment and the README tracker paragraph MUST document the caveat that the hire status does not change until #97, so the app may offer `prepareComplete` again and the contract then rejects it as `TransactionFailed`. `setAgentWallet` and `submit` records MUST remain untracked by this requirement.

#### Scenario: complete succeeds

- GIVEN a `submitted` `complete` record whose transaction is SUCCESS
- WHEN the tracker runs
- THEN the record becomes `confirmed` and the hire status is unchanged

#### Scenario: reject succeeds

- GIVEN a `submitted` `reject` record whose transaction is SUCCESS
- WHEN the tracker runs
- THEN the record becomes `confirmed` and the hire status is unchanged

#### Scenario: registerFull succeeds

- GIVEN a `submitted` `registerFull` record whose transaction is SUCCESS
- WHEN the tracker runs
- THEN the record becomes `confirmed` with no domain effect

#### Scenario: No longer blocks later prepares

- GIVEN a confirmed `complete` record
- WHEN a prepare method is called for the hire
- THEN it is not rejected with `SubmissionInProgress`

#### Scenario: Failed settlement transaction

- GIVEN a `complete` record whose transaction is FAILED on chain
- WHEN the tracker runs
- THEN the record fails with `TransactionFailed`

#### Scenario: setAgentWallet and submit unchanged

- GIVEN a `setAgentWallet` or `submit` record
- WHEN the tracker runs
- THEN this change does not alter their handling

### Requirement: SUCCESS without a parsable event is retried three passes

When a `fund` or `createJob` transaction is SUCCESS but no parsable matching event is available, the tracker MUST keep the record `submitted` and retry on later passes. After 3 attempts (one per pass) without an event, the record MUST fail with `JobEvidenceUnavailable`. The attempt counter MUST be kept in memory per submission record, MUST be cleared when the record reaches a final state, and is lost on restart; the restart reset MUST be documented. Persisted counters and DB migrations are out of scope.

#### Scenario: Event appears on the second pass

- GIVEN a SUCCESS transaction with no event on pass 1 and a valid event on pass 2
- WHEN the tracker runs twice
- THEN the record is confirmed on pass 2 and was not failed

#### Scenario: Three passes without an event

- GIVEN a SUCCESS transaction that never exposes an event
- WHEN the tracker runs three passes
- THEN after the third pass the record is `failed` with `JobEvidenceUnavailable`
- AND after passes 1 and 2 it was still `submitted`

#### Scenario: Restart resets the counter

- GIVEN two passes without an event, then a server restart
- WHEN the tracker runs again
- THEN the count restarts at one and the record is still `submitted`

### Requirement: Resend verifies the expected hash

When the tracker resends a stored envelope, it MUST pass the stored `transactionHash` as the expected hash. If the hash computed by the ledger differs, the resend MUST throw `LedgerUnavailable`, and the record MUST stay `submitted` and unchanged.

#### Scenario: Matching hash

- GIVEN a `submitted` record whose resend returns the stored hash
- WHEN the tracker resends
- THEN the record is processed normally

#### Scenario: Hash mismatch

- GIVEN a resend where the ledger reports a different hash
- WHEN the tracker resends
- THEN `LedgerUnavailable` is raised and the record stays `submitted`
