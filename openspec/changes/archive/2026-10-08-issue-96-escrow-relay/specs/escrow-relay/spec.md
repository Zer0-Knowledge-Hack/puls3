# Escrow Relay Specification

## Purpose

The server prepares every client-signed escrow call, the wallet signs it unchanged, and `HireEndpoint.submitEscrowCall` verifies and relays it (Decision A, `docs/architecture/api.md`, "Server relay submission"). The server never custodies or signs for the consumer. `api.md` is authoritative for error codes and `details` payloads.

> Scope: `createHire` first preparation, `prepareCreateJob`, `prepareFund`, `prepareComplete`, `prepareReject` and `submitEscrowCall`. Tracker effects for `complete` and `reject` belong to #97. Real wallet sessions belong to #25; until then the session wallet comes from the injectable `SessionWallet` seam.

## ADDED Requirements

### Requirement: Spike gates the cryptographic implementation

Before any verification code is merged, a spike MUST prove that `stellar_dart`, running in the server, (a) decodes a recorded signed testnet transaction envelope, (b) computes the network transaction hash for the configured passphrase, and (c) verifies an ed25519 signature over that hash. If any of the three fails, the implementation MUST use `crypto` plus an ed25519 package with hand-written XDR. A TypeScript sidecar MUST NOT be used. The recorded testnet envelopes MUST be kept as golden vectors for the codec and signature tests.

#### Scenario: Spike passes

- GIVEN a recorded signed testnet envelope with known hash and signer
- WHEN the spike decodes it, hashes it for the testnet passphrase and verifies the signature
- THEN the decoded fields, the hash and the signature check match the recorded values
- AND the envelope codec adapter is built on `stellar_dart`

#### Scenario: Spike fails

- GIVEN any one of decode, hash or signature verification fails with `stellar_dart`
- WHEN the spike result is recorded
- THEN the fallback (`crypto` plus an ed25519 package, hand-written XDR) is adopted and documented
- AND no TypeScript sidecar is introduced

#### Scenario: Golden vectors protect the codec

- GIVEN the recorded testnet envelopes
- WHEN the codec tests run
- THEN decoding, hashing and signature verification reproduce the recorded hash and signer for each vector

### Requirement: Prepare returns an unsigned, server-built envelope

Each `prepare...` method (and `createHire` for the first `create_job`) MUST build the unsigned transaction envelope with the session wallet as source, the signer's current sequence number, a fee and Soroban data and authorization entries taken from `simulateTransaction`, and time bounds ending at now plus the configured preparation validity window. It MUST persist an `escrow_preparation` record (id, hire, purpose, signer, body bytes, transaction hash, time bounds, superseded flag) and return a `PreparedTransaction` carrying `preparationId`, `purpose`, `signer`, the network passphrase, the envelope XDR, `transaction` (hash) and an expiry. It MUST NOT sign. For `fund`, arguments MUST use `expected_budget = Hire.price` and `max_fee_bps = NetworkConfig.platformFeeBps`.

#### Scenario: Prepare fund

- GIVEN a hire owned by the session wallet whose `create_job` is confirmed
- WHEN `prepareFund(hireId)` is called
- THEN the result has purpose `fund`, the session wallet as `signer` and source, and an expiry equal to the time-bounds end
- AND the `fund` arguments carry `expected_budget` equal to `Hire.price` and `max_fee_bps` equal to `NetworkConfig.platformFeeBps`
- AND an `escrow_preparation` row exists with the same hash

#### Scenario: Chain unavailable while preparing

- GIVEN the account sequence, latest ledger or simulation call fails
- WHEN any prepare method is called
- THEN it fails with `ChainUnavailable` and persists no preparation

#### Scenario: Prepare complete and reject

- GIVEN a hire owned by the session wallet whose job allows `complete` (or `reject` with a valid reason)
- WHEN `prepareComplete` or `prepareReject` is called
- THEN a `PreparedTransaction` with purpose `complete` or `reject` is returned
- AND an invalid or missing reject reason fails with `InvalidRejectReason`

### Requirement: Preparation validity window is required configuration

The preparation validity window and the job `expired_at` duration MUST be read from `PULS3_*` environment configuration. Neither MUST have a default, fallback or placeholder in code. When either is missing, not a whole number, or not positive, the operation that needs it MUST fail before persisting anything.

#### Scenario: Missing preparation window

- GIVEN the preparation validity window setting is not configured or is invalid
- WHEN any prepare method (or `createHire` with a first preparation) is called
- THEN it fails with a typed configuration error naming the setting
- AND no preparation or hire is persisted

#### Scenario: Missing job duration

- GIVEN `PULS3_HIRE_JOB_DURATION_SECONDS` is not configured or is invalid
- WHEN `prepareCreateJob` or `createHire` needs `expired_at`
- THEN it fails with `HireConfigurationMissing` naming the setting

#### Scenario: No default in code

- GIVEN the configuration and server sources
- WHEN they are inspected by a test
- THEN no literal default value exists for the validity window or for `expired_at`

### Requirement: Ownership and session enforcement

