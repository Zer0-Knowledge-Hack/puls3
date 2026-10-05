# Agent instructions

This is a Stellar smart-contract workspace (Soroban). Each contract is a workspace member under `contracts/<name>/`.

## Layout

- `Cargo.toml` — workspace root; contract crates inherit `soroban-sdk` from here
- `contracts/<name>/src/lib.rs` — contract implementation (`#![no_std]`)
- `contracts/<name>/src/test.rs` — host-side unit tests

Current members: `contracts/identity-registry/` (Agent Identity Registry), `contracts/escrow/` (agent escrow and payment) and `contracts/placeholder/` (sample for CI). Deployed IDs and hashes are in `deployments/testnet.json` (never put secrets there); seed data is `deployments/demo-agents.json`.

Scripts (run from the repo root): `scripts/deploy-testnet.sh` (registry), `scripts/deploy-escrow-testnet.sh` (escrow deploy, USDC allow-list, `--test-job`, `--direct-payment`, `--redeploy`) and `scripts/seed-demo-agents.sh`. Offline tests: `scripts/tests/`. Escrow state has a persistent TTL of about 60 days: `extend_ttl(job_id)` renews it. Verification steps: `docs/verification/onchain.md`.

## Build

From the workspace root:

```sh
stellar contract build
```

That compiles every `cdylib` member to WASM. Artifacts land in `target/wasm32v1-none/release/*.wasm`. Build one crate with `stellar contract build --package <name>`.

Do not substitute this with `cargo build --target wasm32v1-none`. `stellar contract build` applies the flags and metadata the network expects.

The `wasm32v1-none` Rust target must be installed (`rustup target add wasm32v1-none`). Rust 1.84 or newer is required for that target. Rust 1.82 and 1.83 cannot build contracts.

## Test

Host tests run with the normal Cargo test harness (not on-chain):

```sh
cargo test
```

A single crate: `cargo test -p <name>`.

## Deploy and invoke

On testnet, after a successful build:

```sh
stellar contract deploy \
  --wasm target/wasm32v1-none/release/<name>.wasm \
  --source-account <identity> \
  --network testnet \
  --alias <alias>

stellar contract invoke \
  --id <alias> \
  --network testnet \
  --source-account <identity> \
  -- hello --to world
```

The sample `hello_world` contract exposes `hello(to: String) -> Vec<String>`. Replace that with your own functions; `stellar contract invoke --id <id> -- -h` prints the generated CLI for the deployed contract.

## Further reading

- https://developers.stellar.org/docs/build/smart-contracts/overview
- https://github.com/stellar/soroban-examples
