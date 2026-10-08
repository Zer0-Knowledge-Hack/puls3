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
confirms `createJob` and `fund` from their escrow events. After a successful
`fund` the hire effect (`HireEscrowEffects`) reads the job from the escrow and
pays the hire only if the job matches it (state `Funded`; client and
evaluator are the consumer; provider, token, budget and `expired_at` as
prepared); otherwise the submission fails as `JobMismatch` with the mismatching
field. Recording the job id after `createJob` is a no-op until the hire
lifecycle lands (#96).

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_TRACKER_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_TRACKER_INTERVAL_SECONDS` | `5` | Seconds between passes; a positive whole number |

It is off by default so tests, CI and existing deployments do not poll the
chain. It uses the same `PULS3_STELLAR_*` variables as the agent catalog, and
writes `[chain-tracker]` lines to stdout (info) and stderr (warnings).

### Hire configuration

| Variable | Default | Meaning |
|---|---|---|
| `PULS3_HIRE_JOB_DURATION_SECONDS` | none (required) | How long a new hire's escrow job stays valid: `HireService.createHire` sets the job's `expired_at` to now plus this many seconds, and `fund` is only accepted for a job with that same `expired_at`. A positive whole number; without it `createHire` fails with `HireConfigurationMissing`. The value is deferred (ADR-0005 D3), so no default is set. |
| `PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS` | none (required) | How long an unsigned escrow envelope stays valid: its `maxTime` is now plus this many seconds, and `submitEscrowCall` answers `PreparationExpired` after it. A positive whole number. |
| `PULS3_STELLAR_INCLUSION_FEE_STROOPS` | none (required) | The inclusion fee, in stroops, of every prepared envelope; the simulated resource fee is added on top. A positive whole number. |
| `PULS3_PLATFORM_FEE_BPS` | none (required) | The `max_fee_bps` argument of `fund`, in basis points from 0 to 1000 (the contract's `MAX_FEE_BPS`). It must equal `NetworkConfig.platformFeeBps`. `0` is a valid value. |

The three relay keys have no default, fallback or placeholder. They are read
when an operation needs them, so a missing, empty, non-integer or out-of-range
value makes that call fail with `HireConfigurationMissing` naming the key
(`createHire` and the `prepare*` methods read the keys they need;
`submitEscrowCall` reads none) and never stops the server or affects the other endpoints.

### Hire endpoint sessions

`HireEndpoint` (`createHire`, `prepareCreateJob`, `prepareFund`,
`prepareComplete`, `prepareReject`, `submitEscrowCall`) resolves the caller
through the `SessionWallet` seam before doing any work. Until wallet sessions
exist (#25) the production binding, `FailClosedSessionWallet`, fails closed:
every call is rejected with `AuthenticationUnavailable`, so the hire methods
are not usable against a running server yet. Tests inject a fake with
`HireEndpoint.sessionWallet`. `InputTooLong` has no documented limit, so the
hire `input` length is not checked.

### End-to-end proof on testnet

`tool/e2e_relay_testnet.dart` creates and funds a hire on **testnet** using
only `createHire`, `prepareFund` and `submitEscrowCall`, signing the unsigned
XDR unchanged with a consumer key. It composes the real `HireEndpoint`, wiring,
codec, Soroban RPC client and chain tracker over the test PostgreSQL (test
mode, migrations applied), checks that a second submit of one preparation
returns the existing record, and that an envelope with altered time bounds
(a copy, never broadcast) is rejected with `EnvelopeMismatch`. It prints the
hire and job ids, both transaction hashes with Stellar Expert links and the
final status, and exits non-zero on any failed step.

The secret is read from `PULS3_E2E_CONSUMER_SECRET` and is never printed or
stored; feed it from the Stellar CLI in the same command. The relay values
below are for this run only (they are not defaults of the server); the chain
ids default to testnet and can be overridden with the `PULS3_STELLAR_*` keys.
The consumer needs XLM and testnet USDC of the allowed token, and the registry
needs an agent with a wallet (`PULS3_E2E_AGENT_ID` picks one; the cheapest
otherwise).

```bash
docker start puls3_server-postgres_test-1 puls3_server-redis_test-1
cd puls3_server
PULS3_E2E_CONSUMER_SECRET="$(stellar keys secret alice)" \
PULS3_E2E_CONSUMER_ADDRESS="$(stellar keys address alice)" \
PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS=600 \
PULS3_STELLAR_INCLUSION_FEE_STROOPS=100000 \
PULS3_PLATFORM_FEE_BPS=0 \
PULS3_HIRE_JOB_DURATION_SECONDS=86400 \
dart run tool/e2e_relay_testnet.dart
```

## Prerequisites

- Dart 3.8 or newer
- Flutter 3.32 or newer (to run the app)
- Docker with Docker Compose
- Serverpod CLI 3.4.13: `dart pub global activate serverpod_cli 3.4.13`

## Start the backend

From the repository root, generate the local `.env` and Serverpod password
files (on Windows, run this from Git Bash):

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

Then, from `puls3_server/`, start PostgreSQL and Redis and run the server with
pending migrations applied:

```bash
docker compose up --build --detach
dart run bin/main.dart --apply-migrations
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
