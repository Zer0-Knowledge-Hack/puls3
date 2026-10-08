# Secrets and testnet configuration

The repo is public. **No secret is ever committed**: not in code, not in `.env.example`, not in `contracts/deployments/`. Every secret lives in exactly one of three places: a git-ignored local file, a GitHub Actions secret, or Serverpod Cloud. Everything else (RPC URL, passphrase, contract ids, public keys) is public configuration and lives in [`.env.example`](../../.env.example).

## Run against testnet from a fresh clone

This is the canonical setup path; CONTRIBUTING.md, the root README and `puls3_server/README.md` link here. Run every command from **Git Bash** on Windows. Prerequisites: Flutter, Serverpod CLI 4.0.4 and Docker ([CONTRIBUTING.md §1](../../CONTRIBUTING.md#1-set-up-your-machine)), and the Stellar CLI for step 4 ([contracts/README.md](../../contracts/README.md#prerequisites)).

Two env files, two jobs:

| File | Holds | Created by |
|---|---|---|
| `.env` (repo root) | Public config for the server, the app and the scripts, plus Stellar CLI identity **names**. No secrets | `cp .env.example .env` |
| `puls3_server/.env` | Local Docker passwords for Postgres and Redis (secrets, local only), read by `docker compose` | `scripts/setup-local-secrets.sh` |

1. **Install the workspace:** `flutter pub get` (repo root).
2. **Local secrets:** `./scripts/setup-local-secrets.sh`. It creates `puls3_server/.env` and `puls3_server/config/passwords.yaml` with random values. Both are git-ignored.
3. **Root config:** `cp .env.example .env`. The testnet values are already filled in.
4. **Your testnet identity** (only for the scripts; the server and app run without it):

   ```bash
   stellar keys generate <name> --fund --network testnet
   ./scripts/fund-testnet-accounts.sh <name>   # optional: more XLM and 100 test USDC (PUSDC)
   ```

   Then set `STELLAR_ACCOUNT=<name>` in `.env`. The same applies to the other identity names (`AGENT_WALLET_ACCOUNT`, `CLIENT_ACCOUNT`) when a script needs them. `.env` holds the name, never the key.
5. **Backend** (from `puls3_server/`):

   ```bash
   docker compose up --build --detach
   set -a; . ../.env; set +a
   dart bin/main.dart --apply-migrations
   ```

   The API listens on `http://localhost:8080`. Stop with `Ctrl+C`, then `docker compose stop`.
6. **App** (from `puls3_flutter/`, in a second terminal):

   ```bash
   flutter run -d chrome --dart-define-from-file=../.env
   ```

   The app loads the agent catalog from the server and falls back to the bundled demo catalog when the server is unreachable.

Switching from testnet to a local network changes only the `PULS3_STELLAR_*` values in `.env`. `PULS3_API_URL` points the app at another server. No code changes.

## Where configuration lives

| What | Single place | Read by |
|---|---|---|
| Server network config (public) | `.env` → `PULS3_STELLAR_*`, `PULS3_TRACKER_*` | `StellarConfig.fromEnvironment`, `TrackerLoopConfig.fromEnvironment` |
| Server secrets | `puls3_server/config/passwords.yaml` locally; `SERVERPOD_*` env vars in a deployment | Serverpod `PasswordManager` |
| App config (public, compile time) | `.env` → `PULS3_API_URL`, `PULS3_ESCROW_CONTRACT` via `--dart-define-from-file` | `resolveApiUrl`, `defaultEscrowContractAddress` |
| Script settings | `.env` → identity names and options | `scripts/*.sh` |
| Stellar keys | Stellar CLI config (`stellar keys`), outside the repo | `stellar` CLI only |

The app compiles its dart-defines into the build, which is one more reason `.env` must never hold a secret.

## Secrets

Access roles: **each developer** (own machine only), **maintainers** (GitHub repo admins), **deployer** (the maintainer who ran the testnet deploy scripts and holds those CLI identities).

| Secret | Purpose | Where it is stored | Who has access | How to rotate |
|---|---|---|---|---|
| Deployer / registry owner key (`STELLAR_ACCOUNT` identity, testnet `GBY33…TJ4R`) | Deploys contracts, owns the Identity Registry and the seeded demo agents | Stellar CLI config on the deployer's machine. `.env` holds only the identity **name** | Deployer | Generate a new identity and redeploy with `scripts/deploy-testnet.sh`, then re-seed. The registry has no owner transfer. Update `contracts/deployments/testnet.json` and `.env.example` |
| Escrow admin key (testnet `GAFUY…IFKY`) | Admin of the Agent Escrow (allow-list tokens, `set_admin`, `set_treasury`). Also the demo agent wallet | Stellar CLI config on the deployer's machine | Deployer | `set_admin` to a new identity's address, or `scripts/deploy-escrow-testnet.sh --redeploy` |
| Agent wallet key (`AGENT_WALLET_ACCOUNT` identity) | Provider wallet bound with `set_agent_wallet` for the demo agents | Stellar CLI config. Defaults to the deployer identity | Deployer | New identity, then re-run `scripts/seed-demo-agents.sh` (it re-binds the wallet) |
| Test client key (`CLIENT_ACCOUNT` identity) | Client and evaluator in `deploy-escrow-testnet.sh --test-job / --direct-payment` | Stellar CLI config | Whoever runs the evidence jobs | Generate a new identity and fund it. Nothing on chain points to it |
| Test USDC issuer key (`TEST_USDC_ISSUER_ACCOUNT` identity, default `puls3-test-usdc-issuer`) | Issues the scripted test asset `PUSDC` in `fund-testnet-accounts.sh` | Stellar CLI config. Created on first use | Whoever runs the funding script | Remove the identity (`stellar keys rm`). The next run creates a new issuer, so a new asset and SAC |
| Per-agent wallet keys, server-custodied ([ADR-0003](../adr/0003-payment-rail-and-custody.md) §4) | One G-account per agent: trustline, earnings sweep | **Planned, not in code yet.** Encrypted in the database. The encryption key goes in Serverpod passwords (Serverpod Cloud or `SERVERPOD_PASSWORD_<name>`) | Server process only | Rotate the encryption key by re-encrypting the stored keys. A leaked wallet key is replaced by a new wallet and `set_agent_wallet` |
| Server signing key for server-signed submissions (`submit`, `release`, `claimRefund`) | Signs the escrow calls the server makes itself | **Planned, not in code yet** (`ChainSubmission` already models these purposes). Will be a Serverpod password | Server process only | New key, fund it, update the password in Serverpod Cloud |
| LLM provider API key (`anthropicApiKey`) | Runs agent tasks (`RuntimeConfig`, `AnthropicRuntime`, [ADR-0001](../adr/0001-system-architecture.md), #20) | Serverpod password `anthropicApiKey`: `passwords.yaml` (`shared`) locally, `scloud password set anthropicApiKey --from-file <file>` on Serverpod Cloud (`SERVERPOD_PASSWORD_anthropicApiKey`). Never in `.env`. Without it the runtime is disabled | Server process, maintainers | Create a new key in the provider console, update Serverpod Cloud, revoke the old key |
| `database` (`SERVERPOD_DATABASE_PASSWORD`) | Postgres password | Locally `passwords.yaml` + `POSTGRES_PASSWORD` / `POSTGRES_TEST_PASSWORD` in `puls3_server/.env`. Deployed: Serverpod Cloud | Developer (local), maintainers (cloud) | Local: delete both files and re-run `setup-local-secrets.sh` (recreate the Docker volume). Cloud: change it in Serverpod Cloud |
| `redis` (`SERVERPOD_REDIS_PASSWORD`) | Redis password | Locally `passwords.yaml` + `REDIS_PASSWORD` / `REDIS_TEST_PASSWORD` in `puls3_server/.env`. Deployed: Serverpod Cloud (Redis is disabled in staging and production configs) | Developer, maintainers | Same as `database` |
| `serviceSecret` (`SERVERPOD_SERVICE_SECRET`) | Server-to-server calls and the Serverpod Insights service protocol | `passwords.yaml` / Serverpod Cloud | Developer, maintainers | Generate a new random value and redeploy. Insights clients need the new value |
| `emailSecretHashPepper`, `jwtHmacSha512PrivateKey`, `jwtRefreshTokenHashPepper`, `serverSideSessionKeyHashPepper` (`SERVERPOD_PASSWORD_<key>`) | Email sign-in hashing and JWT signing (`serverpod_auth_idp`) | `passwords.yaml` / Serverpod Cloud | Developer, maintainers | New random value. Rotating the JWT key logs every user out. Rotating a pepper invalidates pending codes and stored hashes |
| `mySharedPassword` | Unused Serverpod template entry | `passwords.yaml` (`shared`) | Developer | Not used by the code. Safe to remove |

CI needs no GitHub secret today: `.github/workflows/ci.yml` writes throwaway test passwords, and the gitleaks scan needs none. When a deploy workflow is added, its secrets go into GitHub Actions secrets and are listed here.

### Not secrets

- **`PULS3_STELLAR_SIMULATION_SOURCE`** is a **public key** (`G…`). The server uses it only as the source account of unsigned `simulateTransaction` calls, which need an existing account. Nothing is signed with it, so knowing it gives no power over the account.
- Contract ids, the USDC SAC id, RPC URL and network passphrase are public chain data.
- `STELLAR_ACCOUNT`, `AGENT_WALLET_ACCOUNT`, `CLIENT_ACCOUNT`, `TEST_USDC_ISSUER_ACCOUNT` are identity **names**. The keys stay in the Stellar CLI config. The scripts never call `stellar keys show` or `keys secret`.

## Guard rails

| Guard | Where |
|---|---|
| `.env`, `.env.*` (except `.env.example`), `*.pem`, `*.key`, `*.p12`, `*.secret`, `secrets/`, `.stellar/`, `.soroban/`, `.config/stellar/` are ignored | [`.gitignore`](../../.gitignore) |
| `config/passwords.yaml` and the Firebase service account key are ignored | [`puls3_server/.gitignore`](../../puls3_server/.gitignore) |
| Gitleaks with a Stellar secret seed rule runs on every PR and push to `main` | [`.gitleaks.toml`](../../.gitleaks.toml), [`.github/workflows/secrets.yml`](../../.github/workflows/secrets.yml) |
| `.env.example` lists every variable read in code, matches `testnet.json`, and this table lists every secret | `bash scripts/tests/env-inventory.test.sh` |

Check locally:

```bash
git check-ignore -v .env puls3_server/.env puls3_server/config/passwords.yaml
gitleaks git --config=.gitleaks.toml .
```

## If a secret leaks

1. Rotate it first, using the table above. Removing it from git history does not un-leak it.
2. Testnet keys: move any funds you still need and stop using the identity. Testnet funds have no value, but a leaked admin key lets anyone change the escrow allow-list.
3. Open an issue (`area: infra`) that says what leaked and when. Never paste the secret in the issue.

Out of scope here: mainnet keys, HSM/KMS custody, automated rotation.
