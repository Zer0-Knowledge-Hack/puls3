# Escrow Settlement Tracking Specification

## Purpose

Defines what a confirmed server-relayed `release` or `claim_refund` means for its hire, and how a relayed escrow call that never succeeds is closed. Agent-signed `submit` is out of scope.

## Requirements

### Requirement: Confirmed release completes the hire

When the tracker confirms a `release` submission for a hire, that hire MUST read as `HireStatus.completed`. The tracker MUST keep marking the submission `confirmed`; the status is derived from the confirmed submission, with no schema migration. Re-applying the same confirmation MUST be a no-op.

#### Scenario: Release confirmed

- GIVEN a funded hire with a relayed `release` submission whose transaction succeeded
- WHEN the tracker polls it
- THEN the submission is `confirmed` and the hire status is `completed`

#### Scenario: Release still submitted or failed

- GIVEN a `release` submission in `submitted` or `failed`
- WHEN the hire is read
- THEN its status is not `completed`

#### Scenario: Confirmation applied twice

- GIVEN a hire already `completed` by a confirmed `release`
- WHEN the tracker processes the same submission again
- THEN the status stays `completed` and nothing else changes

### Requirement: Confirmed claim_refund expires the hire

When the tracker confirms a `claim_refund` submission, the hire MUST read as `HireStatus.expired` (the refund outcome in `puls3_domain` `HireStatus`; no `refunded` status exists).

#### Scenario: Refund confirmed

- GIVEN a funded hire with a relayed `claim_refund` whose transaction succeeded
- WHEN the tracker polls it
- THEN the submission is `confirmed` and the hire status is `expired`

### Requirement: Exhausted relay attempts fail the record

A relayed `release` or `claim_refund` is exhausted when it is the 3rd failed attempt of that purpose for that hire (`maxEscrowCallAttempts`). The system MUST then record the submission `failed` with `EscrowCallFailed`. Failures 1 and 2 MUST NOT write `EscrowCallFailed`. Failed attempts of one purpose MUST NOT count toward the other purpose or another hire.

#### Scenario: Third failure

- GIVEN a hire with two failed `release` attempts
- WHEN a third `release` attempt fails
- THEN that record is `failed` with `EscrowCallFailed`
- AND no fourth envelope is built

#### Scenario: Below the limit

- GIVEN a hire with one failed `release` attempt
- WHEN a second attempt fails
- THEN `EscrowCallFailed` is not recorded and a retry stays possible

#### Scenario: Counts are scoped

- GIVEN two failed `release` attempts on hire H1 and one failed `claim_refund` on H1
- WHEN a `release` attempt for hire H2 fails
- THEN no `EscrowCallFailed` is recorded for H1 or H2

#### Scenario: Stuck call stops blocking

- GIVEN a `release` for hire H1 exhausted with `EscrowCallFailed`
- WHEN another hire's escrow call is relayed
- THEN H1 no longer occupies the in-flight relay slot
