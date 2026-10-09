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

## Agent runtime

A second background loop runs the agent of every funded hire once (#20).
When the tracker records a hire's payment, it queues a run (`hire_run`) in
the same transaction. Each pass:
1. fails runs still `running` past the timeout plus a minute (`interrupted`);
2. takes up to 10 queued runs, one at a time, with a conditional update, so
   two runners never run the same hire;
3. loads the manifest the hire pinned and calls the model through
   `AgentRunner` (input and output limits, timeout that aborts the call);
4. stores the result, or a safe failure code such as `timeout`,
   `provider_error:<type>` or `manifest_unavailable`.

Each run goes through the domain (`Hire.startRun`, `Hire.failRun`).
`HireEndpoint.getHire` shows the progress as `runtimeStatus` (`queued`,
`running`, `failed`), with the `result` and `failureReason`.

A successful run leaves the hire `funded` with its result: the server-signed
escrow `submit` that makes it `submitted` is #97. Until the #34 chain stores
deployed manifests, the demo agents' manifests are seeded in
`lib/src/runtime/demo_manifests.dart`, keyed by the agent's `id` metadata
(`agt-006` Copy Forge, `agt-007` Support Relay). Both run on Cloudflare
Workers AI (`@cf/meta/llama-3.3-70b-instruct-fp8-fast`), the free provider of
the #34 model policy. `ProviderRouter` sends each run to its manifest's
provider; a provider without credentials fails the run as
`unsupported_provider`.

| Setting | Default | Meaning |
|---|---|---|
| `PULS3_RUNTIME_ENABLED` | `false` | Only `true` starts the loop |
| `PULS3_RUNTIME_INTERVAL_SECONDS` | `5` | Seconds between passes; a positive whole number |
| `PULS3_RUNTIME_TIMEOUT_SECONDS` | `120` | Longest one run may take; it must end before the job's `expired_at` |
| `PULS3_WORKERS_AI_ACCOUNT_ID` | none | Cloudflare account id for Workers AI (public) |
| Serverpod password `workersAiApiToken` | none | Cloudflare API token for Workers AI. Locally, `shared: workersAiApiToken:` in `config/passwords.yaml`; on Serverpod Cloud, `scloud password set workersAiApiToken --from-file <file>` |
| Serverpod password `anthropicApiKey` | none | Optional Anthropic API key, for manifests with provider `anthropic` (BYOK) |

With neither provider configured the loop does not start, even when enabled.

The server-wide `workersAiApiToken` is for the seeded demo agents only. Builder
agents run on the builder's own provider account (ADR-0004 amendment, #142),
resolved from the deploy record once #18/#35 land.

It is off by default so tests, CI and existing deployments never call a paid
model. It writes `[agent-runtime]` lines to stdout (info) and stderr
(warnings).

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
example `1.0.0+63fbad2`, so a deployed server names the commit it runs. Without
it, `health.check` returns `1.0.0` alone. A value with characters other than
letters, digits, `-` and `.` stops the server at startup.

Browsers may call the API server only from an origin listed in
`PULS3_ALLOWED_ORIGINS` (comma-separated, for example
`https://puls3-4lw.pages.dev`). In the `development` run mode, loopback origins
(`localhost`, `127.0.0.1` or `[::1]`, any port) are allowed as well; in
`production`, `staging` and `test` they are not. A request from any other
origin, or with several `Origin` headers, gets `403` before an endpoint runs.
Requests without an `Origin` header, such as `curl`, are not affected.

Serverpod 4.0.4 answers CORS preflight (`OPTIONS`) requests in its own core
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
| API server | `https://puls3-hub-on-stellar.api.serverpod.space/` |
| Health check | `POST https://puls3-hub-on-stellar.api.serverpod.space/health/check` |

Run every command from `puls3_server/`. The commands were checked against the
help output and source of `serverpod_cloud_cli` **1.0.0**.

> **Git Bash on Windows:** pub installs the CLI as `scloud.bat`, which Git Bash
> does not find as `scloud`. Run `alias scloud=scloud.bat` first, or use
> PowerShell or cmd.

### First deploy

Do these steps once, in order. Steps 1 and 2 are per machine; steps 3 to 7 are
per project.

1. **Install the CLI.** Pick the path that matches `dart --version`:

   - **Dart 3.12.2 or newer (preferred):**

     ```bash
     dart pub global activate serverpod_cloud_cli 1.0.1
     ```

     1.0.1 is the latest release and needs Dart 3.12.2. The first deploy of
     `puls3-hub-on-stellar` used it.

   - **Older Dart (3.10.3 to 3.12.1):** `dart pub global activate
     serverpod_cloud_cli 1.0.0` installs but does not compile, because pub
     picks `serverpod_cloud_shared` 1.0.1, which dropped a class 1.0.0 uses.
     Install 1.0.0 with that dependency pinned instead:

     ```bash
     mkdir -p ~/scloud-1.0.0/bin && cd ~/scloud-1.0.0
     printf '%s\n' \
       'name: scloud_1_0_0' \
       'publish_to: none' \
       'environment:' \
       "  sdk: '>=3.10.3 <4.0.0'" \
       'dependencies:' \
       '  serverpod_cloud_cli: 1.0.0' \
       'dependency_overrides:' \
       '  serverpod_cloud_shared: 1.0.0' \
       'executables:' \
       '  scloud: scloud' > pubspec.yaml
     dart pub get
     # Windows: $LOCALAPPDATA/Pub/Cache. macOS/Linux: $HOME/.pub-cache.
     PUB_CACHE_DIR="${PUB_CACHE:-$LOCALAPPDATA/Pub/Cache}"
     cp "$PUB_CACHE_DIR/hosted/pub.dev/serverpod_cloud_cli-1.0.0/bin/serverpod_cloud_cli.dart" bin/scloud.dart
     dart pub global activate --source path .
     cd -
     ```

   Check it with `scloud version`.

2. **Log in.** Create an account at <https://accounts.serverpod.dev/> first.

   ```bash
   scloud auth login
   ```

3. **Create the project with a database.** Project ids are global; pick a free
   one. `starter` is the smaller of the two plans the CLI offers (`starter`,
   `growth`). A plan can be billed: check its price and apply the hackathon
   credits in the Serverpod Cloud console before you run this.

   ```bash
   scloud project create <project-id> --plan starter --enable-db
   ```

4. **Link the project.** This writes the id into `scloud.yaml`, replacing
   `REPLACE_WITH_PROJECT_ID`, and keeps the pre-deploy script. Commit the
   change, so teammates can deploy without linking. The file holds only the
   project id, not credentials.

   ```bash
   scloud project link <project-id>
   git add scloud.yaml && git commit -m "chore(server): link Serverpod Cloud project"
   ```

   Do not use `scloud launch` here: it adds `serverpod run flutter_build` and
   `serverpod generate` as pre-deploy scripts, and neither is needed.

5. **Set the environment variables.** The values are public, so they are plain
   variables, not secrets.

   ```bash
   scloud variable set SERVERPOD_APPLY_MIGRATIONS true
   scloud variable set PULS3_ALLOWED_ORIGINS https://puls3-4lw.pages.dev
   ```

   - `SERVERPOD_APPLY_MIGRATIONS=true` makes Serverpod apply pending migrations
     from `migrations/` at every start (the same as `--apply-migrations`
     locally).
   - `PULS3_ALLOWED_ORIGINS` is the origin of the Cloudflare Pages deployment
     (no path; comma-separate several).
   - `PULS3_GIT_SHA` is set by the pre-deploy script in step 6. Do not set it
     by hand.
   - `PULS3_STELLAR_*` default to testnet. Set them only for another network.
   - Leave `PULS3_TRACKER_ENABLED` unset: the chain submission tracker stays
     off in this deployment.

   Serverpod Cloud generates and manages the passwords the server needs today
   (see [Secrets in Serverpod Cloud](#secrets-in-serverpod-cloud)). Check them
   with `scloud password list`.

6. **Deploy.**

   ```bash
   scloud deploy --show-files
   ```

   Before it uploads, `scloud deploy` runs the pre-deploy script from
   `scloud.yaml` on your machine, in `puls3_server/` (through `cmd /c` on
   Windows, `bash -c` elsewhere): `dart run tool/set_deploy_sha.dart` sets
   `PULS3_GIT_SHA` to `git rev-parse --short HEAD`, with a `-dirty` suffix when
   tracked files have uncommitted changes. If the script fails (no `git`, no
   `scloud` on the `PATH`, not logged in), the deploy stops before uploading.
   The command waits for the rollout. To follow it again later, run
   `scloud status deployment show`.

7. **Verify.** Replace `<api>` with `https://<project-id>.api.serverpod.space`.

   ```bash
   curl -s -X POST -d '{}' <api>/health/check
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: https://puls3-4lw.pages.dev' <api>/health/check   # 200
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: https://evil.example.com' <api>/health/check      # 403
   curl -s -o /dev/null -w '%{http_code}\n' -X POST -d '{}' \
     -H 'Origin: http://localhost:3000' <api>/health/check         # 403
   ```

   The first call returns JSON whose `version` is `1.0.0+<sha>` for the commit
   you deployed. If it shows `1.0.0` alone, `PULS3_GIT_SHA` was not applied:
   check `scloud variable list`, then run `scloud deploy --redeploy`. The
   localhost call must return 403: loopback origins are allowed only in the
   `development` run mode. A 200 there means the server is not running in
   `production`; check the "run mode" line in `scloud log` before going on.
   Finally, put the API URL in the root README.

### Redeploy

Anyone with access to the project, on a machine where steps 1 and 2 are done:

1. Update `main`: `git switch main && git pull`.
2. Deploy: `scloud deploy`. The pre-deploy script sets `PULS3_GIT_SHA`.
3. Verify with the three calls of step 7. `version` must name the commit you
   just pulled.

To change only variables (no new code), run `scloud variable set ...` and then
`scloud deploy --redeploy`, which redeploys the running build with the latest
variables and secrets.

### If a deploy or migration fails

| Look at | Command |
|---|---|
| Rollout state of the latest deploy | `scloud status deployment show` |
| Build output (compile and dependency errors) | `scloud build log` |
| Server logs (startup, migrations, requests) | `scloud log --since 1h` or `scloud log --tail` |
| Running podlets and service URLs | `scloud status live` |

- **Fix forward:** fix the cause on a branch, merge it to `main`, and redeploy.
- **Go back to a known good commit:** `git switch --detach <good-sha>`, then
  `scloud deploy`. The CLI has no rollback command, so this uploads and builds
  that commit again.
- **Migrations** only move forward. Older code is not guaranteed to work
  against a newer schema, so prefer fixing forward once a migration has run.
  `scloud db backup` manages database snapshots; take one before a risky
  migration.

Not verified from the CLI (check on the first deploy): whether a failed build
or rollout keeps the previous deployment serving, and whether a variable set
by the pre-deploy script is always applied by the same deploy (the step 7
check catches it).

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

Use `scloud variable set --secret <NAME> --from-file <file>` only for a secret
that must not get the `SERVERPOD_PASSWORD_` prefix. Prefer `--from-file` over a
value on the command line, so the secret does not land in the shell history.
Never upload `config/passwords.yaml`.

### Reference

| Task | Command |
|---|---|
| List variables | `scloud variable list` |
| Apply changed variables without uploading | `scloud deploy --redeploy` |
| Preview the upload without deploying | `scloud deploy --wet-run --show-files` |

The upload follows `.gitignore` and the repository-root `.scloudignore`:
passwords, run-mode configs (Serverpod Cloud generates the server
configuration), tests, Docker files and `web/app` are left out.
