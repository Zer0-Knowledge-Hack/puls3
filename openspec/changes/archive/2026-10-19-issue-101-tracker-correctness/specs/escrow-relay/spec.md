# Delta for escrow-relay

## MODIFIED Requirements

### Requirement: Settlement of complete and reject depends on #97

`prepareComplete`, `prepareReject` and their submissions MUST work through the relay. The tracker effects that move a hire to `completed` or `rejected` still belong to #97. Until then a chain-SUCCESS `complete`, `reject` or `registerFull` submission MUST become `confirmed` and MUST NOT change the hire. Because the hire status does not change, the app MAY be offered `prepareComplete` again; the contract then rejects it as `TransactionFailed`. This caveat MUST be documented in the README tracker paragraph and in the tracker doc comment.
(Previously: the submission remained `submitted` and blocked later prepares with `SubmissionInProgress`.)

#### Scenario: Complete confirms without hire change

- GIVEN a relayed `complete` or `reject` submission whose transaction is SUCCESS
- WHEN the tracker runs
- THEN the submission is `confirmed` and the hire status is unchanged

#### Scenario: Prepare after a confirmed settlement

- GIVEN a confirmed `complete` submission and a hire whose status is unchanged
- WHEN `prepareComplete` is called
- THEN it is not rejected with `SubmissionInProgress`

### Requirement: One escrow submission in flight per hire

While a hire has a `submitted` escrow record, every `prepare...` method MUST raise `SubmissionInProgress`, and `createHire` MUST NOT issue a new preparation. `prepareFund` MUST raise `PaymentAlreadySubmitted` when an earlier `fund` for the hire reached `SUCCESS` on chain, even if verification then failed (the `fund` record is `failed` with `JobMismatch` or `JobEvidenceUnavailable`). A hire with any escrow record `failed` with `OutcomeUnknown` MUST reject every `prepare...` method until manually resolved. Hire state that disallows the purpose raises `InvalidHireTransition`.
(Previously: no `OutcomeUnknown` case.)

#### Scenario: Submission in flight

- GIVEN a hire with a `submitted` escrow `ChainSubmission`
- WHEN any prepare method is called for it
- THEN it fails with `SubmissionInProgress`

#### Scenario: Fund already reached the chain

- GIVEN a hire whose earlier `fund` succeeded on chain and then failed with `JobMismatch` or `JobEvidenceUnavailable`
- WHEN `prepareFund` is called
- THEN it fails with `PaymentAlreadySubmitted` and no preparation is created

#### Scenario: Re-prepare after a final failure

- GIVEN a hire whose last escrow record is `failed` with `SubmissionRejected` or `PreparationExpired`
- WHEN the same prepare method is called
- THEN a new preparation is returned and the previous one is superseded

#### Scenario: No re-prepare after OutcomeUnknown

- GIVEN a hire with an escrow record `failed` with `OutcomeUnknown`
- WHEN any prepare method is called
- THEN it is rejected and no preparation is created
- AND the hire stays blocked until manual resolution

#### Scenario: Wrong hire state

- GIVEN a hire whose state does not allow the requested purpose
- WHEN the prepare method is called
- THEN it fails with `InvalidHireTransition`
