# Delta for Hire Payment

## ADDED Requirements

### Requirement: Hire status derives settlement from confirmed submissions

Hire status reads MUST report `completed` when the hire has a `confirmed` `release` submission and `expired` when it has a `confirmed` `claim_refund` submission, taking precedence over `funded`. A hire without either keeps its current derived status. `submitted` and `rejected` MUST remain unpersisted (#97 remainder). See `escrow-settlement-tracking`.

#### Scenario: Completed from confirmed release

- GIVEN a funded hire and a `confirmed` `release` submission
- WHEN the hire is loaded
- THEN its status is `completed`

#### Scenario: Expired from confirmed claim_refund

- GIVEN a funded hire and a `confirmed` `claim_refund` submission
- WHEN the hire is loaded
- THEN its status is `expired`

#### Scenario: Funded stays funded

- GIVEN a funded hire whose escrow submission is `submitted` or `failed`
- WHEN the hire is loaded
- THEN its status is `funded`

## MODIFIED Requirements

### Requirement: Hire state changes only through the domain

The effect and the repository MUST change a hire's status only through the domain state machine (`Hire.fund`). The server MUST NOT write a status directly. The only exception is the read-time derivation of `completed` and `expired` from confirmed `release` and `claim_refund` submissions, which writes no status.
(Previously: no exception for derived settlement status.)

#### Scenario: No direct status write

- GIVEN the repository and the effects
- WHEN a hire is funded
- THEN the status changes only through `Hire.fund`

#### Scenario: Derived status writes nothing

- GIVEN a confirmed `release` submission
- WHEN the hire is read as `completed`
- THEN no hire row status is written
