# Delta for Agent Catalog Endpoint

## MODIFIED Requirements

### Requirement: AgentSummary model

The server MUST define a serializable `AgentSummary` with the fields `id` (metadata id, e.g. `agt-001`), `registryId` (on-chain integer id), `name`, `description`, `skills` (list of kebab-case skill ids), `priceUsdcStroops`, optional `wallet`, optional `model`, `rating` and `paidHireCount`. `rating` and `paidHireCount` are defined by the "Catalog reputation fields" requirement.
(Previously: no rating or reputation field was allowed.)

#### Scenario: Required fields populated

- GIVEN an agent with valid metadata
- WHEN it is mapped to `AgentSummary`
- THEN `id`, `registryId`, `name`, `description`, `skills` and `priceUsdcStroops` are set
- AND `wallet` and `model` are set only when the chain provides them

#### Scenario: Reputation fields present

- GIVEN the generated `AgentSummary` protocol class
- WHEN its fields are inspected
- THEN `rating` and `paidHireCount` exist
- AND the committed `puls3_client` matches the generated output

## ADDED Requirements

### Requirement: Catalog reputation fields

`list` and `get` MUST populate `rating` and `paidHireCount` on every `AgentSummary`, computed with the #11 reputation function (`puls3_domain` reputation, `docs/domain/reputation.md`). The server MUST NOT reimplement or redefine that formula or its constants. For an agent with no feedback the values MUST be those the #11 function yields for empty input.

#### Scenario: Matches the #11 formula

- GIVEN a fake feedback source with a fixed set of scores and paid-hire inputs for agent `agt-001`
- WHEN `list` and `get` return `agt-001`
- THEN `rating` and `paidHireCount` equal what the #11 function returns for the same inputs, called directly in the test

#### Scenario: Agent without feedback

- GIVEN an agent with no feedback and no paid hires
- WHEN it is mapped
- THEN its reputation fields equal the #11 function's empty-input result
- AND the agent is still listed

#### Scenario: Reputation source unavailable

- GIVEN the feedback source fails
- WHEN `list` is called
- THEN the failure surfaces as a typed error or the existing stale fallback, never as fabricated ratings
