# Testnet deploy + demo-agent seed (Identity Registry only)

## Why
Issue #15 needs a repeatable testnet deploy of the Identity
Registry (#13) plus seeded demo agents, runnable from a clean
clone with no leaked secrets.

## What (5 deliverables)
1. `scripts/deploy-testnet.sh` — builds (`stellar contract build`)
   and deploys Identity Registry via `stellar contract deploy
   --wasm ... --source-account <identity> --network testnet`,
   then writes `contracts/deployments/testnet.json`.
2. `contracts/deployments/testnet.json` — contract IDs, WASM
   hashes, deployer pubkey, date, `soroban-sdk` version. NEVER seeds.
3. `contracts/deployments/demo-agents.json` — 6–8 demo agents
   (URI + metadata), input to the seed script.
4. `scripts/seed-demo-agents.sh` — registers each demo agent
   (`register_with_uri` / `register_full`); idempotent via
   `agent_id_by_uri` pre-check (+ `total_agents` sanity), skips
   with a message, never duplicates.
5. Docs/config — "Deploy" section in `contracts/README.md` and
   root `.env.example` (identity name + network only, NO seeds).

## Design locks
- Identity/env config via env vars + Stellar CLI identity; fail
  fast with a clear error when identity or network is missing.
- Reputation Registry is NOT deployed here (#14 unmerged).

## Non-goals
Mainnet, upgrade scripts, CI-driven deploys, real agent data.
