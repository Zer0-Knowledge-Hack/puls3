# E2E suites hire a custodied agent (#290)

## Objective
Make the local E2E suites pass again on `main` by storing the suite agent's key in server custody, the way a Studio-deployed agent is stored.

## Problem
Since #279 (#276), `createHire` refuses an agent whose payee wallet has no `agent_wallet` row. `LocalSandbox.registerAgent` registers the agent with a Stellar CLI key that the server never stores, so both server E2E suites fail with `AgentCannotDeliver`, and the browser E2E seed has the same gap.

## Scope
- Test support and the local seed only. No production code changes; the #276 check stays.

## Constraints
- No secret committed or logged; the custody cipher key of a run is random and ephemeral.
- Delivery: one PR on `fix/290-e2e-custodied-agent`, strategy `ask-on-risk`. Forecast about 80 authored changed lines.

## Tasks
- [x] **T1** Server E2E world stores the agent key in custody before the first hire.
  - Route: inline (one new test-support file plus a two-line call in `e2e_world.dart`; no research left).
  - Check: `dart test -t e2e --run-skipped -j 1 test/e2e` (RED observed on `1b5d75d`: 2 failing with `AgentCannotDeliver`).
- [ ] **T2** Browser E2E seed stores its agent key in custody in the `puls3_e2e` database.
  - Route: to be decided after T1.
  - Check: `bash scripts/e2e-flutter-local.sh` (needs `chromedriver`).

## Acceptance criteria
- `melos run test:e2e` passes against the local sandbox.
- `bash scripts/e2e-flutter-local.sh` passes.
- `dart analyze --fatal-infos` passes in `puls3_server`.

## Progress
- RED: `1b5d75d`, both server E2E suites fail at `HireEndpoint.createHire` with `AgentCannotDeliver`.
- T1 change (`test/e2e/support/agent_custody.dart`, call in `e2e_world.dart`) moves past the custody check; `fund` then fails simulation with `HostError: Error(Storage, MissingValue)`.
- Second cause (added as **T1b**, reported on #290): `scripts/setup-local-soroban.sh` never deploys the native SAC, so a fresh ledger has no token contract. With the SAC deployed, both suites pass (`+2: All tests passed!`).
- Stale rows in `postgres_test` from older sandboxes made the create_job effect fail with `JobMismatch (job_id)`; resetting the `puls3_server_puls3_test_data` volume cleared it. Not a code defect: the ledger is ephemeral and the test database is not.

## Tasks added
- [x] **T1b** `setup-local-soroban.sh` deploys the native SAC when it is missing.
  - Route: inline (one script block).
  - Check: recreate `soroban_standalone`, run the setup with `--skip-build`, then the server E2E suites.

- T1 + T1b committed in `c5eb3bc`. Checks: `scripts/tests/local-soroban.test.sh` 30/30, `dart analyze --fatal-infos` clean, server E2E `+2` on a reused ledger.
- Fresh ledger (recreated `soroban_standalone`, setup with `--skip-build`): the setup deploys the SAC; the relay suite passes; the feedback suite fails with `InvalidAgentId` because its agent got registry id 0. Third finding: the identity registry numbers agents from 0 (`NextId` starts at `0u32`), and `HireEndpoint.createHire` refuses `agentId < 1`, so agent 0 of any registry can never be hired. Production code, outside #290.

- Agent id 0 moved to its own issue #291, fixed in #293 (`ff152e6`, merged). This branch is rebased on it.
- [x] **T1c** (fourth finding) `setup-local-soroban.sh` called Friendbot once and went on when it failed, so on a fresh ledger the deploy hit `Account not found` for the admin. It now retries until Friendbot answers 200, accepts 400 (already funded), and fails before deploying when it never funds. Route: inline. Checks: `scripts/tests/local-soroban.test.sh` 36/36 (6 new cases, RED observed first).
- Fresh ledger + reset `postgres_test`, after rebase on `ff152e6`: setup exit 0, server E2E `+2: All tests passed!`.

## Next step
Push and open the PR for T1/T1b/T1c (`Refs #290`, T2 still open), then T2 (needs `chromedriver`).
