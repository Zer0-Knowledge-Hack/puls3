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
- [ ] **T3** Run it on testnet; record hashes in `docs/verification`.

## Checks

- `dart analyze`, unit tests for T1.
- T3: stellar.expert links for create_job, fund, submit, complete.
