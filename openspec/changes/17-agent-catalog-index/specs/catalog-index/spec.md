# Catalog Index Specification

## Purpose

A durable Postgres index of the agent catalog, synced from the on-chain
identity registry, so the endpoint does not read the chain on every request.

## ADDED Requirements

### Requirement: AgentRecord model

The server MUST define a server-only `AgentRecord` table with `registryId`
(unique), `agentId`, `name`, `description`, `skills`, `priceUsdcStroops`,
optional `wallet` and optional `model`. Rows MUST be complete: the indexer
stores an agent only when its required metadata is valid.

#### Scenario: A complete agent is stored

- GIVEN an agent with valid metadata
- WHEN the indexer stores it
- THEN one `AgentRecord` row exists for its registry id

#### Scenario: An incomplete agent is not stored

- GIVEN an agent whose `skills` metadata is not valid JSON
- WHEN the indexer considers it
- THEN no `AgentRecord` row is written for it

### Requirement: Resume cursor

The server MUST define a server-only `CatalogIndexState` table with `network`
(unique), `lastProcessedLedger` and `updatedAt`, one row per network.

#### Scenario: Cursor round-trips

- GIVEN no cursor for a network
- WHEN `lastProcessedLedger` is read
- THEN it is `null`
- WHEN a ledger is stored
- THEN reading it returns that ledger

### Requirement: Idempotent upsert

`upsertAll` MUST insert or replace agents by `registryId`, so running it twice
with the same agents leaves the index unchanged.

#### Scenario: Running twice does not duplicate

- GIVEN an agent written once
- WHEN the same agent is written again
- THEN exactly one row exists for its registry id

### Requirement: Newest registration per metadata id

`list` MUST return one agent per metadata id, the one with the highest
registry id, ordered by registry id.

#### Scenario: Superseded registration is hidden

- GIVEN two rows with the same `agentId` and registry ids 0 and 2
- WHEN `list` is called
- THEN only the registry id 2 row is returned
