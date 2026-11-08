# Local Soroban environment

A self-contained Stellar network for developing and testing puls3 without the
public testnet. It runs Postgres and Redis test services plus a
[`stellar/quickstart`](https://github.com/stellar/quickstart) node, then deploys
the three puls3 contracts and writes the server environment file (#253).

> This sandbox is for development only. The local network's master key is
> derived from its public passphrase; never put real funds on it.

## What it starts

| Service | URL / port | Purpose |
|---|---|---|
| `soroban_standalone` | `http://localhost:8000` | core, Horizon, Soroban RPC (`/rpc`) and Friendbot (`/friendbot`) |
| `postgres_test` | `localhost:9090` | integration-test database |
| `redis_test` | `localhost:9091` | integration-test Redis |

The quickstart image is ephemeral: stopping the container discards the ledger.
`docker compose down -v` also discards the test database volumes.

## Prerequisites

- Docker (on WSL, enable the Docker Desktop WSL integration for this distro)
- Stellar CLI 28 or newer (`stellar --version`)
- Rust stable and the `wasm32v1-none` target only when the WASM must be built
  (`rustup target add wasm32v1-none`)
- `curl`

## 1. Start the services

From the repository root:

```bash
./scripts/setup-local-secrets.sh          # once: creates puls3_server/.env and config/passwords.yaml
docker compose -f puls3_server/docker-compose.yaml up -d
docker compose -f puls3_server/docker-compose.yaml ps
```

Wait until `soroban_standalone` reports `healthy`. The first start pulls the
image and takes a minute or two.

## 2. Deploy the contracts

```bash
scripts/setup-local-soroban.sh
```

The script:

1. waits for `getHealth` on `http://localhost:8000/rpc`;
2. adds the `puls3-local` network alias to the Stellar CLI;
3. reuses (or creates) the `puls3-local-admin` CLI identity and funds it from
   the local Friendbot;
4. builds any missing WASM under `contracts/target/wasm32v1-none/release/`;
5. deploys `identity-registry`, `reputation-registry` and `escrow`;
6. allow-lists the native SAC on the escrow; and
7. writes `puls3_server/.env.local-soroban`.

The generated file is git-ignored and contains only public values: RPC URL,
network passphrase, contract ids and the admin address. The Stellar CLI keeps
the identity's key material in its own configuration directory, never in the
repository.

If the WASM is already built, skip the build (also useful offline):

```bash
scripts/setup-local-soroban.sh --skip-build
```

Useful environment variables (defaults in `.env.example`):

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_LOCAL_RPC_URL` | `http://localhost:8000/rpc` | RPC endpoint |
| `PULS3_LOCAL_FRIENDBOT_URL` | `http://localhost:8000/friendbot` | local faucet |
| `PULS3_LOCAL_NETWORK` | `puls3-local` | Stellar CLI network alias |
| `PULS3_LOCAL_IDENTITY` | `puls3-local-admin` | Stellar CLI identity |
| `PULS3_LOCAL_ENV_FILE` | `puls3_server/.env.local-soroban` | output file |
| `PULS3_LOCAL_TIMEOUT_SECONDS` | `120` | RPC wait |
| `PULS3_LOCAL_SKIP_BUILD` | `0` | `1` uses the existing WASM |

## 3. Run the server against it

```bash
docker compose -f puls3_server/docker-compose.yaml up -d postgres
set -a
. puls3_server/.env.local-soroban
set +a
cd puls3_server && dart bin/main.dart --apply-migrations
```

`PULS3_STELLAR_USDC_SAC` points at the **native SAC**. Local mode has no USDC
issuer, so the native Stellar asset stands in for the payment token; it also has
7 decimals, so the same stroop amounts work. The escrow constructor matches the
testnet deployment: zero fee, no treasury, 30-day maximum expiry and a one-day
approval window.

The database still comes from `puls3_server/config/development.yaml`
(`localhost:8090`). Use `docker compose -f puls3_server/docker-compose.yaml up -d postgres`
for that service, or switch the test services if you are running the E2E suite.

## Verify

```bash
# RPC
curl -s -X POST http://localhost:8000/rpc \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Friendbot
curl -s "http://localhost:8000/friendbot?addr=<a G… account>"

# Escrow token allow-list
set -a; . puls3_server/.env.local-soroban; set +a
stellar contract invoke --id "$PULS3_STELLAR_ESCROW" \
  --source-account "$PULS3_LOCAL_IDENTITY" --network "$PULS3_LOCAL_NETWORK" \
  --send=no -- is_token_allowed --token "$PULS3_STELLAR_USDC_SAC"
```

## Re-running and resetting

Re-running `scripts/setup-local-soroban.sh` points the CLI alias at the sandbox
again, deploys a fresh set of contracts and overwrites the env file. The old
contracts stay on the ephemeral ledger until it is reset.

```bash
# Stop everything and discard the ledger and test databases
docker compose -f puls3_server/docker-compose.yaml down -v

# Start a clean sandbox
docker compose -f puls3_server/docker-compose.yaml up -d
scripts/setup-local-soroban.sh
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `docker: command not found` on WSL | Enable the distro in Docker Desktop → Settings → Resources → WSL integration |
| `RPC did not become healthy` | Check `docker compose logs soroban_standalone`; port 8000 may be in use |
| `Friendbot did not fund ...` | Expected on a re-run; the account already exists |
| `wasm is missing and --skip-build was given` | Build once with `(cd contracts && stellar contract build)` |
| Contracts deploy but the app cannot read them | Source `puls3_server/.env.local-soroban` before starting the server |
| Ledger state is confusing after a contract change | `docker compose down -v && up -d`, then deploy again |

The local E2E suites (#255) and the Flutter browser suite (#256) build on this
environment.
