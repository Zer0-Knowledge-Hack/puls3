# Registry Metadata Reads Specification

## Purpose

Read-only registry queries for the agent count and per-agent metadata values, plus the Soroban string argument encoding they require. This capability is additive to `soroban-contract-reads` and `soroban-rpc-ledger-adapter`; it does not change their requirements.

## ADDED Requirements

### Requirement: Registry totalAgents

`SorobanLedger.totalAgents()` MUST call the registry `total_agents` function through simulation and return the count as a non-negative integer. A result that is not a non-negative integer MUST be treated as a failed decode and surface as `LedgerUnavailable`.

#### Scenario: Count returned

- GIVEN the registry simulation returns the integer 15
- WHEN `totalAgents` is called
- THEN it returns 15

#### Scenario: Empty registry

- GIVEN the registry simulation returns 0
- WHEN `totalAgents` is called
- THEN it returns 0

#### Scenario: Malformed result

- GIVEN the registry simulation returns a value that is not an integer
- WHEN `totalAgents` is called
- THEN `LedgerUnavailable` is thrown

### Requirement: Registry agentMetadata

`SorobanLedger.agentMetadata(AgentId, key)` MUST call the registry `get_metadata` function through simulation with the agent id and the key as a string argument. It MUST return the stored value as raw bytes (`Uint8List`, the contract's `Option<Bytes>`), or `null` when the contract returns `void` (missing key or unknown agent). Decoding the bytes to text belongs to the catalog service.

#### Scenario: Metadata present

- GIVEN the registry simulation returns the bytes of `Alpha` for agent 7 and key `name`
- WHEN `agentMetadata` is called with that agent and key
- THEN it returns those bytes (UTF-8 `Alpha`)

#### Scenario: Metadata missing

- GIVEN the registry simulation returns `void`
- WHEN `agentMetadata` is called
- THEN it returns `null`

#### Scenario: Key is sent as a string

- GIVEN `agentMetadata` is called with key `skills`
- WHEN the simulation request envelope is built
- THEN the key argument is encoded as an ScVal string, not a symbol

### Requirement: ScArg.string XDR encoding

The envelope encoder MUST provide `ScArg.string`, encoding an ScVal of type `SCV_STRING` (discriminant 14) as a 4-byte big-endian discriminant, a 4-byte big-endian UTF-8 byte length, the UTF-8 bytes, and zero padding to a multiple of 4 bytes. The length MUST be the UTF-8 byte count, not the character count.

#### Scenario: Discriminant and length

- GIVEN the string `name`
- WHEN it is encoded with `ScArg.string`
- THEN the output begins with discriminant 14 followed by length 4 and the bytes of `name`
- AND no padding is added

#### Scenario: Padding

- GIVEN the string `id` (2 bytes)
- WHEN it is encoded with `ScArg.string`
- THEN the output is discriminant 14, length 2, the 2 bytes, and 2 zero padding bytes

#### Scenario: Empty string

- GIVEN the empty string
- WHEN it is encoded with `ScArg.string`
- THEN the output is discriminant 14 followed by length 0 and no data bytes

#### Scenario: Multi-byte characters

- GIVEN a string containing a non-ASCII character
- WHEN it is encoded with `ScArg.string`
- THEN the length equals the UTF-8 byte count
- AND the padding aligns the total to a multiple of 4 bytes

### Requirement: Metadata reads are simulation-only and fail safely

`totalAgents` and `agentMetadata` MUST follow the same constraints as other registry reads: simulation only, `LedgerUnavailable` on HTTP error, JSON-RPC error or `restorePreamble`, and offline testability with `MockClient`.

#### Scenario: RPC failure on metadata read

- GIVEN the RPC answers with HTTP 503
- WHEN `agentMetadata` or `totalAgents` is called
- THEN `LedgerUnavailable` is thrown

#### Scenario: Offline test

- GIVEN a `MockClient` returning a recorded simulation fixture
- WHEN `totalAgents` or `agentMetadata` is called
- THEN it completes without network, PostgreSQL or Redis access
