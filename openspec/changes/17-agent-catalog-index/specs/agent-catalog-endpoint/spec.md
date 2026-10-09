# Agent Catalog Endpoint Specification (delta)

## MODIFIED Requirements

### Requirement: Endpoint list and get

`AgentEndpoint.list(Session)` MUST return the catalog from the `agent_record`
index. `AgentEndpoint.get(Session, String id)` MUST look up the id in the index
and return the matching `AgentSummary`, or `null` for an unknown id. Reads MUST
NOT touch the chain while the index has rows; only an empty index falls back to
the on-chain catalog.

#### Scenario: Unknown id on a populated index

- GIVEN the index has rows and no agent with the id
- WHEN `get` is called with that id
- THEN it returns `null` and does not read the chain

#### Scenario: Empty index falls back

- GIVEN the index is empty
- WHEN `list` or `get` is called
- THEN the on-chain catalog answers

### Requirement: Cache and stale fallback

The on-chain fallback MUST be built once per process, so its 60 s cache, its
shared in-flight refresh and its serve-last-list-on-outage behavior survive
across requests. Rebuilding it per request MUST NOT happen.

#### Scenario: Fallback is reused

- GIVEN the default reader is built twice
- WHEN the fallback is requested
- THEN it is built exactly once
