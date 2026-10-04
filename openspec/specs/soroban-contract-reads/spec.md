# Soroban Contract Reads Specification

## Purpose

Read-only registry and escrow queries executed through `simulateTransaction`, exposed by `SorobanLedger` beyond the `LedgerPort` surface.

## ADDED Requirements

### Requirement: Registry agentExists

`SorobanLedger.agentExists(AgentId)` MUST call the registry contract through simulation and return a boolean indicating whether the agent is registered.

#### Scenario: Registered agent exists

- GIVEN the registry simulation returns `true`
- WHEN `agentExists` is called
- THEN it returns `true`

#### Scenario: Unregistered agent

- GIVEN the registry simulation returns `false`
- WHEN `agentExists` is called
- THEN it returns `false`

### Requirement: Registry agentUri

`SorobanLedger.agentUri(AgentId)` MUST return the agent's metadata URI string from the registry, or `null` when the contract returns `void`.

#### Scenario: URI present

- GIVEN the registry simulation returns a string value
- WHEN `agentUri` is called
- THEN it returns that string

#### Scenario: URI absent

- GIVEN the registry simulation returns `void`
- WHEN `agentUri` is called
- THEN it returns `null`

### Requirement: Escrow job read

`SorobanLedger.escrowJob(...)` MUST call the escrow `get_job` function through simulation and return a server-local job record decoded from the returned `map` ScVal, or `null` when the contract returns `void`. The record type MUST live in the server package and MUST NOT modify `puls3_domain`.

#### Scenario: Job found

- GIVEN the escrow simulation returns a `map` with the job fields
- WHEN `escrowJob` is called
- THEN it returns a record whose fields equal the decoded map entries

#### Scenario: Job missing

- GIVEN the escrow simulation returns `void`
- WHEN `escrowJob` is called
- THEN it returns `null`

### Requirement: Reads are simulation-only and fail safely

Every contract read MUST use `simulateTransaction` with an unsigned envelope built from the configured source account, MUST throw `LedgerUnavailable` on HTTP error, JSON-RPC error or `restorePreamble`, and MUST be testable offline with `MockClient` without PostgreSQL or Redis.

#### Scenario: Simulation failure on a read

- GIVEN the RPC responds with a JSON-RPC error to a registry read
- WHEN the read is performed
- THEN `LedgerUnavailable` is thrown

#### Scenario: Read offline

- GIVEN a `MockClient` returning a recorded simulation fixture
- WHEN a registry or escrow read is performed
- THEN it completes without any network, database or cache access
