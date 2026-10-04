# Agent Catalog Endpoint Specification

## Purpose

A read-only server endpoint that serves the agent catalog from the on-chain identity registry, so the registry stays the single source of truth.

## ADDED Requirements

### Requirement: AgentSummary model

The server MUST define a serializable `AgentSummary` with the fields `id` (metadata id, e.g. `agt-001`), `registryId` (on-chain integer id), `name`, `description`, `skills` (list of kebab-case skill ids), `priceUsdcStroops`, optional `wallet`, and optional `model`. It MUST NOT contain any rating or reputation field.

#### Scenario: Required fields populated

- GIVEN an agent with valid metadata
- WHEN it is mapped to `AgentSummary`
- THEN `id`, `registryId`, `name`, `description`, `skills` and `priceUsdcStroops` are set
- AND `wallet` and `model` are set only when the chain provides them

#### Scenario: No rating

- GIVEN the generated `AgentSummary` protocol class
- WHEN its fields are inspected
- THEN no rating or reputation field exists

### Requirement: Endpoint list and get

`AgentEndpoint.list(Session)` MUST return all valid `AgentSummary` entries. `AgentEndpoint.get(Session, String id)` MUST look up by metadata id in the same list and return the matching `AgentSummary`, or `null` for an unknown id. An unknown id MUST NOT be reported as an error.

#### Scenario: List seeded agents

- GIVEN the registry holds seeded agents `agt-001` to `agt-008` with valid metadata
- WHEN `list` is called
- THEN it returns those 8 agents

#### Scenario: Get existing

- GIVEN `agt-001` is in the catalog
- WHEN `get` is called with `agt-001`
- THEN it returns that `AgentSummary`

#### Scenario: Get unknown

- GIVEN no agent has metadata id `agt-999`
- WHEN `get` is called with `agt-999`
- THEN it returns `null`

### Requirement: Enumeration and orphan skipping

The catalog service MUST enumerate registry ids `0` through `total-1`, where `total` comes from `totalAgents`. An agent whose metadata is missing or invalid MUST be skipped without failing the list. Invalid means any required key (`id`, `name`, `description`, `skills`, `priceUsdcStroops`) is absent or fails the parsing rules below. Skipping MUST NOT be reported as unavailability.

#### Scenario: Orphans are skipped

- GIVEN a registry with 15 agents where ids 0-6 have no metadata and ids 7-14 have valid metadata
- WHEN the catalog is built
- THEN the result contains exactly the 8 agents of ids 7-14

#### Scenario: Invalid metadata skipped

- GIVEN one agent whose `skills` value is not valid JSON
- WHEN the catalog is built
- THEN that agent is omitted
- AND the other agents are still returned

#### Scenario: Empty registry

- GIVEN `totalAgents` returns 0
- WHEN the catalog is built
- THEN the result is an empty list
- AND no error is raised

### Requirement: Skills parsing

The `skills` metadata value MUST be parsed as a JSON array of strings and exposed as `skills` in the same order. A value that is not valid JSON, is not an array, or contains a non-string element makes the agent invalid.

#### Scenario: Valid skills

- GIVEN the `skills` value `["code-review","testing"]`
- WHEN the agent is mapped
- THEN `skills` equals `code-review`, `testing` in that order

#### Scenario: Non-array skills

- GIVEN the `skills` value `{"a":1}`
- WHEN the agent is mapped
- THEN the agent is invalid and skipped

### Requirement: Price parsing

The `priceUsdcStroops` metadata value MUST be parsed as a base-10 integer that is strictly positive and at most 2^53 - 1 (9007199254740991). Zero, negative, non-numeric, fractional or larger values make the agent invalid.

#### Scenario: Valid price

- GIVEN the `priceUsdcStroops` value `25000000`
- WHEN the agent is mapped
- THEN `priceUsdcStroops` equals 25000000

#### Scenario: Upper bound accepted

- GIVEN the value `9007199254740991`
- WHEN the agent is mapped
- THEN the agent is valid

#### Scenario: Above bound rejected

