# puls3 Serverpod backend

Serverpod **4.0.4**, pinned on **2026-10-07**. The backend currently exposes a
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

## Prerequisites

- Dart 3.12.2
- Flutter 3.44.4 (to run the app)
- Docker with Docker Compose
- Serverpod CLI 4.0.4: `dart pub global activate serverpod_cli 4.0.4`

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

## Health version and allowed origins

`health.check` returns the package version from `pubspec.yaml`. When
`PULS3_GIT_SHA` is set, the commit is appended as semver build metadata, for
example `1.0.0+63fbad2`, so a deployed server names the commit it runs. A value
with characters other than letters, digits, `-` and `.` stops the server at
startup.

Browsers may call the API server only from a loopback origin (`localhost`,
`127.0.0.1` or `[::1]`, any port) or from an origin listed in
`PULS3_ALLOWED_ORIGINS` (comma-separated, for example
`https://puls3-4lw.pages.dev`). A request from any other origin gets `403`
before an endpoint runs. Requests without an `Origin` header, such as `curl`,
are not affected.

Serverpod 3.4.13 answers CORS preflight (`OPTIONS`) requests in its own core
middleware, before added middleware runs, so preflight responses still carry
`Access-Control-Allow-Origin: *`. The request that follows is still rejected
when its origin is not allowed.

## Deploy to Serverpod Cloud

The server runs on Serverpod Cloud, which also provides its PostgreSQL
database. The Flutter web app is deployed separately to Cloudflare Pages (not
covered here); build it with `--dart-define=PULS3_API_URL=<api-url>` so it
calls this server.

| | URL |
|---|---|
| API server | `https://<project-id>.api.serverpod.space/` (fill in after the first deploy) |
| Health check | `POST https://<project-id>.api.serverpod.space/health/check` |

Run every command from `puls3_server/` (Git Bash on Windows). The commands were
checked against `serverpod_cloud_cli` 1.0.0 (`scloud help <command>`).

### First deploy

Do this once per project. Later deploys only need [Redeploy](#redeploy).

1. **Install the CLI.** Version 1.0.1 needs Dart 3.12.2 or newer. Version
   1.0.0 does not compile when pub resolves `serverpod_cloud_shared` 1.0.1, so
   upgrade Dart (or Flutter) first if `dart --version` is older.

   ```bash
   dart pub global activate serverpod_cloud_cli
   scloud version
   ```

2. **Log in.** Create an account at <https://accounts.serverpod.dev/> first.

   ```bash
   scloud auth login
   ```

3. **Create the project and link it.** Project ids are global; pick a free one.
   `--plan` selects `starter` or `growth`, which can incur cost: check the plan
   and the hackathon credits before you run it.

   ```bash
   scloud project create <project-id> --enable-db
   scloud project link <project-id>
   ```

   `project link` writes the id into `scloud.yaml`, replacing
   `REPLACE_WITH_PROJECT_ID`. Commit that change, so teammates can deploy
   without linking. It only holds the project id, not credentials. Do not use
   `scloud launch` here: it would add `serverpod run flutter_build` and
   `serverpod generate` as pre-deploy scripts, and neither is needed.

4. **Set the environment variables.** Values are public, so they are plain
   variables, not secrets.

   ```bash
   scloud variable set SERVERPOD_APPLY_MIGRATIONS true
   scloud variable set PULS3_ALLOWED_ORIGINS https://puls3-4lw.pages.dev
   ```

   `SERVERPOD_APPLY_MIGRATIONS=true` makes Serverpod apply pending migrations
   from `migrations/` at every start (the same as `--apply-migrations`
   locally). Use the origin of the Cloudflare Pages deployment, comma-separate
   several, and never add a trailing path. The `PULS3_STELLAR_*` variables
   default to testnet, so they are only needed to point at another network.
   Leave `PULS3_TRACKER_ENABLED` unset: the chain submission tracker stays off
   in this deployment.

5. **Check the passwords.** Serverpod Cloud generates and manages `database`,
   `redis`, `serviceSecret`, `emailSecretHashPepper`, `jwtHmacSha512PrivateKey`
   and `jwtRefreshTokenHashPepper`, so nothing has to be set today. List them
   with `scloud password list`. Never upload `config/passwords.yaml`.

6. **Deploy** (see [Redeploy](#redeploy)).

### Secrets in Serverpod Cloud

How each row of `docs/infra/secrets.md` (#30) maps to Serverpod Cloud:

| Secret | In Serverpod Cloud |
|---|---|
| `database`, `redis`, `serviceSecret` | Platform-managed. No action |
| `emailSecretHashPepper`, `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper` | Platform-managed. No action |
| `serverSideSessionKeyHashPepper` | Not used: the server issues JWTs only |
| `mySharedPassword` | Unused template entry. Do not set |
| Server signing key, per-agent wallet encryption key, LLM provider key (planned) | `scloud password set <name> --from-file <file>`. The server reads it with `getPassword('<name>')` (injected as `SERVERPOD_PASSWORD_<name>`) |
| Stellar CLI keys (deployer, escrow admin, agent wallet, test client, test USDC issuer) | Never. They stay in the Stellar CLI config of the person who runs the scripts |

Use `scloud variable set --secret <NAME> <value>` only for a secret that must
not get the `SERVERPOD_PASSWORD_` prefix. Prefer `--from-file` over a value on
the command line, so the secret does not land in the shell history.

### Redeploy

Anyone with access to the project can redeploy from a clean checkout of `main`:

```bash
scloud auth login                    # once per machine
git switch main && git pull
scloud variable set PULS3_GIT_SHA "$(git rev-parse --short HEAD)"
scloud deploy --show-files           # uploads, builds and rolls out
scloud status deployment show        # follow the rollout
curl -s -X POST https://<project-id>.api.serverpod.space/health/check
```

The health check returns JSON whose `version` names the commit you deployed,
for example `1.0.0+63fbad2`. `scloud deploy` warns when the working
tree has uncommitted changes: they are uploaded but the deploy is recorded
against the last commit.

Useful commands:

| Task | Command |
|---|---|
| Live status and service URLs | `scloud status live` |
| Server logs | `scloud log --tail` |
| Build log of the last deploy | `scloud build log` |
| List variables | `scloud variable list` |
| Apply changed variables without uploading | `scloud deploy --redeploy` |
| Preview the upload without deploying | `scloud deploy --wet-run --show-files` |

The upload follows `.gitignore` and the repository-root `.scloudignore`:
passwords, run-mode configs (Serverpod Cloud generates the server
configuration), tests, Docker files and `web/app` are left out.
