# Exploration: fix-readme-onchain-evidence

## Findings

- README "On-chain evidence (testnet)" lists a full 56-char Identity Registry ID (`CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ`) matching `contracts/deployments/testnet.json`. Deploy tx, agent 0, agent 6 and the SAC payment tx all exist and succeeded on testnet. No truncated or broken IDs/links found in README, docs/, contracts/, scripts/.
- The documented payment is a SAC `transfer` to a muxed address (hire id 7) from `spikes/payments-poc/pay.sh`. It is not an escrow call.
- The Agent Escrow & Payment contract (PR #78) is on main as code (`contracts/escrow`) but is NOT deployed or documented: `testnet.json` has only `identity_registry`; `scripts/deploy-testnet.sh` deploys only the registry; README never mentions escrow.
- Drift: README says 7 demo agents (`payments-agent` .. `analytics-agent`); `contracts/deployments/demo-agents.json` lists 8 (`agt-001..008`). Re-running the idempotent-by-URI seed would register 8 new agents.
- Stale docs: `contracts/README.md` (layout shows only `placeholder`), `contracts/AGENTS.md` (hello_world), README "Repository layout" omits contracts/, scripts/, spikes/, puls3_domain/.
- Escrow `create_job` requires `provider == registry wallet of agent_id`; the seed never calls `set_agent_wallet`, so demo agents would be rejected (`agent_without_wallet`).
- App wiring: server has only health/greeting/auth endpoints; Flutter uses a mock JSON catalog and `MockWallet`; domain ports (`AgentRepository`, `LedgerPort`, `AgentRuntimePort`) have no adapters.

## Proposed split (each within the 400-line review budget)

1. `fix-readme-onchain-evidence` — docs: evidence table, `docs/verification/onchain.md`, layout, stale contracts docs.
2. `fix-escrow-testnet-deploy` — deploy script, `escrow` slot in testnet.json, allow-list USDC SAC, scripted test job with recorded tx hashes.
3. `fix-seed-agent-wallets` — bind agent wallets in seed; reconcile 7-vs-8 drift.
4. `fix-server-soroban-rpc-adapter` — `LedgerPort` implementation and contract-ID config.
5. `fix-server-agent-catalog-endpoint` — `agent.list/get` endpoint, regenerate client.
6. `fix-flutter-onchain-catalog` — client-backed repository with asset fallback.
7. `fix-flutter-hire-escrow-flow` — real `WalletPort` adapter and create/fund/submit/complete flow (likely splits in two).

Order: 1 and 3 first, then 2, then 4 → 5 → 6 → 7.

## Risks

- README cannot claim escrow evidence until a deploy and a funded test job exist.
- Seed drift can silently duplicate agents.
- Escrow persistent TTL (~60 days) needs `extend_ttl`.
- On-chain registry state (agent count/URIs) not re-verified against README.
