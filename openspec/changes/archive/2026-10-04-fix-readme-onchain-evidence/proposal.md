# Proposal: Fix README On-Chain Evidence and Deploy Escrow to Testnet

## Intent

README on-chain evidence is incomplete and partly stale: it lists 7 demo agents while `contracts/deployments/demo-agents.json` defines 8, the escrow contract (PR #78) is undeployed and undocumented, and contracts docs/layout are outdated. Every on-chain claim must be independently verifiable by contract ID, tx hash, and explorer link.

## Scope

### In Scope
- `scripts/deploy-escrow-testnet.sh`: deploy escrow with documented values only (`fee_bps` 0, `approval_window` 86400 s, `max_expiry` 2592000 s, no treasury); record ID and wasm hash in `testnet.json` `escrow` slot; allow-list the USDC SAC.
- Seed: re-seed `agt-001..008` and bind wallets via `set_agent_wallet` (required: `create_job` needs `provider == registry wallet`).
- Scripted test job `create_job -> fund -> submit -> complete`, recording real tx hashes.
- README evidence table: full 56-char IDs, tx hashes, stellar.expert links; both rails (escrow, direct SAC muxed payment); the 7 earlier agents stated as on-chain orphans.
- `docs/verification/onchain.md`: step-by-step stellar CLI and explorer verification.
- Refresh `contracts/README.md`, `contracts/AGENTS.md`, README repository layout; note escrow persistent TTL and `extend_ttl`.
- `reputation_registry` stays `null`.

### Out of Scope (follow-up changes)
- `fix-server-soroban-rpc-adapter`, `fix-server-agent-catalog-endpoint`, `fix-flutter-onchain-catalog`, `fix-flutter-hire-escrow-flow` (end-to-end app wiring).
- Any change to `contracts/escrow` code or `openspec/changes/agent-escrow-payment`.

## Capabilities

### New Capabilities
- `testnet-escrow-deployment`: escrow deploy script, deployment record, token allow-list, recorded test job.
- `onchain-evidence-docs`: README evidence table and verification guide requirements.

### Modified Capabilities
- None (`openspec/specs/` is empty; `testnet-demo-seed` is archived only). Seed wallet binding is specified under `testnet-escrow-deployment`.

## Approach

Scripts first, then execute on testnet with a funded key held by the user, then write docs from recorded outputs. Docs cite only values present in `testnet.json` or script logs.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `scripts/deploy-escrow-testnet.sh` | New | Escrow deploy, allow-list, test job |
| `scripts/seed-demo-agents.sh` | Modified | `set_agent_wallet` binding |
| `contracts/deployments/testnet.json` | Modified | `escrow` ID + wasm hash |
| `README.md`, `docs/verification/onchain.md` | Modified/New | Evidence and verification |
| `contracts/README.md`, `contracts/AGENTS.md` | Modified | Current layout |

Components: contracts (scripts/deployments) and docs only; domain, server, client, app untouched.

## Review Workload

Estimate ~520 changed lines, over the 400-line budget. Split: PR 1 scripts + deployment record (~240); PR 2 docs (~280), after on-chain execution.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| No funded testnet key in CI/agent | High | User runs scripts; secrets never committed |
| Re-seed duplicates agents | Med | Document orphans honestly; seed idempotent by URI |
| Escrow TTL expiry (~60 days) | Med | Document `extend_ttl` |
| Testnet reset invalidates links | Low | Verification guide allows redeploy and re-record |

## Rollback Plan

Revert both PRs; restore `testnet.json` `escrow` to absent. On-chain state cannot be removed; README reverts to the prior registry-only evidence.

## Dependencies

- Funded testnet key and USDC SAC trustline/balance (user-provided).
- stellar-cli 28.0.0.

## Success Criteria

- [ ] `testnet.json` has escrow ID and wasm hash matching the chain.
- [ ] Test job reaches `Completed` with all four tx hashes in README.
- [ ] Every README ID/hash resolves on stellar.expert; following `onchain.md` reproduces each check.
- [ ] README agent set matches `demo-agents.json` (8) with orphans noted.
