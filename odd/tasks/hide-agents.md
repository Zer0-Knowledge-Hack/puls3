# Feature: hide agents from the catalog (moderation phase 1)

- **Branch:** `feat/hide-agents` (from `origin/main` 21b9252)
- **Locator:** `odd/tasks/hide-agents.md` · Engram `odd/hide-agents/tasks`
- **Delivery strategy:** ask-on-risk · forecast ~250 authored lines (one PR)

## Objective

Let maintainers hide an agent from every puls3 surface without touching the
chain, starting with test agents 15 (`ssda`) and 16 (`rigoberto`).

## Problem / why

The Identity Registry has no delete, and anyone can call `register_full`
on chain, so the indexer lists every registered agent. puls3 has no way to
remove an agent it does not want to show (test leftovers today, offensive
content tomorrow). Filtering must happen on the server, not only in Studio.

## Scope

- `PULS3_HIDDEN_AGENT_IDS`: comma-separated registry ids; blank or unset hides
  nothing; a malformed entry fails loudly at read time without echoing the value
  beyond the bad token.
- Hidden agents are removed from `agent.list` / `agent.get`, refused by
  `createHire` as `AgentUnavailable`, and their `/registry/<hash>` file is 404.
- Funded jobs of a hidden agent are untouched (they settle or refund as usual).

Out of scope: moderation table, admin endpoint, report button, Studio content
check (phases 2 and 3). Editing `.env.example` (blocked for the agent; the user
appends the line).

## Tasks

- [x] **T1** Hidden-agent config + catalog decorator wired in
  `buildAgentCatalogReader`; `createHire` and the registration route refuse
  hidden ids. Unit tests RED → GREEN. Route: delegated (writer trigger: 3+
  non-trivial files).
- [x] **T2** Docs: env table for `PULS3_HIDDEN_AGENT_IDS`; `.env.example` line
  handed to the user. Route: inline.
- [ ] **T3** Deploy to Serverpod Cloud with `PULS3_HIDDEN_AGENT_IDS=15,16`
  after merge (user decision), verify `agent.list` has 8 agents.

## Acceptance criteria

- `agent.list` in production no longer returns ids 15 and 16.
- `agent.get` for them returns null; `createHire` refuses them.
- With the variable unset, behavior is identical to today (tests prove it).

## Checks

- `dart test` for the new and touched unit tests in `puls3_server`.
- `dart analyze` on `puls3_server`.
- `bash scripts/tests/env-inventory.test.sh` (fails until the `.env.example`
  line is added).

## Progress

- 2026-11-17: document created; T1 delegated.
- 2026-11-17: T1 done (delegated writer). RED: new test files failed to load;
  wiring test got `ReputationCatalogReader` instead of `ArgumentError`. GREEN:
  `dart analyze` clean; unit tests +56 passed (writer); parent spot check
  `hidden_catalog_reader_test` + `hire_service_create_test` +31 passed.
  Not covered: `RegistrationRoute` has no Docker-free harness (no test).
  Known limits: hidden check runs after the idempotent repeat in `createHire`
  (a retry of a pre-existing hire still returns it); the shared `agentOf`
  lookup is not filtered so funded jobs keep settling.
- 2026-11-17: T2 done (inline): README "Hidden agents" section; `.env.example`
  line appended by the user. `env-inventory.test.sh`: passed 100, failed 0.