Every `HireEndpoint` method MUST resolve the wallet through `SessionWallet.requireLogin` before doing any work. Where a wallet address parameter exists it MUST equal the session wallet, otherwise `WalletMismatch`. A hire not owned by the session wallet MUST raise `HireNotOwned`. A `preparationId` that is unknown, belongs to another hire, or belongs to another wallet MUST raise `PreparationNotFound`.

#### Scenario: Not logged in

- GIVEN the `SessionWallet` seam reports no session
- WHEN any `HireEndpoint` method is called
- THEN the unauthenticated outcome is raised and no store or chain call is made

#### Scenario: Every method enforces the seam

- GIVEN a fake `SessionWallet` that records calls
- WHEN each hire method is invoked in turn
- THEN `requireLogin` is called by each of them

#### Scenario: Hire not owned

- GIVEN a hire whose consumer is not the session wallet
- WHEN any prepare method or `submitEscrowCall` is called for it
- THEN it fails with `HireNotOwned` and nothing is persisted

#### Scenario: Wallet parameter differs from the session

- GIVEN `createHire` is called with a `consumer` address different from the session wallet
- WHEN the call is made
- THEN it fails with `WalletMismatch` and no hire is persisted

#### Scenario: Unknown or foreign preparation

- GIVEN a `preparationId` that does not exist, or belongs to another hire or wallet
- WHEN `submitEscrowCall` is called
- THEN it fails with `PreparationNotFound`

#### Scenario: Invalid or unknown hire

- GIVEN a non-positive hire id, or an id that names no hire
- WHEN a prepare method or `submitEscrowCall` is called
- THEN it fails with `InvalidHireId` or `HireNotFound` respectively

### Requirement: Preparation expiry and supersession

`submitEscrowCall` MUST reject a preparation whose envelope time bounds have passed with `PreparationExpired` (`details.reason = timeBounds`), and a preparation replaced by a newer one for the same resource with `PreparationExpired` (`details.reason = superseded`). A new preparation for a resource MUST supersede the previous one and MUST reuse the signer's current sequence number, so at most one of them can be included on chain. These checks run synchronously, after ownership checks and before envelope verification.

#### Scenario: Time bounds passed

- GIVEN a preparation whose time-bounds end is earlier than the current time
- WHEN `submitEscrowCall` is called with it
- THEN it fails with `PreparationExpired` and `details.reason = timeBounds`
- AND no `ChainSubmission` is stored and nothing is sent

#### Scenario: Superseded preparation

- GIVEN two preparations for the same hire and purpose, the second created later
- WHEN `submitEscrowCall` is called with the first
- THEN it fails with `PreparationExpired` and `details.reason = superseded`

#### Scenario: Supersession reuses the sequence number

- GIVEN a prepared envelope that has not been submitted
- WHEN the same prepare method is called again
- THEN the new envelope uses the same sequence number as the first
- AND the first preparation is marked superseded

### Requirement: Signed envelope verification

`submitEscrowCall` MUST verify the signed XDR against the stored preparation, in this order, with the first failure winning: well-formedness (`InvalidSignedEnvelope`), body equality (`EnvelopeMismatch`), signature (`InvalidTransactionSignature`).

`InvalidSignedEnvelope` applies when the XDR is empty, not base64, truncated, has trailing bytes, or is a fee-bump envelope.

`EnvelopeMismatch` applies when the transaction body differs in any byte from the prepared body. Comparison is by body bytes; decoding is used only to name `details.field`, the first differing group in this order: `contract`, `function`, `arguments`, `source`, `timeBounds`. A difference outside those groups (for example fee, sequence number, Soroban data, memo, or envelope type) MUST still raise `EnvelopeMismatch` with `details.field = other`.

`InvalidTransactionSignature` applies when the envelope carries no signature from the session wallet or one that does not verify over the transaction hash for the configured network. `details.reason` is `missing` (no signatures), `wrongSigner` (signatures exist but none from the session wallet) or `doesNotVerify` (a signature from the session wallet fails verification).

#### Scenario: Malformed envelopes

- GIVEN a signed XDR that is empty, not base64, truncated, has trailing bytes, or is a fee-bump envelope
- WHEN `submitEscrowCall` is called
- THEN it fails with `InvalidSignedEnvelope` and nothing is stored or sent

#### Scenario: Body differs by contract

- GIVEN a signed envelope whose invoked contract address differs from the prepared one
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = contract`

#### Scenario: Body differs by function

- GIVEN a signed envelope invoking a different function (for example `complete` instead of `fund`)
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = function`

#### Scenario: Body differs by arguments

- GIVEN a signed envelope with any changed argument (for example a different budget or provider)
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = arguments`

#### Scenario: Body differs by source

- GIVEN a signed envelope whose source account differs from the prepared one
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = source`

#### Scenario: Body differs by time bounds

