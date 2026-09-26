# Tasks — testnet-deploy (#15, planning only)

## Deploy script
- [x] `scripts/deploy-testnet.sh` uses `set -euo pipefail`, resolves repo root from its own path, and fails fast with a clear error when identity (`STELLAR_ACCOUNT`/positional) or network config is missing
- [x] Deploy script builds from `contracts/` with `stellar contract build --package identity-registry` and deploys with `stellar contract deploy --wasm <identity-registry.wasm> --source-account <identity> --network testnet` plus `__constructor` args
- [x] Deploy script writes `contracts/deployments/testnet.json` on success and prints the explorer URL for the deployed contract ID

## Deployment record
- [x] `contracts/deployments/testnet.json` contains contract ID, WASM hash, deployer pubkey, deploy date (UTC), and `soroban-sdk` version, and contains no `S…` secret seed

## Seed data + script
- [x] `contracts/deployments/demo-agents.json` defines 6–8 demo agents, each with a unique URI and metadata entries within registry limits
- [x] `scripts/seed-demo-agents.sh` uses `set -euo pipefail`, reads contract ID from `testnet.json`, and fails fast with a clear error when identity, network, or files are missing
- [x] Seed script is idempotent: before each register it invokes `agent_id_by_uri`, skips already-registered URIs with a message, fails clearly (no silent duplicates) on `UriAlreadyRegistered`, and reports `total_agents` before/after

## Docs + hygiene
- [x] `contracts/README.md` gains a "Deploy" section: prerequisites, deploy command, seed command, re-seed behavior, explorer link pattern
- [x] Root `.env.example` documents identity/network vars only (keys from Stellar CLI identity or env vars) and contains no secret seed
- [ ] Secret scan passes: `git grep -nE "S[A-Z2-7]{55}"` returns empty; seed-twice run produces no duplicates
