# puls3 Serverpod backend

Serverpod **3.4.13**, pinned on **2026-09-26**. The backend currently exposes a
`health` endpoint so the Flutter app can verify the generated client, server,
and shared workspace are connected, and a read-only `agent` endpoint that serves
the agent catalog from the on-chain identity registry.

## Agent catalog endpoint

`agent.list` returns every agent with valid metadata (`AgentSummary`: `id`,
`registryId`, `name`, `description`, `skills`, `priceUsdcStroops`, optional
`wallet` and `model`). `agent.get(id)` returns the agent with that metadata id,
for example `agt-001`, or `null` when there is none. There is no rating: the
registry does not store one.

The registry has no list function, so the server reads `total_agents` and then
the metadata of ids `0` to `total - 1` through Soroban RPC simulations (four
agents at a time). An agent whose metadata is missing or invalid, such as a
superseded registration, is skipped. The endpoint never signs or submits a
transaction.

The chain is read from the testnet values unless these variables override
them: `PULS3_STELLAR_RPC_URL`, `PULS3_STELLAR_NETWORK_PASSPHRASE`,
`PULS3_STELLAR_USDC_SAC`, `PULS3_STELLAR_IDENTITY_REGISTRY`,
`PULS3_STELLAR_ESCROW` and `PULS3_STELLAR_SIMULATION_SOURCE`. Each RPC call
times out after 8 seconds.

The built list is cached in memory for 60 seconds, and concurrent callers share
one refresh. If a refresh fails because the chain cannot be read, the last list
is served. With no cached list, `list` and `get` throw the serializable
`AgentCatalogUnavailable` exception; an outage is never an empty list, and an
unknown id is never reported as an outage.

## Chain submission tracker

A background loop drives relayed `ChainSubmission` records from `submitted`
to `confirmed` or `failed` (relay step 5 in `docs/architecture/api.md`). Each
pass polls `getTransaction` for up to 100 records, resends the persisted
envelope at most every 30 seconds while the transaction is not found, fails
it as `PreparationExpired` once the chain time passes its time bounds, and
confirms `createJob` and `fund` from their escrow events. The domain effects
on the hire are a no-op until the hire lifecycle lands (#96).

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_TRACKER_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_TRACKER_INTERVAL_SECONDS` | `5` | Seconds between passes; a positive whole number |

It is off by default so tests, CI and existing deployments do not poll the
chain. It uses the same `PULS3_STELLAR_*` variables as the agent catalog, and
writes `[chain-tracker]` lines to stdout (info) and stderr (warnings).

## Prerequisites

- Dart 3.8 or newer
- Flutter 3.32 or newer (to run the app)
- Docker with Docker Compose
- Serverpod CLI 3.4.13: `dart pub global activate serverpod_cli 3.4.13`

## Start the backend

The full path (fresh clone → server and app against testnet) is in
[docs/infra/secrets.md](../docs/infra/secrets.md#run-against-testnet-from-a-fresh-clone).
In short: from the repository root, generate the local Docker passwords
(`puls3_server/.env`) and Serverpod password files (on Windows, run this from
Git Bash):

```bash
./scripts/setup-local-secrets.sh
```

To configure them manually instead, start by copying the tracked templates:

```bash
cd puls3_server
cp .env.example .env
cp config/passwords.example.yaml config/passwords.yaml
```

Replace every empty or `<generate>` value. The development and test
`database`/`redis` values in `config/passwords.yaml` must match the respective
passwords in `.env`.

`puls3_server/.env` only holds these local Docker passwords. The server's
public network config (`PULS3_STELLAR_*`, `PULS3_TRACKER_*`) lives in the root
`.env` (`cp .env.example .env`). Then, from `puls3_server/`, start PostgreSQL
and Redis, load the root config and run the server with pending migrations
applied:

```bash
docker compose up --build --detach
set -a; . ../.env; set +a
dart bin/main.dart --apply-migrations
```

The API listens on `http://localhost:8080` by default. The Flutter app reads
that URL from `puls3_flutter/assets/config.json` and displays
`Backend v1.0.0` when the health call succeeds.

## Tests and analysis

```bash
dart test
dart analyze
cd ../puls3_client && dart analyze
```

The integration tests use Serverpod's generated test tools and the test
PostgreSQL/Redis services started by the Compose command above (ports 9090 and
9091).

## Regenerate Serverpod code

After changing an endpoint or a `*.spy.yaml` model, regenerate the server,
client, and test helpers:

```bash
serverpod generate
git status --short
```

Commit all generated changes. A second generation run must leave the working
tree unchanged.

When you are finished, you can shut down Serverpod with `Ctrl-C`, then stop Postgres and Redis.

```bash
docker compose stop
```
