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

## Working with git worktrees

A new `git worktree` starts without the git-ignored files the tests need:
`puls3_server/.env`, `puls3_server/config/passwords.yaml`,
`puls3_server/.env.local-soroban` and the built WASM under `contracts/target/`.
Prepare each worktree on its own (#327):

1. **Create the secrets in every worktree.** Run `./scripts/setup-local-secrets.sh`
   from the worktree root. It needs no Docker and never overwrites existing files.
2. **Never copy `.env` or `passwords.yaml` from another checkout.** Copying
   spreads one secret across directories. Generate fresh ones instead.
3. **Use one Compose project per worktree.** `docker-compose.yaml` sets no
   `name:`, so every checkout shares the project `puls3_server` and its named
   volumes. Postgres sets its password only when the volume is created, so a
   second worktree with its own random `.env` fails with
   `28P01 password authentication failed`. Give each worktree its own project:

   ```bash
   docker compose -p puls3_wt_<name> -f puls3_server/docker-compose.yaml up -d
   docker compose -p puls3_wt_<name> -f puls3_server/docker-compose.yaml down -v
   ```

4. **Run the services of one worktree at a time.** The ports (8000, 8090, 8091,
   9090, 9091) are fixed, so two worktrees cannot run them together. Stop one
   worktree's project (`down`) before starting another's.
5. **Get the WASM.** Either build it in this worktree (`(cd contracts &&
   stellar contract build)`) or copy the git-ignored `contracts/target/`
   artifacts from another checkout; they hold no secret. A copied WASM is
   deployed as it is: the setup script never rebuilds a WASM that already
   exists, so make sure it was built from the code you are testing.
6. **Rebuild after contract changes.** `scripts/setup-local-soroban.sh` skips
   the build whenever the WASM file already exists, with or without
   `--skip-build` (`--skip-build` only turns a missing WASM into an error). After
   changing the contracts, or after copying `contracts/target/`, run
   `(cd contracts && stellar contract build)` or delete
   `contracts/target/wasm32v1-none/release/*.wasm` before the script. Otherwise
   it deploys contracts that no longer match `main`, and the E2E then fails with
   `JobMismatch (job_id)`.

On Windows, `melos` needs Developer Mode symlinks and its scripts use POSIX
`case`: run it from Git Bash or WSL, or use `dart pub get` plus `dart test` per
package (see the README and CONTRIBUTING).

After these steps `git status --short` stays clean: `.env`, `passwords.yaml`,
`.env.local-soroban` and `contracts/target/` are all git-ignored.

### Decision: stale database volume

Should `setup-local-secrets.sh` refuse to run, or warn, when the test database
volume already exists with another password? **Print a one-line warning; do not
refuse.** Creating a new `.env` is harmless and often correct (a first run, or
a worktree with its own `-p` project), while a refusal would block those cases
and needs Docker to detect the volume. A warning (for example "volume
`<project>_puls3_test_data` exists; if you see `28P01`, run `down -v` or use a
separate `-p` project") covers the failure at no cost. Implementing it is a
follow-up to the script; this change is documentation only.

## Run the E2E suites

```bash
melos run test:e2e        # or, per package, without melos:
cd puls3_server && dart test -t e2e --run-skipped -j 1 test/e2e
```

The suites share the test database, so they run one at a time (`-j 1`).

| Suite | What it proves |
|---|---|
| `hire_relay_e2e_test.dart` | create and fund a hire with the XDR signed unchanged (#255) |
| `feedback_e2e_test.dart` | approve, rate and count a delivered hire (#255, #287) |
| `subcontracting_e2e_test.dart` | the subcontracting journey of #334: happy path with reserve accounting, rejection, restart (#374) |
| `subcontract_limits_e2e_test.dart` | reserve (#124), cycle (#127), depth (#126), the children cap and a spent reserve (#374) |
| `subcontract_expiry_e2e_test.dart` | a child that is never delivered is refunded and the parent stays consistent (#374) |

The subcontracting suites run the production wiring of the subcontract executor
with a deterministic stand-in for the model (`support/subcontract_world.dart`).
`startAgentRuntime` itself is not exercised, because it has no seam for a
stand-in model; the suites compose the same pieces (`buildSubcontractServices`,
`HireRunner`, the real stores) and drive the passes by hand.

Things the suites rely on:

- **Redeploy, then clear the test database.** A redeployed escrow numbers its
  jobs from 1 again, and hires left in the test database by a run on the old
  ledger hold those ids, so a new `create_job` fails with `JobMismatch`. After
  `scripts/setup-local-soroban.sh` truncate the hire tables of the test
  database (`hire`, `hire_payment`, `hire_run`, `chain_submission`,
  `escrow_preparation`, `agent_wallet`, `terminal_job_fact`) or run
  `docker compose down -v` first.
- **Job duration.** The sandbox helper sets `PULS3_HIRE_JOB_DURATION_SECONDS`
  to 259200 (three one-day approval windows). A child must expire a full
  approval window plus `childExpiryMarginSeconds` before its parent and leave
  `childRunHeadroom` to run, so with the one-day window a shorter duration
  makes `subcontract` refuse with `parent_too_short`.
- **Reserve ceiling.** `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS` is set by the
  suites to `subcontractMaxChildrenCap` children at the sandbox price. ADR-0011
  D1 names a configured ceiling per network but no value.
- **Expiry.** The expiry suite shortens the escrow's approval window with the
  admin identity for its own run and restores it afterwards, because a child
  outlives that window and the ledger clock cannot be moved. It needs the
  `STELLAR_ACCOUNT` identity of `.env.local-soroban` to be the escrow admin.
  It fails fast when the window is not the sandbox default (86400 s), which
  means an earlier run was killed before it could restore it: reset the
  window to 86400 s (or redeploy the escrow) and run it again.
- **Relay key.** The `test:` passwords hold no `escrowRelaySigningKey`, so the
  tracker's deadline relay is off in the tests; the subcontracting suites run
  the same `EscrowDeadlineRunner` with an ephemeral, friendbot-funded account.

## Check the migrations

CI runs `scripts/check-migrations.sh` (#373) whenever a migration or a `.spy.yaml`
model changes. It fails when the models need a migration that is not committed, or
when a database built from all the migrations ends with a different schema than
one built from the base branch's migrations and then this branch's.

Run the same check locally against the integration-test database. It needs
`serverpod`, `psql` and `pg_dump` on the PATH (or `PG_CONTAINER=<container>` to
run the Postgres tools inside the container), and a clean `puls3_server/migrations`:

```bash
docker compose -f puls3_server/docker-compose.yaml up -d postgres_test
# PGPASSWORD is POSTGRES_TEST_PASSWORD from puls3_server/.env, and the `test:`
# section of puls3_server/config/passwords.yaml must hold the same `database` value.
PGPORT=9090 PGPASSWORD=<POSTGRES_TEST_PASSWORD> scripts/check-migrations.sh
```

The base defaults to the merge base with `origin/main`; pass another commit as the
first argument. To use another database server, set `PGHOST`, `PGPORT`, `PGUSER`
and `PGPASSWORD`; the script reaches it through the server's
`SERVERPOD_DATABASE_HOST` and `SERVERPOD_DATABASE_PORT`, and names the scratch
databases through `SERVERPOD_DATABASE_NAME`. It creates `mig_fresh` and
`mig_upgraded` and drops both when it ends.

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
