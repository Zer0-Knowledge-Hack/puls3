# Indexed Agent Catalog Specification

## Purpose

Serve the catalog endpoint from the index, with an on-chain fallback while the
index is empty, so a chain outage does not take the catalog down and the
endpoint never depends on Soroban directly.

## ADDED Requirements

### Requirement: Index-first reads

`list` and `get` MUST read from the index and MUST NOT touch the chain while
the index has rows.

#### Scenario: Index has rows

- GIVEN an indexed agent
- WHEN `list` is called with a failing chain fallback
- THEN the indexed agent is returned and the fallback is not called

### Requirement: Empty-index fallback

While the index is empty, `list` and `get` MUST fall back to the on-chain
catalog so the catalog is not reported as empty just because indexing has not
run.

#### Scenario: Index is empty

- GIVEN an empty index and a working chain fallback
- WHEN `list` is called
- THEN the fallback list is returned

### Requirement: Endpoint depends on the port

`AgentEndpoint` MUST depend only on `CatalogReader`; the Soroban RPC client MUST
be constructed only in the wiring module, never in the endpoint.

#### Scenario: Wire a custom reader

- GIVEN the endpoint's default builder replaced with a fake `CatalogReader`
- WHEN `list` is called
- THEN the fake's list is returned
