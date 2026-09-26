# puls3 Serverpod backend

Serverpod **3.4.13**, pinned on **2026-09-26**. The backend currently exposes a
minimal `health` endpoint so the Flutter app can verify the generated client,
server, and shared workspace are connected.

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
