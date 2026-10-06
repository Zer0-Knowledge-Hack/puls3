# Delta Spec: testnet-escrow-deployment

Change: `fix-readme-onchain-evidence`. New capability; all requirements ADDED. Covers the escrow deploy script, the deployment record, the token allow-list, agent wallet binding in the seed, and the recorded test job. Contract behavior is defined by `agent-escrow-payment` and is NOT changed here.

## Definitions

- **documented values**: `fee_bps = 0`, `approval_window = 86400` seconds, `max_expiry = 2592000` seconds, no treasury. No other values are permitted.
- **deployment record**: `contracts/deployments/testnet.json`.
- **demo agents**: the 8 agents (`agt-001..008`) defined in `contracts/deployments/demo-agents.json`.
- **operator**: the user holding the funded testnet key. Secrets are never committed or logged.
- **test job**: one job driven through `create_job -> fund -> submit -> complete`.

## Requirements

### D1. escrow deploy script
`scripts/deploy-escrow-testnet.sh` MUST deploy the escrow contract to Stellar testnet with the constructor arguments set to the documented values, the identity registry set to the `identity_registry` ID in the deployment record, and no treasury.
- The script MUST NOT hard-code or accept alternative defaults for `fee_bps`, `approval_window` or `max_expiry`.
- The script MUST read the signing key from the operator's environment or stellar-cli key store and MUST NOT write it to any file or log.
- The script MUST fail with a non-zero exit and a clear message if the key, the registry ID, or the wasm artifact is missing.
- The script MUST print each deployed contract ID, wasm hash and transaction hash it produces.

#### Scenario: deploy with documented values
- GIVEN a funded testnet key and a built escrow wasm
- WHEN the operator runs the script
- THEN the escrow is deployed with `fee_bps = 0`, `approval_window = 86400`, `max_expiry = 2592000` and no treasury
- AND the getters `fee_bps()`, `approval_window()`, `max_expiry()` and `treasury()` return those values (treasury `None`)

#### Scenario: missing prerequisite
- WHEN the key, registry ID or wasm artifact is absent
- THEN the script exits non-zero before submitting any transaction

#### Scenario: no secret leakage
- WHEN the script completes or fails
- THEN no secret key appears in stdout, stderr, or any file in the repository

### D2. deployment record
After a successful deploy the script MUST record in `contracts/deployments/testnet.json` an `escrow` slot containing the 56-character contract ID and the wasm hash.
- The recorded values MUST match the chain.
- `reputation_registry` MUST remain `null`.
- Existing slots (`identity_registry` and others) MUST NOT be altered.
- Re-running the script MUST update the `escrow` slot in place and MUST NOT create duplicate slots.

#### Scenario: record written
- WHEN the deploy succeeds
- THEN `testnet.json` `escrow` holds the deployed contract ID and wasm hash

#### Scenario: reputation registry untouched
- THEN `reputation_registry` is still `null` after the run

#### Scenario: redeploy after testnet reset
- WHEN the operator re-runs the script after a testnet reset
- THEN the `escrow` slot is overwritten with the new ID and wasm hash

### D3. token allow-list
After deployment the script MUST call `set_token_allowed(caller, USDC_SAC, true)` as the escrow admin and MUST verify `is_token_allowed(USDC_SAC)` is true.
- The USDC SAC contract ID MUST come from the deployment configuration, not from the contract.
- The script MUST NOT allow-list any other token.

#### Scenario: USDC allowed
- WHEN the script finishes the allow-list step
- THEN `is_token_allowed(USDC_SAC)` returns true

#### Scenario: other tokens stay disallowed
- THEN `is_token_allowed(X)` is false for any token other than USDC

### D4. seed binds agent wallets
`scripts/seed-demo-agents.sh` MUST register all 8 demo agents (`agt-001..008`) and MUST call `set_agent_wallet` for each so that the registry wallet for every agent equals the provider wallet intended for escrow jobs. `create_job` requires `provider == registry wallet`.
- Seeding MUST be idempotent by agent URI: re-running MUST NOT register a duplicate for an already seeded URI.
- Seeding MUST log each agent ID and transaction hash.
- Agents registered by earlier runs (7 agents) remain on-chain and are not removed; the script MUST NOT attempt to delete them.

#### Scenario: eight agents bound
- WHEN the seed runs against the identity registry
- THEN `get_agent_wallet` returns a wallet for each of `agt-001..008`

#### Scenario: idempotent re-run
- WHEN the seed runs a second time
- THEN no new agent is registered for an already seeded URI

#### Scenario: job creation precondition
- GIVEN a bound wallet for an agent
- WHEN `create_job` is called with that wallet as provider
- THEN the provider check against the registry passes

### D5. recorded test job
The deployment flow MUST drive one test job through `create_job -> fund -> submit -> complete` using the USDC SAC, and MUST record the transaction hash of each of the four calls.
- The job MUST finish in state `Completed`.
- The script MUST print the four transaction hashes and the job ID in a form that can be copied into the README.
- Hashes MUST be taken from real execution output; they MUST NOT be fabricated or edited by hand.

#### Scenario: completed job
- GIVEN the escrow is deployed and USDC is allowed
- WHEN the script runs the test job
- THEN the job reaches `Completed` and four distinct transaction hashes are printed

#### Scenario: failure mid-flow
- WHEN any step fails
- THEN the script exits non-zero, reports the failed step and the hashes obtained so far, and does not report success

#### Scenario: hashes resolve
- WHEN a printed hash is looked up on stellar.expert (testnet)
- THEN the transaction exists and invokes the expected escrow function

### D6. persistent storage TTL
The documentation delivered by this change MUST state that escrow persistent entries have a TTL and can be extended with `extend_ttl`. The script MAY provide an optional TTL extension step; it MUST NOT be required for a successful deploy.

#### Scenario: TTL noted
- THEN `contracts/README.md` and `docs/verification/onchain.md` mention the persistent TTL and `extend_ttl`

## Out of scope

- Any change to `contracts/escrow` code or to `openspec/changes/agent-escrow-payment`.
- Server, client, Flutter or domain wiring to the deployed escrow.
- Deploying or populating `reputation_registry`.
- Enabling fees or a treasury.
