# Feature: an agent hires and pays another agent autonomously (#312)

- **Branch:** `feat/312-agent-hires-agent` (from `origin/main`)
- **Locator:** `odd/tasks/agent-hires-agent.md` · Engram `odd/agent-hires-agent/tasks`
- **Deadline:** working testnet evidence before 08:00 Bolivia 2026-11-17 (BAF meeting 10:45)

## Objective

SOW week 2: an agent makes an autonomous payment to another agent on testnet,
verifiable by tx hash, with no human signature in the loop.

## Approach

Agent A (custodied wallet) acts as the hire client of agent B through the
existing escrow: A's custodied key signs `create_job`, `fund` and, as
evaluator, `complete`; B's custodied key signs `submit` (#208). Spending is
bounded by a per-run budget. Fallback if escrow path is not green by 06:00:
direct USDC transfer from A's custodied wallet to B's.

## Tasks

- [x] **T1** Server service: a custodied agent hires another agent (sign as
  client and evaluator with its custodied key), with a budget cap. Unit tests.
  Route: delegated writer. `lib/src/hire/agent_hire_service.dart`
  (`AgentHireService`, `HireServicesEscrow`, `custodiedEnvelopeSigner`);
  `test/unit/hire/agent_hire_service_test.dart` RED (missing library) then
  GREEN 6/6. Budget checked on catalog price and on stored hire price.
- [x] **T2** Testnet demo tool printing every tx hash (A and B custodied in the
  local DB, real testnet). Route: same writer. `tool/a2a_hire_testnet.dart`
  (`--mode test`, throwaway custody key, Friendbot + DEX XLM->USDC signed by
  A, `register_full` signed by each agent, B's work is deterministic, B's
  `submit` via `AgentSubmitSender`; `--direct` fallback). Ran 2026-11-17
  06:50 UTC: A = agent 28 `GDUMY7…AIMW`, B = agent 29 `GBJ2UD…GNMT`, hire 5,
  job 30, status completed, B received 0.1 USDC.
  - create_job (A) `3aba5baeeaeb4a9427ad848e3465114c707eb06681370fa588ea8f94fedeb7d3`
  - fund (A) `a6dac2d00c742f932bda3a9e0aa5399e7833d165e636687d48efadcb058db2e0`
  - submit (B) `d6abe4be0410016fa9406f80be26dbe7323c3eb6e8b979a5b276bf4c825561e5`
  - complete (A) `6903874f8155515b23d0ac6f49a42aee68a585c98b08f77f27ef4811660db18b`
  - `--direct` transfer A->B `748ecbf1cd9836c7b5c8e6765f926977c401c754538c0413f6a71d2cedac2df7`
- [x] **T3** Run it on testnet; record hashes in `docs/verification`.
  Route: inline. Re-ran 2026-11-18 from `main` `64a6793`: hire 6 / job 36, all four escrow txs
  `SUCCESS` (ledgers 5799908–5799911); over-budget run refused with `AgentHireOverBudget` before
  any escrow tx. Recorded in `docs/verification/312-agent-hires-agent.md`, PR #356 (part 1).
  **Scope correction (accepted by the user):** A and B were bare custodied wallets and B's work
  was deterministic, so T3 proves the payment rail only, not working agents. #356 changed from
  `Closes` to `Refs #312`.

## Part 2: real Studio agents (reopened scope, 2026-11-18)

Both agents are deployed Studio agents with manifests. B's output comes from a real model
(Workers AI `@cf/meta/llama-3.3-70b-instruct-fp8-fast`) through the hire runtime, and A's owner
starts the hire with `StudioEndpoint.hireAgentAs`. Agent autonomy (a model deciding to hire)
is #334 and out of scope. Branch: `docs/312-agent-hires-agent-evidence` (same PR #356).

- [x] **T4** (done: delegated writer; `dart analyze` clean, re-checked by parent) Tool `puls3_server/tool/a2a_studio_hire_testnet.dart`. It deploys A and B through
  the Studio endpoints with a throwaway builder, saves the builder's Workers AI credential, gives
  A USDC, starts the runtime and the tracker, runs `hireAgentAs`, and prints every hash plus B's
  model output. Route: delegated writer (one new non-trivial file needing preparation reads).
  The exploration map is in the writer's prompt.
- [x] **T5** (done 2026-11-18: hire 7 / job 37 `completed`, A = registry 37, B = registry 38,
  B's Workers AI output stored; 8 txs `SUCCESS` on RPC, ledgers 5800286–5800299; B USDC 0 → 0.1)
  Run T4 on testnet. Secrets: `test.workersAiApiToken` in `config/passwords.yaml`, and
  `PULS3_WORKERS_AI_ACCOUNT_ID` plus `PULS3_AGENT_WALLET_SECRET_KEY` exported in the environment.
- [x] **T6** (record updated; whether #356 says `Closes #312` is the user's call) Add run 3 to `docs/verification/312-agent-hires-agent.md` and lift the scope note
  only for what the run proves. Then decide whether #356 can say `Closes #312`.

## Checks

- `dart analyze`, unit tests for T1.
- T3: stellar.expert links for create_job, fund, submit, complete.
