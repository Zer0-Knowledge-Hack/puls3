# Delta Spec: onchain-evidence-docs

Change: `fix-readme-onchain-evidence`. New capability; all requirements ADDED. Documentation requirements so that every on-chain claim is independently verifiable by contract ID, transaction hash and explorer link. Docs are written AFTER on-chain execution and cite only values present in `contracts/deployments/testnet.json` or in recorded script output.

## Definitions

- **evidence value**: a contract ID, wasm hash, agent ID or transaction hash.
- **explorer link**: a `https://stellar.expert/explorer/testnet/...` URL for the evidence value.
- **orphans**: the 7 agents registered by earlier seed runs that are not part of the current `demo-agents.json`.
- **rails**: escrow (`create_job -> fund -> submit -> complete`) and direct SAC muxed payment.

## Requirements

### E1. README evidence table
`README.md` MUST contain an on-chain evidence table where each row has: what it proves, the full 56-character contract ID or full transaction hash (never truncated), and a stellar.expert link.
- The table MUST cover the identity registry, the escrow contract (ID and wasm hash), and the demo agent registrations.
- Every value MUST equal a value in `testnet.json` or recorded script output.
- The README MUST state that `reputation_registry` is not deployed.

#### Scenario: full identifiers
- WHEN a reader inspects any evidence row
- THEN the ID or hash is complete and the link opens the matching testnet entity

#### Scenario: values traceable
- WHEN each README ID is compared with `testnet.json` or the script log
- THEN every one matches exactly

#### Scenario: reputation registry honesty
- THEN the README does not claim a reputation registry address

### E2. both payment rails
The README MUST document both rails with evidence:
- Escrow rail: the four transaction hashes of the test job (`create_job`, `fund`, `submit`, `complete`) and the final `Completed` state.
- Direct rail: the direct SAC muxed payment transaction hash.
- Each hash MUST have an explorer link.

#### Scenario: four escrow hashes
- THEN the README lists four distinct hashes, one per lifecycle call, each linked

#### Scenario: direct payment evidence
- THEN the README lists the direct SAC muxed payment hash with a link

### E3. agent set matches demo-agents.json
The README agent list MUST match `contracts/deployments/demo-agents.json` and therefore list exactly 8 agents (`agt-001..008`).
- The README MUST state that the 7 earlier agents remain on-chain as orphans, not part of the current set, and MUST NOT present them as current.

#### Scenario: eight agents
- WHEN the README agent list is compared with `demo-agents.json`
- THEN both contain the same 8 agents

#### Scenario: orphans disclosed
- THEN the README states the 7 earlier agents are orphans that cannot be removed from the chain

### E4. documented parameters only
Docs that describe the deployed escrow MUST state the configuration as `fee_bps` 0, `approval_window` 86400 s, `max_expiry` 2592000 s, no treasury, and MUST NOT state any other value as configuration.

#### Scenario: parameters match
- WHEN a doc states escrow configuration
- THEN the values equal the documented values above

### E5. verification guide
`docs/verification/onchain.md` MUST give step-by-step instructions to reproduce each README check using both the stellar CLI and the stellar.expert explorer.
- It MUST cover: confirming the escrow contract ID and wasm hash, reading config getters (`fee_bps`, `approval_window`, `max_expiry`, `treasury`), `is_token_allowed` for USDC, resolving agents via the registry, and inspecting each of the four test job hashes plus the direct payment hash.
- Each step MUST state the expected result.
- It MUST state that after a testnet reset the links become invalid and that the operator can redeploy and re-record.
- It MUST note the escrow persistent TTL and the `extend_ttl` operation.
- It MUST NOT contain secrets or require the reader to hold a funded key for read-only checks.

#### Scenario: reproducible checks
- WHEN a reader follows the guide
- THEN each README ID and hash is confirmed against the chain with the stated expected output

#### Scenario: read-only
- THEN verification steps need no signing key

#### Scenario: reset caveat
- THEN the guide explains what to do when testnet has been reset

### E6. contracts docs refresh
`contracts/README.md`, `contracts/AGENTS.md` and the README repository layout section MUST describe the current layout, including the escrow contract, the deploy script, the seed script, the deployments directory and `docs/verification/onchain.md`.
- Paths mentioned MUST exist in the repository.
- `contracts/README.md` MUST note the escrow persistent TTL and `extend_ttl`.

#### Scenario: layout current
- WHEN each path in the refreshed docs is checked
- THEN it exists in the repository

#### Scenario: escrow documented
- THEN `contracts/README.md` and `contracts/AGENTS.md` mention the escrow contract and its deploy script

### E7. language and wording
All docs delivered by this change MUST be in English and MUST NOT present unverified claims; anything not yet on-chain is labeled as not deployed.

## Out of scope

- End-to-end app wiring (server Soroban adapter, catalog endpoint, Flutter on-chain catalog, hire-escrow flow).
- Changes to contract code or to the `agent-escrow-payment` change.
