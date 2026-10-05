# Soroban RPC Ledger Adapter Specification

## Purpose

A read-only adapter in `puls3_server` that implements the domain `LedgerPort` (`agentWallet`, `findPayment`) over Soroban JSON-RPC, with environment-based configuration and adapter-level error mapping. It never signs or submits transactions.

## ADDED Requirements

### Requirement: Stellar configuration from environment

The server MUST provide a `StellarConfig` built from `PULS3_STELLAR_*` environment variables covering at least the RPC URL, network passphrase, registry contract id, escrow contract id, USDC SAC contract id and the simulation source account. Any variable that is unset MUST fall back to the matching value of `StellarConfig.testnet`. A set variable MUST override the fallback.

#### Scenario: Environment overrides the default

- GIVEN `PULS3_STELLAR_RPC_URL` is set to a custom URL
- WHEN `StellarConfig` is built from the environment
- THEN its RPC URL equals the custom URL
- AND every unset field equals the corresponding `StellarConfig.testnet` field

#### Scenario: Empty environment yields testnet defaults

- GIVEN no `PULS3_STELLAR_*` variable is set
- WHEN `StellarConfig` is built from the environment
- THEN the result equals `StellarConfig.testnet`

### Requirement: Testnet constant mirrors the deployment record

`StellarConfig.testnet` MUST expose the public testnet RPC URL, passphrase, registry id, escrow id and USDC SAC id. A drift test MUST fail whenever any of these values differs from `contracts/deployments/testnet.json`.

#### Scenario: Constant matches the deployment file

- GIVEN `contracts/deployments/testnet.json` is readable by the test
- WHEN the drift test compares it with `StellarConfig.testnet`
- THEN registry, escrow, USDC SAC and RPC URL are all equal

#### Scenario: Drift is detected

- GIVEN the deployment file records a different escrow id than the constant
- WHEN the drift test runs
- THEN the test fails

### Requirement: Unsigned invoke envelope encoding

The adapter MUST encode unsigned Soroban `invokeHostFunction` transaction envelopes in-repo (contract id, function name, ScVal arguments, source account) and submit them only to `simulateTransaction`. A golden test MUST assert that the base64 output for a fixed input equals the output captured from `stellar contract invoke --build-only`.

#### Scenario: Golden envelope match

- GIVEN a fixed contract id, function, arguments and source account
- WHEN the encoder produces the envelope
- THEN its base64 equals the recorded stellar-cli golden value byte for byte

#### Scenario: No signing or submission

- GIVEN any ledger operation
- WHEN it talks to the RPC
- THEN it only calls `simulateTransaction` and `getTransaction`
- AND it never calls `sendTransaction`

### Requirement: ScVal JSON decoding

The adapter MUST decode simulation and event values from the RPC JSON format into Dart values. A `void` ScVal MUST decode to `null`. An `address` ScVal MUST decode to a Stellar strkey string. A `map` ScVal MUST decode to a key-to-value map keyed by symbol. Unknown or malformed shapes MUST be treated as a failed decode (never a crash with an uncaught type error).

#### Scenario: Void becomes null

- GIVEN a simulation result whose value is `void`
- WHEN it is decoded
- THEN the decoded value is `null`

#### Scenario: Address decoded

- GIVEN a result whose value is an `address` ScVal
- WHEN it is decoded
- THEN the decoded value is the corresponding `G...` or `C...` strkey

#### Scenario: Map decoded

- GIVEN a result whose value is a `map` of symbol keys (a job record)
- WHEN it is decoded
- THEN each symbol key maps to its decoded value

### Requirement: agentWallet lookup

`SorobanLedger.agentWallet(AgentId)` MUST return the agent's `StellarAddress` read from the registry contract through simulation, or `null` when the contract returns `void`.

#### Scenario: Registered agent

- GIVEN the registry simulation returns an address for the agent
- WHEN `agentWallet` is called
- THEN it returns that `StellarAddress`

#### Scenario: Unknown agent

- GIVEN the registry simulation returns `void`
- WHEN `agentWallet` is called
- THEN it returns `null`

### Requirement: findPayment validation

`SorobanLedger.findPayment(TransactionHash)` MUST query `getTransaction` with `xdrFormat: "json"` and return a `Payment` only when ALL of the following hold: the transaction status is `SUCCESS`; a contract event is a `transfer` emitted by the configured USDC SAC contract; the transfer has a muxed destination carrying a hire id (`to_muxed_id`); and the amount is within the accepted range. In every other case it MUST return `null`. When several events satisfy all conditions, the first matching event MUST win. The adapter MUST NOT check for reused transaction hashes.

#### Scenario: Valid payment

- GIVEN a SUCCESS transaction with a USDC SAC `transfer` carrying a muxed hire id and an in-range amount
- WHEN `findPayment` is called
- THEN it returns a `Payment` with the event's amount and hire id

#### Scenario: Failed transaction

- GIVEN the transaction status is `FAILED`
- WHEN `findPayment` is called
- THEN it returns `null`

#### Scenario: Transaction not found

- GIVEN the RPC reports status `NOT_FOUND`
- WHEN `findPayment` is called
- THEN it returns `null`

#### Scenario: Wrong SAC

- GIVEN a SUCCESS transaction whose `transfer` event is emitted by a contract other than the configured USDC SAC
- WHEN `findPayment` is called
- THEN it returns `null`

#### Scenario: Non-muxed destination

- GIVEN a SUCCESS USDC `transfer` whose destination has no muxed id
- WHEN `findPayment` is called
- THEN it returns `null`

#### Scenario: Amount out of range

- GIVEN a SUCCESS USDC `transfer` with a zero, negative or out-of-range amount
- WHEN `findPayment` is called
- THEN it returns `null`

#### Scenario: First matching event wins

- GIVEN a SUCCESS transaction with two events that both satisfy every condition but carry different hire ids
- WHEN `findPayment` is called
- THEN the returned `Payment` reflects the first event only

### Requirement: LedgerUnavailable on infrastructure failure

The adapter MUST throw an adapter-level `LedgerUnavailable` error when the HTTP call fails (non-2xx status, timeout, connection error), when the JSON-RPC response contains an `error`, or when a simulation response contains a `restorePreamble`. The domain `LedgerPort` signature MUST remain unchanged. A legitimate "not found" or "not paid" result MUST NOT be reported as `LedgerUnavailable`.

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

### Requirement: Offline testability

All adapter logic MUST depend only on an injected `http.Client`, so unit tests run with `MockClient` and recorded fixtures. Ledger tests MUST pass without network access, PostgreSQL or Redis.

#### Scenario: Tests run offline

- GIVEN no network, database or cache is available
- WHEN `dart test test/unit/ledger/` runs in `puls3_server`
- THEN all ledger tests pass using `MockClient` and recorded fixtures
