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
- [x] **T2** Browser E2E seed stores its agent key in custody in the `puls3_e2e` database.
  - Route: delegated (one writer: seed, run script, README).
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

- T2 RED: the seeded agent's page shows "This agent cannot be hired yet." (no `agent_wallet` row in `puls3_e2e`).
- T2 change: `tool/e2e_seed_local.dart` starts a Serverpod (development mode, `--apply-migrations`), calls `custodyAgentKey`, and shuts it down; `scripts/e2e-flutter-local.sh` shares one `e2e_database_env` function between the seed and the server. Checks: `dart analyze --fatal-infos` clean, `dart format` unchanged, `scripts/tests/local-soroban.test.sh` 36/36.
- `bash scripts/e2e-flutter-local.sh` (Windows): the custody check passes (the seed applies migrations, stores the row, "Seeded agent 3"; the hire form opens), then the hire fails with "Your wallet session ended": `walletAuth.createChallenge` throws `AuthenticationUnavailable` (`wallet_auth_config.dart:68`). Fifth finding, not caused by T2: on Windows, Dart's `Platform.environment` upper-cases variable names (`SERVERPOD_PASSWORD_walletAuthSigningKey` arrives as `SERVERPOD_PASSWORD_WALLETAUTHSIGNINGKEY`), and Serverpod's `PasswordManager` keeps the suffix as the password name, so `getPassword('walletAuthSigningKey')` is null. The run script cannot fix it; it needs a case-safe way to pass the key (for example a custom password mapping in `lib/server.dart`, or a run-scoped `config/passwords.yaml`), which is outside T2's surface. T2 stays open. Server E2E after the T2 change: `+2: All tests passed!`.

- [x] **T2b** Docker runner for the browser E2E, so it runs on Linux (the fifth finding) and can later be reused in CI.
  - Route: delegated (one writer: `docker/e2e-browser/` image and entry point, `scripts/e2e-flutter-docker.sh`, optional DB/repo-root overrides in `scripts/e2e-flutter-local.sh` with the native defaults unchanged, README).
  - Checks: `docker build` of the image; `bash scripts/e2e-flutter-docker.sh --help`; `bash scripts/e2e-flutter-docker.sh` (full journey); host `dart analyze --fatal-infos` in `puls3_server`; host `.dart_tool/` untouched; `git status` shows only the intended files.

- T2b change: `docker/e2e-browser/Dockerfile` (Debian bookworm-slim by digest; Flutter 3.44.4 / Dart 3.12.2, Stellar CLI 28.1.0, Chrome for Testing + chromedriver 157.0.8103.78, every download SHA-256 checked) and `entrypoint.sh` (defines the CLI network alias from the sandbox env, runs a `\r`-stripped copy of the run script); `scripts/e2e-flutter-docker.sh` joins the sandbox container's compose network (`puls3_server_default`), mounts a copy of `.env.local-soroban` with `soroban_standalone:8000` URLs, passes only `POSTGRES_TEST_PASSWORD` through the environment, keeps every `.dart_tool/`, `build/`, Flutter `ephemeral/` and the pub cache in `puls3-e2e-browser-*` named volumes, restores the host's `.flutter-plugins-dependencies`, and tags the image by the hash of its sources (reused when unchanged). `scripts/e2e-flutter-local.sh` gained `PULS3_E2E_DB_HOST`/`_PORT`/`_CLIENT` and `PULS3_REPO_ROOT`, defaulting to the native values.
- T2b checks: `docker build` succeeded (5.88 GB unpacked, 2.13 GB content); `--help` prints usage; `bash scripts/e2e-flutter-docker.sh`: "Seeded agent 7", web compile 141 s, `All tests passed.`, exit 0 (the first full run also passed; its exit 127 came from the script being edited while it ran). The E2E report trace shows one `prepareFund` answered `InvalidHireTransition` before the job confirmed; the journey still completed (observation, not a failure). Host after the runs: `.dart_tool/`, `build/`, `ephemeral/`, `package_config.json`, `.flutter-plugins-dependencies` and `pubspec.lock` mtimes unchanged; `dart analyze --fatal-infos` `No issues found!`; `scripts/tests/local-soroban.test.sh` 36/36.

## Next step
Parent verifies and commits T2b; then the PR (`Refs #290`) can close #290. Later: reuse the image in CI.
