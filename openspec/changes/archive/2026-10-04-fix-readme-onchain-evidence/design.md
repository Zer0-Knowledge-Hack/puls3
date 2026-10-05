# Design: Fix README On-Chain Evidence and Deploy Escrow to Testnet

## Technical Approach

Follow the existing script pattern (`scripts/deploy-testnet.sh`, `scripts/seed-demo-agents.sh`): bash with `set -euo pipefail`, a testnet-only guard, Stellar CLI identities (never raw secrets), a python/node JSON runtime, and atomic temp-file writes. A new script deploys escrow, allow-lists the USDC SAC, and runs one recorded test job. The seed gains a wallet check. Docs are written only from values recorded in `contracts/deployments/testnet.json`.

Code finding: `mint` in the current identity registry already sets `AgentWallet(agent_id) = caller`. Newly seeded agents therefore have wallet = owner. The seed must still check and bind explicitly, because the deployed registry WASM (`0cf4ff3f...`) may predate that code, and escrow calls `agent_exists` and `get_agent_wallet` on it.

## Architecture Decisions

| Decision | Choice | Rejected alternative | Rationale |
|---|---|---|---|
| Script shape | New `scripts/deploy-escrow-testnet.sh`, run as `deploy`, then `--test-job` | Extending `deploy-testnet.sh` | Keeps the registry deploy unchanged and testable on its own |
| Constructor values | `admin` = deployer, `identity_registry` read from `testnet.json`, `treasury` = none, `fee_bps` 0, `max_expiry` 2592000, `approval_window` 86400 (as stated in the proposal) | CLI flags with defaults | No invented values; fee 0 with no treasury passes `validate_fee` |
| Idempotency | Skip the deploy when `escrow.contract_id` exists, `version` answers, and `identity_registry` matches. `--redeploy` forces a new deploy. Allow-list only when `is_token_allowed` is false | Always deploy | Re-runs do not create orphan escrows |
| Record write | Read-modify-write merge of the `escrow` slot only | Rewriting the whole file | Keeps `identity_registry`. `deploy-testnet.sh` still rewrites the file, which correctly drops an escrow bound to an old registry |
| USDC SAC | `stellar contract id asset --asset USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5 --network testnet` at run time (issuer documented in `spikes/payments-poc/README.md`) | Hard-coding the C... ID | Derived, so it can be checked |
| Wallet binding | For each seed agent: `get_agent_wallet`. If it is not the target wallet, call `set_agent_wallet`. Target = `AGENT_WALLET_ACCOUNT`, which defaults to the owner identity | Always calling `set_agent_wallet` | Owner == wallet needs one signer (satisfies both `require_auth` calls). A separate wallet needs a second auth entry signature |
| Orphans | Leave the 7 earlier agents (`payments-agent`..`analytics-agent`) untouched and list them in the README as orphans | Burn or update their URIs | On-chain history is permanent. Honest documentation |
| Secrets | Only CLI identity names (`STELLAR_ACCOUNT`, `CLIENT_ACCOUNT`, `AGENT_WALLET_ACCOUNT`) are read. No key material is read, logged, or written | `.env` secret keys | Same as the existing scripts and the payments spike |
| Tx hash capture | Parse the 64-hex hash from the CLI stderr of each invoke. Fail if it is missing | Looking hashes up later on the explorer | Hashes are recorded together with the action that produced them |

## Data Flow

    testnet.json.identity_registry ──> deploy-escrow (deploy, allow-list USDC SAC)
                                           │ merge
                                           v
    seed-demo-agents ──> registry: register agt-001..008, bind wallet
                                           │
    deploy-escrow --test-job: create_job(client, provider=wallet, evaluator=client,
       agent_id, USDC SAC, budget=priceUsdcStroops) -> fund -> submit -> complete
                                           │ tx hashes
                                           v
                    testnet.json.escrow.test_job ──> README table, onchain.md

## File Changes