- GIVEN the value `9007199254740992`
- WHEN the agent is mapped
- THEN the agent is invalid and skipped

#### Scenario: Zero, negative or non-numeric rejected

- GIVEN the value `0`, `-5` or `abc`
- WHEN the agent is mapped
- THEN the agent is invalid and skipped

### Requirement: Cache and stale fallback

The service MUST cache the whole built list in memory for 60 seconds. Calls within the TTL MUST NOT query the chain. After expiry the list MUST be rebuilt from the chain. If the rebuild fails with `LedgerUnavailable` and a previously built list exists, the service MUST return that stale list. `get` MUST read from the same cached list.

#### Scenario: Cache hit

- GIVEN a list was built less than 60 seconds ago
- WHEN `list` is called again
- THEN the cached list is returned
- AND no chain read is performed

#### Scenario: Expired cache refreshes

- GIVEN the cached list is older than 60 seconds
- WHEN `list` is called and the chain is available
- THEN the list is rebuilt and the cache replaced

#### Scenario: Stale fallback

- GIVEN a cached list older than 60 seconds
- AND the chain read fails with `LedgerUnavailable`
- WHEN `list` is called
- THEN the stale cached list is returned

### Requirement: Typed AgentCatalogUnavailable

The server MUST define a serializable `AgentCatalogUnavailable` exception model. When the chain is unavailable and no cached list exists, `list` and `get` MUST throw it. An outage MUST NEVER be reported as an empty list.

#### Scenario: Outage without cache

- GIVEN no cached list exists
- AND the chain read fails with `LedgerUnavailable`
- WHEN `list` is called
- THEN `AgentCatalogUnavailable` is thrown
- AND no empty list is returned

#### Scenario: Get during outage without cache

- GIVEN no cached list exists and the chain is unavailable
- WHEN `get` is called with any id
- THEN `AgentCatalogUnavailable` is thrown rather than `null`

### Requirement: Bounded concurrency

The service MUST read per-agent data in parallel with a bounded concurrency of about 4 in-flight agents, never one unbounded request per agent.

#### Scenario: Concurrency cap

- GIVEN a registry with 15 agents and a reader that records concurrent in-flight calls
- WHEN the catalog is built
- THEN the number of agents processed concurrently never exceeds the configured bound (4)
- AND all agents are processed

### Requirement: Lazy default wiring with test override

The endpoint MUST lazily build a default service from `StellarConfig.fromEnvironment`, an `http.Client` and an 8 second RPC timeout, on first use. It MUST expose a `@visibleForTesting` override to inject a service. The catalog service MUST depend only on a narrow `RegistryReader` interface (`totalAgents`, `agentMetadata`, `agentWallet`) implemented by `SorobanLedger`, so it is testable without network, PostgreSQL or Redis.

#### Scenario: Default built on first use

- GIVEN no override is set
- WHEN the endpoint handles its first call
- THEN a default service is created from the environment configuration
- AND it is reused for later calls

#### Scenario: Override used in tests

- GIVEN a test injects a service backed by a fake `RegistryReader`
- WHEN `list` is called
- THEN the fake reader serves the data and no default service is built

#### Scenario: Offline unit tests

- GIVEN no network, database or cache is available
- WHEN the service unit tests run
- THEN they pass using a fake `RegistryReader`

### Requirement: Generated client committed

The output of `serverpod generate` (server `generated/` and `puls3_client` protocol) for `AgentSummary`, `AgentCatalogUnavailable` and the `agent` endpoint MUST be committed, and MUST be byte-identical to what `serverpod_cli` 3.4.13 produces.

#### Scenario: No generated diff

- GIVEN the change is committed
- WHEN CI runs `serverpod generate` with `serverpod_cli` 3.4.13
- THEN `git diff` over `puls3_server` and `puls3_client` is empty

#### Scenario: Client exposes the endpoint

- GIVEN the committed `puls3_client`
- WHEN its protocol is inspected
- THEN it contains the `agent` endpoint with `list` and `get`, and the `AgentSummary` and `AgentCatalogUnavailable` models
