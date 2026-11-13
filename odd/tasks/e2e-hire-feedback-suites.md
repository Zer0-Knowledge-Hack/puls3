# e2e-hire-feedback-suites
Objective: issue #255 — automate the manual testnet E2E scripts as tagged Dart suites against the local Soroban sandbox (#253).
Branch: feat/255-e2e-hire-feedback-suites · Delivery: ask-on-risk · Runner: `dart test` / `dart test -t e2e` in puls3_server

## Specs
- S1: `puls3_server/dart_test.yaml`: "Configure tag `e2e` and exclude it from the default `dart test` run."
- S2: `puls3_server/test/e2e/hire_relay_e2e_test.dart`: "Automates the full hire lifecycle (F1, F5): `WalletAuthEndpoint` sign-in challenge, `createHire`, `prepareCreateJob`, relay submission, `prepareFund`, and relay submission." Uses "ephemeral in-memory `stellar.KeyPair.random()` accounts funded via local Friendbot." Asserts "idempotent relay submissions and escrow balance state in the local ledger."
- S3: `puls3_server/test/e2e/feedback_e2e_test.dart`: "Automates settlement and rating (F6, F7): agent submission, job completion, `prepareFeedback`, relay submission, and catalog reputation update."
- S4: "Clean teardown and zero secret leakage in test stdout/logs."
- S5: "`dart test` (without flags) skips all E2E tests and runs only unit tests."
- S6: "`dart test -t e2e` passes against the running local Docker sandbox (#253)."
- S7: "All accounts are funded on demand from local Friendbot; no hardcoded keys or public testnet dependencies."
- S8: "Assertions verify both database rows (`Hire`, `ChainSubmission`) and on-chain contract events."
- Out of scope: Flutter web / browser UI automation.
- Assumption A1: the local escrow approval window is 1 day, so F6 "job completion" is the consumer's `complete` (prepareComplete), not a wait for the release deadline.
- Assumption A2: the local registry has no agents, so the suite registers one (register_full + set_agent_wallet) with an ephemeral key.

## Tasks
- T1 (S1,S5) dart_test.yaml e2e tag + default exclusion — inline — done
- T2 (S2,S4,S7) shared support + hire relay suite — inline — done
- T3 (S3,S8) feedback suite — inline — done
- T4 (S6) run against sandbox, README docs — inline — done

## Log
L1 (2026-11-13): "Implementa la #255 con odd y gentle ai"
L2 (2026-11-13): `exclude_tags` in config ORs with CLI `-x` and still applies under `-t e2e` ("include: e2e, exclude: e2e"), so S1+S6 literally cannot both hold. Used tag `skip` + preset `e2e` instead.
L3: Prerequisites found missing for #253: server codecs rejected the standalone passphrase (StellarNetwork.fromPassphrase) -> networkIdOf(); setup script never deployed the native SAC and did not wait for Friendbot.
L4: Verified after Docker recovered: plain `dart test -j 4` = 1259 pass, 2 skipped (the e2e suites), integration included; `dart test -P e2e test/e2e` = 2/2 pass against the rebuilt sandbox.