- GIVEN a signed envelope whose time bounds differ from the prepared ones
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = timeBounds`

#### Scenario: Body differs outside the named groups

- GIVEN a signed envelope whose fee, sequence number, Soroban data, memo or envelope type differs
- WHEN `submitEscrowCall` is called
- THEN it fails with `EnvelopeMismatch` and `details.field = other`

#### Scenario: Unsigned envelope

- GIVEN an envelope identical to the prepared body with no signatures
- WHEN `submitEscrowCall` is called
- THEN it fails with `InvalidTransactionSignature` and `details.reason = missing`

#### Scenario: Signed by another key

- GIVEN an envelope signed only by a key other than the session wallet
- WHEN `submitEscrowCall` is called
- THEN it fails with `InvalidTransactionSignature` and `details.reason = wrongSigner`

#### Scenario: Signature does not verify

- GIVEN an envelope whose session-wallet signature is over different bytes or for another network passphrase
- WHEN `submitEscrowCall` is called
- THEN it fails with `InvalidTransactionSignature` and `details.reason = doesNotVerify`

#### Scenario: Verification precedes persistence

- GIVEN any verification failure above
- WHEN `submitEscrowCall` fails
- THEN no `ChainSubmission` is inserted and `sendTransaction` is not called

### Requirement: Persist, then send; chain outcomes never throw from submit

After verification, the server MUST store the final signed envelope and its hash as a `ChainSubmission` with state `submitted` and only then call `sendTransaction`. `submitEscrowCall` MUST return `HireDetail` for every chain outcome and MUST NOT throw them: a definitive RPC rejection sets the record to `failed` with `errorCode = SubmissionRejected` and a safe server-side log reason; an unreachable or timed-out RPC leaves the record `submitted` for the tracker to resend. Only the verification errors of this spec and the hire-level errors (`InvalidHireId`, `HireNotFound`, `HireNotOwned`, `InvalidHireTransition`) are thrown.

#### Scenario: Accepted by RPC

- GIVEN a verified envelope
- WHEN `submitEscrowCall` is called and RPC accepts the transaction
- THEN a `ChainSubmission` exists in state `submitted` with the envelope hash, written before `sendTransaction` was called
- AND the returned `HireDetail.escrowSubmission` is that record

#### Scenario: Definitive RPC rejection

- GIVEN RPC rejects the transaction definitively (for example bad sequence or insufficient fee)
- WHEN `submitEscrowCall` is called
- THEN the call returns normally with `escrowSubmission.state = failed` and `errorCode = SubmissionRejected`
- AND the call does not throw

#### Scenario: RPC unreachable

- GIVEN `sendTransaction` times out or cannot connect
- WHEN `submitEscrowCall` is called
- THEN the call returns normally with the record still `submitted`
- AND the call does not throw and no second send is made by the call

#### Scenario: Invalid hire transition

- GIVEN the hire state does not allow the purpose of the preparation
- WHEN `submitEscrowCall` is called
- THEN it fails with `InvalidHireTransition` and nothing is stored

### Requirement: At most one submission per preparation

Each preparation MUST have at most one `ChainSubmission`. A `submitEscrowCall` for a preparation that already has one MUST re-run the verification of the previous requirement and then return the existing record, without building, signing or sending a new envelope. The order is: load preparation, check ownership, supersession and time bounds, verify the envelope, `findByPreparation`, `insertSubmitted`. A `ChainSubmissionConflict` from `insertSubmitted` MUST be resolved by re-reading the existing record.

#### Scenario: Repeated submit returns the existing record

- GIVEN a preparation that already has a `ChainSubmission`
- WHEN `submitEscrowCall` is called again with the same signed XDR
- THEN `sendTransaction` is not called again
- AND the returned `escrowSubmission` is the existing record with its original hash

#### Scenario: Repeated submit is still verified

- GIVEN a preparation that already has a `ChainSubmission`
- WHEN `submitEscrowCall` is called with a tampered envelope
- THEN it fails with `EnvelopeMismatch` and the existing record is unchanged

#### Scenario: Concurrent submits

- GIVEN two concurrent verified submits for one preparation
- WHEN both reach `insertSubmitted` and one raises `ChainSubmissionConflict`
- THEN the loser re-reads and returns the winner's record
- AND `sendTransaction` is called at most once for the preparation

### Requirement: One escrow submission in flight per hire

While a hire has a `submitted` escrow record, every `prepare...` method MUST raise `SubmissionInProgress`, and `createHire` MUST NOT issue a new preparation. `prepareFund` MUST raise `PaymentAlreadySubmitted` when an earlier `fund` for the hire reached `SUCCESS` on chain, even if verification then failed (the `fund` record is `failed` with `JobMismatch` or `JobEvidenceUnavailable`). Hire state that disallows the purpose raises `InvalidHireTransition`.

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

#### Scenario: Wrong hire state

- GIVEN a hire whose state does not allow the requested purpose
- WHEN the prepare method is called
- THEN it fails with `InvalidHireTransition`

### Requirement: Settlement of complete and reject depends on #97

`prepareComplete`, `prepareReject` and their submissions MUST work through the relay, but the tracker effects that move a hire to `completed` or `rejected` belong to #97. Until then a confirmed-on-chain `complete` or `reject` submission MUST remain `submitted` and MUST NOT change the hire.

#### Scenario: Complete stays submitted

- GIVEN a relayed `complete` or `reject` submission
- WHEN the tracker runs
- THEN the submission stays `submitted` and the hire status is unchanged
