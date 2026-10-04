# Agent Rating Display Specification

## Purpose

Agents without an on-chain rating MUST NOT display a misleading score. The rating badge is hidden for unrated agents and the layouts that host it MUST remain valid.

## ADDED Requirements

### Requirement: Rating badge visibility

`RatingBadge` MUST render nothing when `rating <= 0`. When `rating > 0` it MUST show the rating formatted with exactly one decimal place.

#### Scenario: Zero rating hidden

- GIVEN a `RatingBadge` with rating `0.0`
- WHEN it is built
- THEN no rating text or icon is rendered

#### Scenario: Negative rating hidden

- GIVEN a `RatingBadge` with rating `-1.0`
- WHEN it is built
- THEN nothing is rendered

#### Scenario: Positive rating shown

- GIVEN a `RatingBadge` with rating `4.5`
- WHEN it is built
- THEN the text `4.5` is rendered

#### Scenario: One-decimal formatting

- GIVEN a `RatingBadge` with rating `5.0`
- WHEN it is built
- THEN the text `5.0` is rendered

### Requirement: Layouts tolerate a missing badge

The agent card and the agent detail screen MUST build and lay out without errors or overflow when the agent rating is `0.0` and no badge is shown.

#### Scenario: Card with unrated agent

- GIVEN an agent with rating `0.0`
- WHEN the agent card is built
- THEN it renders the name, description and price without exceptions
- AND no rating text is present

#### Scenario: Detail with unrated agent

- GIVEN an agent with rating `0.0`
- WHEN the agent detail screen is built
- THEN it renders without exceptions
- AND no rating text is present

#### Scenario: Rated agent unchanged

- GIVEN an agent with rating `5.0` (for example one published from Studio)
- WHEN the card or detail is built
- THEN the badge shows `5.0` as before