| File | Action | PR |
|---|---|---|
| `scripts/deploy-escrow-testnet.sh` | Create: deploy, allow-list, `--test-job` | 1 |
| `scripts/seed-demo-agents.sh` | Modify: wallet check and bind after register or skip | 1 |
| `scripts/tests/escrow-deploy.test.sh` | Create: offline tests with a PATH-stub `stellar` | 1 |
| `scripts/tests/seed-preflight.test.sh` | Modify: wallet-binding cases | 1 |
| `contracts/deployments/testnet.json` | Modify: `escrow` slot (after the user runs the scripts) | 1 |
| `README.md` | Modify: evidence table, layout | 2 |
| `docs/verification/onchain.md` | Create: CLI and explorer steps | 2 |
| `contracts/README.md`, `contracts/AGENTS.md` | Modify: current members, `extend_ttl` | 2 |

PR 1 is about 240 lines. PR 2 is about 280 lines and depends on the recorded values from PR 1.

## Interfaces / Contracts

```json
"escrow": {
  "contract_id": "C...", "wasm_hash_sha256": "...", "deploy_tx": "...",
  "deployed_at_utc": "...",
  "constructor": { "admin": "G...", "identity_registry": "C...", "treasury": null,
                   "fee_bps": 0, "max_expiry": 2592000, "approval_window": 86400 },
  "allowed_tokens": [{ "asset": "USDC:GBBD...", "sac_id": "C...", "tx": "..." }],
  "test_job": { "job_id": 0, "agent_id": 0, "budget": "...", "state": "Completed",
                "txs": { "create_job": "...", "fund": "...", "submit": "...", "complete": "..." } }
}
```

`reputation_registry` stays `null`. The `deliverable` and `reason` values are SHA-256 hashes of fixed strings declared in the script. Both the strings and the hashes are recorded so anyone can recompute them.

README evidence table columns: Item | Full 56-char ID or 64-hex hash | stellar.expert link. There are rows for the registry, escrow, the USDC allow-list, the 8 agents, the 4 test-job txs, and the direct SAC muxed payment. Under the table, a note lists the orphans. `onchain.md` has one section per row: a `stellar contract invoke` read (`get_job`, `is_token_allowed`, `get_agent_wallet`) plus the explorer URL. It also covers redeploy after a testnet reset and `extend_ttl(job_id)` before the 60-day TTL ends.

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Script unit | Missing identity, non-testnet network, missing registry ID, idempotent skip, merge keeps `identity_registry`, missing tx hash fails | PATH-stub `stellar`, same harness as `seed-preflight.test.sh` |
| Seed | Wallet already bound means no call. Missing or different wallet means `set_agent_wallet` | Stub returns scripted `get_agent_wallet` output |
| Contract | Unchanged | `cargo test` |
| Live | Test job reaches `Completed` | User runs it on testnet, then reads `get_job` |

## Threat Matrix

| Boundary | Applicability |
|---|---|
| Documentation-like paths | N/A: no executable classification |
| Git repository selection | N/A: scripts run no git |
| Commit state | N/A |
| Push state | N/A |
| PR commands | N/A |

The scripts call the `stellar` CLI. The existing guards apply: testnet-only, identity names only, and `</dev/null` on invokes.

## Migration / Rollout

1. Merge PR 1 code.
2. The user runs the seed, then `deploy`, then `--test-job`.
3. Commit `testnet.json` in PR 1.
4. Write PR 2 from that record.

Rollback: remove the `escrow` slot. On-chain state stays.

## Open Questions

- [ ] Does the deployed registry WASM expose `get_agent_wallet` and `agent_exists`? The script's preflight must invoke both. If they fail, the registry needs a redeploy, which changes every agent ID and is out of scope until decided.
- [ ] Test-job expiry: there is no documented value. The script requires `TEST_JOB_EXPIRY_SECONDS`, validated within `(approval_window, max_expiry]`.
- [ ] Which seeded agent is the test-job provider. Default: `agt-001`, the first seed entry.
- [ ] Does stellar-cli 28.0.0 sign a non-source auth entry for a separate `AGENT_WALLET_ACCOUNT`? Until this is confirmed, wallet = owner.
