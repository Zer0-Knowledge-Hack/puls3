# Delta for Agent Catalog Endpoint

## MODIFIED Requirements

### Requirement: Catalog reputation fields

`list` and `get` MUST populate `rating` and `paidHireCount` on every `AgentSummary`, computed with the #11 reputation function (`puls3_domain` reputation, `docs/domain/reputation.md`). The server MUST NOT reimplement or redefine that formula or its constants. For an agent with no feedback the values MUST be those the #11 function yields for empty input.

A reputation read failure for one agent MUST be isolated: that agent stays listed with the #11 empty-input values and the other agents keep their real values. Those values then mean "no verified feedback", not a score; they MUST NOT be cached as a real read, so the next build retries that agent. A previous cached real read for that agent MAY be served instead. If every agent's read fails and nothing is cached, the existing typed `AgentCatalogUnavailable` or stale fallback applies. Ratings MUST NEVER be invented.
(Previously: any reputation source failure surfaced as a typed error or stale fallback for the whole catalog.)

#### Scenario: Matches the #11 formula

- GIVEN a fake feedback source with a fixed set of scores and paid-hire inputs for agent `agt-001`
- WHEN `list` and `get` return `agt-001`
- THEN `rating` and `paidHireCount` equal what the #11 function returns for the same inputs, called directly in the test

#### Scenario: Agent without feedback

- GIVEN an agent with no feedback and no paid hires
- WHEN it is mapped
- THEN its reputation fields equal the #11 function's empty-input result
- AND the agent is still listed

#### Scenario: One agent unreadable

- GIVEN a registry of agents where the reputation read of one agent fails and the others succeed
- WHEN `list` is called
- THEN all agents are listed
- AND the failed agent has the #11 empty-input values and the others their real values

#### Scenario: Failed read not cached

- GIVEN an agent whose read failed in the previous build
- WHEN the next build runs and the read succeeds
- THEN the agent carries its real values, not the earlier empty-input ones

#### Scenario: Reputation source unavailable for all

- GIVEN the feedback source fails for every agent and no list is cached
- WHEN `list` is called
- THEN `AgentCatalogUnavailable` is thrown, never fabricated ratings

## ADDED Requirements

### Requirement: Reputation is unfiltered and documented

The catalog reputation MUST be computed from all registry feedback, without filtering by clients with completed jobs (ADR-0005 D5 deferred). ADR-0005 D5 and `docs/architecture/api.md` MUST state this and record the risk that any client's score counts. D6 wording MUST read `completed` plus `feedbackReference`, not "Rated".

#### Scenario: Unfiltered score counted

- GIVEN registry feedback from a client with no completed job
- WHEN the catalog is built
- THEN that feedback counts in `rating`

#### Scenario: Docs state the gap

- GIVEN ADR-0005 and `api.md`
- WHEN D5 and D6 are read
- THEN D5 records unfiltered reads and the follow-up, and D6 uses `completed` plus `feedbackReference`
