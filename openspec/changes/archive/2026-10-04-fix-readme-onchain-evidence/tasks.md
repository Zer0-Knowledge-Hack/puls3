# Tasks: Fix README On-Chain Evidence and Deploy Escrow to Testnet

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~520 (PR1 ~240, PR2 ~280) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 scripts + offline tests + seed wallet check -> PR 2 docs |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Escrow deploy script, seed wallet check, offline tests | PR 1 | `bash scripts/tests/escrow-deploy.test.sh && bash scripts/tests/seed-preflight.test.sh` | Stub `stellar` on PATH; live run is manual (Phase 3) | Revert scripts, tests, `testnet.json` `escrow` slot |
| 2 | Evidence table, verification guide, contracts docs | PR 2 | `rg -n "stellar.expert" README.md docs/verification/onchain.md` | N/A: docs only, values from `testnet.json` | Revert docs files |

Chain base (if feature-branch-chain): PR 1 base = tracker branch; PR 2 base = PR 1 branch.

## Phase 1: Prerequisites (open design items, no invented values)

- [x] 1.1 Operator verifies the deployed registry answers `get_agent_wallet` and `agent_exists` (read-only invoke). If either fails, STOP: registry redeploy decision needed (out of scope).
- [x] 1.2 User chooses `TEST_JOB_EXPIRY_SECONDS` within (86400, 2592000]; no default is coded. (Operator: 604800.)
- [x] 1.3 Confirm test-job provider (default `agt-001`) and that wallet = owner (separate wallet signing unconfirmed). (Operator: provider agt-001, wallet = owner.)

## Phase 2: PR 1 - Scripts (RED then GREEN)

- [x] 2.1 RED: create `scripts/tests/escrow-deploy.test.sh` (stub `stellar`, same harness as `scripts/tests/seed-preflight.test.sh`): missing identity, non-testnet network, missing registry ID, missing wasm exit non-zero before any tx (D1).
- [x] 2.2 RED: idempotent skip, `--redeploy`, merge keeps `identity_registry` and `reputation_registry` null, `escrow` slot updated in place (D2).
- [x] 2.3 RED: allow-list only USDC SAC, skipped when `is_token_allowed` true (D3); registry preflight fails if `get_agent_wallet`/`agent_exists` fail (1.1).
- [x] 2.4 RED: `--test-job` rejects expiry unset or outside (86400, 2592000]; missing tx hash fails; mid-flow failure reports step and hashes so far, exit non-zero (D5); no secret in output (D1).
- [x] 2.5 RED: modify `scripts/tests/seed-preflight.test.sh`: wallet already bound -> no `set_agent_wallet`; missing/different -> bind (D4).
- [x] 2.6 GREEN: create `scripts/deploy-escrow-testnet.sh` (`deploy`, allow-list, merge write with documented constants only).
- [x] 2.7 GREEN: add `--test-job` to the same script (`create_job -> fund -> submit -> complete`, parse 64-hex hashes, record `escrow.test_job`).
- [x] 2.8 GREEN: modify `scripts/seed-demo-agents.sh` with wallet check and `set_agent_wallet` for `agt-001..008`.
- [x] 2.9 Direct rail (proposed owner, confirm with user): add `--direct-payment` to `scripts/deploy-escrow-testnet.sh`, reusing `spikes/payments-poc/pay.sh` (read-only) muxed-payment logic; record hash in `testnet.json` for docs E2. RED test first in 2.1 file.
- [x] 2.10 REFACTOR: run both test files green; shellcheck if available.

## Phase 3: Manual live run (USER STEP, funded key, never commit secrets)

- [x] 3.1 User runs seed, then `deploy`, then `--test-job`, then `--direct-payment` on testnet. (Done by the operator 2026-10-04; `DIRECT_PAYMENT_HIRE_ID=8`.)
- [x] 3.2 Commit resulting `contracts/deployments/testnet.json` in PR 1 (values from real output only); verify `get_job` state `Completed`. (Done by the operator 2026-10-04; job 3 Completed.)

## Phase 4: PR 2 - Docs (after 3.2)

- [x] 4.1 Modify `README.md`: evidence table (full IDs/hashes, stellar.expert links), both rails, 8 agents, 7 orphans, `reputation_registry` not deployed, documented parameters only (E1-E4).
- [x] 4.2 Create `docs/verification/onchain.md`: CLI and explorer steps with expected results, reset caveat, `extend_ttl`, read-only, no secrets (E5).
- [x] 4.3 Modify `contracts/README.md` and `contracts/AGENTS.md`: escrow, deploy and seed scripts, TTL note (E6, D6).
- [x] 4.4 Verify: every path in refreshed docs exists; every README value matches `testnet.json`; English only.
