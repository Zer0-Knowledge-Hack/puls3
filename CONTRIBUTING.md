# Contributing to puls3

This guide is for the team. It covers how to set up your machine, run the project, and get a pull request approved.

- [1. Set up your machine](#1-set-up-your-machine)
- [2. Run the project](#2-run-the-project)
- [3. How we work](#3-how-we-work)
- [4. Code conventions](#4-code-conventions)
- [5. Security rules](#5-security-rules)
- [6. Troubleshooting](#6-troubleshooting)

---

## 1. Set up your machine

Use **these exact versions**. CI uses them too, and mismatches cause dependency errors.

| Tool | Version | Needed for |
|---|---|---|
| Flutter (includes Dart) | **3.41.4** (Dart 3.11.1) | Everything |
| Serverpod CLI | **3.4.13** | Backend code generation |
| Docker Desktop | Latest | Local Postgres + Redis for the backend |
| Git | Latest | Everything |
| GitHub CLI (`gh`) | Latest | Optional, for PRs from the terminal |
| Node.js | 18+ | Only for `design/logo-lab` |
| Rust + Stellar CLI | Rust **1.98.1**+, Stellar CLI **28.0.0** | Only for Soroban contracts. See [contracts/README.md](contracts/README.md) |

### 1.1 Flutter and Dart

1. Follow the official guide for your OS: https://docs.flutter.dev/get-started/install. Choose the **web** target.
2. Switch to the pinned version:
   ```bash
   cd <your-flutter-folder>
   git fetch --tags
   git checkout 3.41.4
   flutter --version   # must say Flutter 3.41.4 and Dart 3.11.1
   ```
3. Check your setup: `flutter doctor`. For this project you only need **Chrome (web)** to be ✓.

### 1.2 Serverpod CLI

```bash
dart pub global activate serverpod_cli 3.4.13
serverpod version
```

If `serverpod` is not found, add the pub cache `bin` folder to your `PATH`:

| OS | Folder |
|---|---|
| Windows | `%LOCALAPPDATA%\Pub\Cache\bin` |
| macOS / Linux | `$HOME/.pub-cache/bin` |

> Do not install Serverpod 4.x yet: it needs Dart ≥ 3.12.2. The upgrade is tracked in #16.

### 1.3 Docker

Install Docker Desktop (https://www.docker.com/products/docker-desktop) and make sure it is running: `docker --version`.

---

## 2. Run the project

### 2.1 Clone and install dependencies

```bash
git clone https://github.com/Zer0-Knowledge-Hack/puls3.git
cd puls3
flutter pub get        # installs the whole workspace (server, client, app)
```

The repo is a **Dart pub workspace**. The root `pubspec.yaml` groups `puls3_server`, `puls3_client`, and `puls3_flutter`, so one `pub get` covers all three.

### 2.2 Run the app (frontend only)

The app currently uses mock data, so it does not need the backend.

```bash
cd puls3_flutter
flutter run -d chrome
```

To check a production build:

```bash
flutter build web --release
npx http-server build/web -p 5000    # open http://localhost:5000
```

Use a port other than 8080, because the backend uses 8080.

### 2.3 Run the backend

1. **Generate your local secrets (first time only):**
   ```bash
   ./scripts/setup-local-secrets.sh
   ```
   This creates `puls3_server/.env` and `puls3_server/config/passwords.yaml` with random values that are only valid on your machine. Both files are git-ignored. On Windows, run it from **Git Bash**.
2. **Start Postgres and Redis:**
   ```bash
   cd puls3_server
   docker compose up --build --detach
   ```
3. **Start the server:**
   ```bash
   dart bin/main.dart --apply-migrations
   ```
4. **Stop everything when you are done:** press `Ctrl+C` to stop the server, then run `docker compose stop`.

| Service | Local port |
|---|---|
| API server | 8080 |
| Serverpod Insights | 8081 |
| Web server | 8082 |
| Postgres (dev / test) | 8090 / 9090 |
| Redis (dev / test) | 8091 / 9091 |

### 2.4 After changing Serverpod models or endpoints

```bash
cd puls3_server
serverpod generate
```

Always commit the generated code. CI and reviewers check that `serverpod generate` leaves no diff.

### 2.5 Checks to run before opening a PR

```bash
# App
cd puls3_flutter && flutter analyze && flutter test

# Server (same checks CI runs)
cd puls3_server && dart analyze --fatal-infos && dart format --set-exit-if-changed .
```

---

## 3. How we work

### 3.1 Issues

Every piece of work starts from an issue. Each issue has:

- **Exactly one area label:**
  - `area: docs` · `area: architecture` · `area: domain` · `area: contracts`
  - `area: backend` · `area: blueprints` · `area: frontend` · `area: infra`
- **One type label:** `type: feat` · `type: docs` · `type: spike` · `type: chore`
- **One priority:** `P0` (blocks a deadline) · `P1` · `P2`
- **A milestone:** `Stellar Odyssey (Sep 25)` · `Stellar Elite (Oct 10)` · `Serverpod (Oct 14)` · `HackMeridian (Oct 25)`

Each issue lists its **Deliverables**, **Acceptance criteria**, **How to verify**, **Out of scope**, and **Depends on**. Read all of them before starting. New issues use the **Task** form, which requires all of these fields.

**To take an issue:** assign yourself on GitHub and leave a comment. Check its **Depends on** list first: if a dependency is still open, coordinate with its owner.

### 3.2 Branches

```
<type>/<issue-number>-<short-slug>
```

Examples: `feat/13-identity-registry`, `docs/2-vision`, `chore/29-ci`.

Always branch from an up-to-date `main`.

### 3.3 Commits

We use [Conventional Commits](https://www.conventionalcommits.org):

```
feat(app): add hire confirmation screen
fix(server): reject replayed payment hashes
docs: add product vision
chore: pin Flutter version in CI
```

Keep commits small and focused. Keep tests and docs in the same commit as the code they cover.

### 3.4 Pull requests

1. Open the PR against `main`. The description is pre-filled from `.github/pull_request_template.md`.
2. In the description:
   - `Closes #N` **only if every acceptance criterion is met**. Otherwise, use `Refs #N` and say what is missing.
   - Copy the issue's acceptance criteria as a checklist and tick what is done.
   - Add evidence: command output, screenshots, GIFs, tx hashes, as the issue asks.
3. Add the same labels and milestone as the issue.
4. CI must be green.

**Review rule:** a PR is approved only when **every acceptance criterion is checked** and the issue's **How to verify** steps pass for the reviewer. It needs at least **1 approval from someone other than the author**. If something is missing, the reviewer requests changes and names the exact criterion that failed.

### 3.5 Where each area lives

This table follows [ADR-0001](docs/adr/0001-system-architecture.md#3-repo-layout).

| Area label | Folder |
|---|---|
| `area: docs` | `docs/`, `assets/`, `design/` |
| `area: architecture` | `docs/adr/`, `docs/architecture/`, `docs/spikes/`, `spikes/` |
| `area: blueprints` | `docs/blueprints/` |
| `area: domain` | `puls3_domain/` (pure Dart package, created by #9) |
| `area: contracts` | `contracts/` (Cargo workspace, created by #12) |
| `area: backend` | `puls3_server/`, and `puls3_client/` through `serverpod generate` only |
| `area: frontend` | `puls3_flutter/` |
| `area: infra` | `.github/`, `scripts/` |

---

## 4. Code conventions

### Architecture

- **Hexagonal:** business rules live in a pure Dart domain, which must not import Serverpod, Flutter, or the Stellar SDK. Frameworks and the chain are adapters behind ports. This is defined in ADR-0001 (#5).
- **Flutter UI:**
  - **Atomic design:** `lib/src/ui/atoms`, `molecules`, `organisms`; screens in `lib/src/screens`.
  - **Container/presentational:** presentational widgets receive data through their constructors and never call the client. Only containers hold state and call services.
- **Money is never a `double`.** Store amounts as integers in the asset's smallest unit (USDC has 7 decimals, so 0.50 USDC = `5000000`).

### Design and brand

- Follow the **[brand guide](docs/brand/README.md)**.
- All colors, fonts, and spacing come from the theme file (`puls3_flutter/lib/src/theme/puls3_theme.dart`), which mirrors `docs/brand/tokens.json`. **No hex colors anywhere else.**
- Never use Stellar yellow `#FDDA24`, and never imitate the Stellar logo. Our identity is *inspired by* Stellar, not copied.
- Use the logo SVGs from `assets/brand/`. Never retype the logo as text.

### Language

Code, comments, UI copy, docs, commits, and PRs are in **English**.

---

## 5. Security rules

The repo is **public**. Anything you push can be seen and copied.

- **Never commit secrets:** Stellar secret seeds (`S…`), API keys, passwords, or `.env` files.
- Local secrets live in git-ignored files (`puls3_server/.env`, `puls3_server/config/passwords.yaml`). Use `scripts/setup-local-secrets.sh` to create them.
- Read keys from environment variables, and document every new one in an `.env.example`.
- If you leak a secret, tell the team right away and rotate it. Deleting the commit is not enough.

---

## 6. Troubleshooting

| Problem | Fix |
|---|---|
| `version solving failed` / `requires SDK version ^3.10` | Your Flutter is not 3.41.4. See [1.1](#11-flutter-and-dart). |
| `serverpod: command not found` | Add the pub cache `bin` folder to your `PATH` ([1.2](#12-serverpod-cli)). |
| `set it in puls3_server/.env` when running Docker | Run `./scripts/setup-local-secrets.sh` first. |
| Port 8080 already in use | Another process uses it (maybe a static server). Stop it, or serve the web build on another port. |
| The web app shows an old version | Hard reload with `Ctrl+Shift+R`: Flutter caches the app in a service worker. |
