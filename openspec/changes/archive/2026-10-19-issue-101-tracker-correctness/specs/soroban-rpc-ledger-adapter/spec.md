# Delta for soroban-rpc-ledger-adapter

The main spec has no requirement that names `sendTransaction`; the closest existing one is "LedgerUnavailable on infrastructure failure", which is extended below. The hash check is added as a new requirement.

## MODIFIED Requirements

### Requirement: LedgerUnavailable on infrastructure failure

The adapter MUST throw an adapter-level `LedgerUnavailable` error when the HTTP call fails (non-2xx status, timeout, connection error), when the JSON-RPC response contains an `error`, when a simulation response contains a `restorePreamble`, or when `sendTransaction` returns a transaction hash different from the expected one. The domain `LedgerPort` signature MUST remain unchanged. A legitimate "not found" or "not paid" result MUST NOT be reported as `LedgerUnavailable`.
(Previously: the hash-mismatch trigger did not exist.)

#### Scenario: HTTP 5xx

- GIVEN the RPC answers with HTTP 503
- WHEN any ledger operation is called
- THEN `LedgerUnavailable` is thrown

#### Scenario: Timeout or connection error

- GIVEN the HTTP client throws a timeout or socket error
- WHEN any ledger operation is called
- THEN `LedgerUnavailable` is thrown

#### Scenario: JSON-RPC error object

- GIVEN a 200 response whose body contains an `error` member
- WHEN any ledger operation is called
- THEN `LedgerUnavailable` is thrown

#### Scenario: Restore preamble

- GIVEN a simulation response containing `restorePreamble`
- WHEN a read is performed
- THEN `LedgerUnavailable` is thrown

## ADDED Requirements

### Requirement: sendTransaction verifies the expected hash

`sendTransaction(envelopeXdr, expectedHash)` MUST receive the expected transaction hash and MUST throw `LedgerUnavailable` when the hash in the RPC response differs from it. On a match it MUST behave as before. `SubmissionLedger.resend`, `escrow_relay_service`, `studio_deploy_service`, `escrow_server_submit`, the e2e tool and all test fakes MUST pass the expected hash. A stored record MUST NOT be modified by a mismatch.

#### Scenario: Hash matches

- GIVEN the RPC returns the same hash as `expectedHash`
- WHEN `sendTransaction` is called
- THEN the send result is returned normally

#### Scenario: Hash mismatch

- GIVEN the RPC returns a hash different from `expectedHash`
- WHEN `sendTransaction` is called
- THEN `LedgerUnavailable` is thrown

#### Scenario: Resend keeps the record

- GIVEN a `submitted` record and a mismatching resend
- WHEN the tracker resends
- THEN the record stays `submitted` with its original hash
