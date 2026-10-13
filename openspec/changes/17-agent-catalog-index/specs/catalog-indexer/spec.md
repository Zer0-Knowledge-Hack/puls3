# Catalog Indexer Specification

## Purpose

A periodic pass that syncs the catalog index from the identity registry,
resuming from the last processed ledger.

## ADDED Requirements

### Requirement: Bootstrap from state

The first pass (no stored cursor) MUST hydrate every registry id `0` to
`total_agents - 1` from state, because the RPC keeps only about 7 days of
events. It MUST store the node's latest ledger as the cursor.

#### Scenario: First pass indexes every valid agent

- GIVEN a registry with two valid agents and no cursor
- WHEN the indexer runs
- THEN both agents are written to the index
- AND the cursor is the node's latest ledger

### Requirement: Incremental sync

A pass with a stored cursor MUST read the registry events after the cursor,
collect the affected agent ids, and hydrate those agents from state. It MUST
advance the cursor to the node's latest ledger.

#### Scenario: Only changed agents are re-read

- GIVEN a cursor and one `registered` event for agent 1
- WHEN the indexer runs
- THEN agent 1 is hydrated
- AND the events are read starting at cursor + 1

### Requirement: Missing agents are recovered

A pass MUST hydrate any registry id present on chain but absent from the index,
even without an event, so a registration is never lost.

#### Scenario: Recovery after a missed event

- GIVEN a chain with an agent that is not in the index and no event for it
- WHEN the indexer runs
- THEN the agent is hydrated

#### Scenario: Running twice is stable

- GIVEN a pass that indexed every agent
- WHEN the same pass runs again
- THEN no agent is hydrated and no row is duplicated

### Requirement: Outage handling

A failure to read the latest ledger or the agent count MUST abort the pass with
a `LedgerException`, leaving the index and cursor unchanged, so the loop
retries later.

#### Scenario: Chain down

- GIVEN a chain read that fails
- WHEN the indexer runs
- THEN the pass throws and no rows are written

### Requirement: Retention gap

When the cursor is outside the node's retention window (the node rejects the
range), the indexer MUST reset the cursor to the latest ledger and still
recover missing agents from state.

#### Scenario: Cursor older than retention

- GIVEN a cursor and a rejected event range
- WHEN the indexer runs
- THEN the cursor advances to the latest ledger
- AND agents missing from the index are hydrated
