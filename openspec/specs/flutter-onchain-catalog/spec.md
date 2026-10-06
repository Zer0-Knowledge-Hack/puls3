# Flutter On-chain Catalog Specification

## Purpose

The Flutter market MUST list agents served by the server catalog (`client.agent.list()`), mapped to the app `Agent` model, and MUST keep the bundled asset catalog as an offline fallback.

## ADDED Requirements

### Requirement: Server-backed agent repository

`ServerAgentRepository` MUST implement `AgentRepository` and obtain agent summaries from an injectable source function (a zero-argument async function returning a list of `AgentSummary`). It MUST NOT depend directly on the generated client.

#### Scenario: Source function is used

- GIVEN a `ServerAgentRepository` constructed with a fake source function returning two summaries
- WHEN `fetchAgents()` is called
- THEN the source function is invoked exactly once
- AND the result contains the two mapped agents in source order

#### Scenario: Source error propagates

- GIVEN a source function that throws an error
- WHEN `fetchAgents()` is called
- THEN the same error is thrown to the caller (no swallowing)

### Requirement: AgentSummary to Agent mapping

The repository MUST map each `AgentSummary` to an `Agent` as follows: `id`, `name`, `description` and price (`priceUsdcStroops`) copied unchanged; `skills` = each skill id converted by `skillDisplayName`, order preserved; `model` = the summary model, or `Unspecified` when null or empty; `stellarAddress` = the summary `wallet`; `rating` = `0.0`.

#### Scenario: Full summary is mapped

- GIVEN a summary with id `a1`, name `Atlas`, description `Reads chains`, price 5000000, skills `[on-chain-analytics, monitoring]`, wallet `GABC`, model `gpt-x`
- WHEN it is mapped
- THEN the agent has id `a1`, name `Atlas`, description `Reads chains`, price 5000000
- AND skills are `[On-chain analytics, Monitoring]`
- AND model is `gpt-x`, stellarAddress is `GABC`, rating is `0.0`

#### Scenario: Missing model defaults

- GIVEN a summary whose model is null
- WHEN it is mapped
- THEN the agent model is `Unspecified`

### Requirement: Agents without a wallet are dropped

The mapper MUST exclude any summary whose wallet is null or empty. It MUST NOT substitute an empty string or any placeholder address, because an agent that cannot be paid cannot be hired.

#### Scenario: Null wallet dropped

- GIVEN a source returning one summary with a wallet and one with a null wallet
- WHEN `fetchAgents()` is called
- THEN only the agent with a wallet is returned

#### Scenario: Empty wallet dropped

- GIVEN a summary whose wallet is an empty string
- WHEN `fetchAgents()` is called
- THEN that agent is absent from the result

#### Scenario: All agents lack wallets

- GIVEN a source returning only summaries without wallets
- WHEN `fetchAgents()` is called
- THEN the result is an empty list and no error is thrown

### Requirement: Skill display names

A pure function `skillDisplayName(String id)` MUST return the display name from a const table for these 17 known ids:

| id | display name |
|----|--------------|
| on-chain-analytics | On-chain analytics |
| monitoring | Monitoring |
| summaries | Summaries |
| payments | Payments |
| anchors | Anchors |
| compliance | Compliance |
| smart-contracts | Smart contracts |
| security | Security |
| rust | Rust |
| document-parsing | Document parsing |
| accounting | Accounting |
| trading | Trading |
| copywriting | Copywriting |
| marketing | Marketing |
| customer-support | Customer support |
| triage | Triage |
| data-cleaning | Data cleaning |

For an unknown id it MUST replace hyphens with spaces and uppercase only the first letter, leaving the rest unchanged.

#### Scenario: Known ids use the table

- GIVEN each of the 17 known ids
- WHEN `skillDisplayName` is called
- THEN it returns the display name listed in the table

#### Scenario: Unknown id fallback

- GIVEN the unknown id `yield-farming`
- WHEN `skillDisplayName` is called
- THEN it returns `Yield farming`

#### Scenario: Unknown single-word id

- GIVEN the unknown id `quant`
- WHEN `skillDisplayName` is called
- THEN it returns `Quant`

#### Scenario: Empty id

- GIVEN an empty id
- WHEN `skillDisplayName` is called
- THEN it returns an empty string without throwing

### Requirement: Fallback repository

`FallbackAgentRepository(primary, fallback)` MUST implement `AgentRepository`. It MUST return the primary result when the primary succeeds, including an empty list, and MUST NOT call the fallback in that case. When the primary throws any error or exception, it MUST return the fallback result.

#### Scenario: Primary succeeds

- GIVEN a primary returning two agents and a fallback returning three
- WHEN `fetchAgents()` is called
- THEN the two primary agents are returned
- AND the fallback is never called

#### Scenario: Primary throws

- GIVEN a primary that throws (any error type, including a catalog-unavailable error)
- WHEN `fetchAgents()` is called
- THEN the fallback result is returned

#### Scenario: Primary returns empty list

- GIVEN a primary that succeeds with an empty list
- WHEN `fetchAgents()` is called
- THEN an empty list is returned
- AND the fallback is never called

#### Scenario: Primary timeout

- GIVEN a primary that fails with a timeout error
- WHEN `fetchAgents()` is called
- THEN the fallback result is returned

### Requirement: Bounded call timeout

The server call MUST be bounded by a finite timeout so that a hanging server does not block the market. When the timeout elapses the call MUST fail with a thrown error (so the fallback repository takes over). The mechanism MAY be a client option or `Future.timeout`.

#### Scenario: Hanging source

- GIVEN a source function that never completes
- WHEN `fetchAgents()` is called and the timeout elapses
- THEN a timeout error is thrown by the server repository

#### Scenario: Fast source unaffected

- GIVEN a source function that completes before the timeout
- WHEN `fetchAgents()` is called
- THEN the mapped agents are returned normally

### Requirement: App composition

`main.dart` MUST compose `FallbackAgentRepository` with `ServerAgentRepository` (source `() => client.agent.list()`) as primary and `AssetAgentRepository` as fallback, and pass it to the app as its repository. `AgentCatalog` and screens MUST NOT require changes to consume it.

#### Scenario: Server reachable

- GIVEN the server returns registry agents with wallets
- WHEN the market loads
- THEN the market lists those agents with readable skill names

#### Scenario: Server failing

- GIVEN the server call throws or times out
- WHEN the market loads
- THEN the bundled asset catalog is shown

#### Scenario: Server returns an empty list

- GIVEN the server call succeeds with no agents
- WHEN the market loads
- THEN the market is empty and the asset catalog is not shown
