#!/usr/bin/env bash
# Runs the browser E2E of the hire flow (#256) on the local sandbox.
#
# It seeds an agent (its key in server custody) and a funded consumer wallet,
# starts the real server on the test PostgreSQL, and drives the Flutter web app
# in headless Chrome with `flutter drive`. Every key is ephemeral and belongs to
# the local standalone network; the files that hold them live in a temp
# directory this script deletes when it ends.
#
# Needs (see puls3_server/README.md, "End-to-end suites on the local sandbox"):
#   docker compose -f puls3_server/docker-compose.yaml up -d \
#     soroban_standalone postgres_test redis_test
#   bash scripts/setup-local-soroban.sh
#   chromedriver matching your Chrome (https://googlechromelabs.github.io/chrome-for-testing/)
#
# Usage:
#   scripts/e2e-flutter-local.sh
#
# Env:
#   CHROMEDRIVER             chromedriver binary (default: chromedriver on PATH)
#   PULS3_ENV_FILE           file with POSTGRES_TEST_PASSWORD (default puls3_server/.env)
#   PULS3_E2E_TIMEOUT_SECONDS  server readiness timeout (default 180)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$REPO_ROOT/puls3_server"
FLUTTER_DIR="$REPO_ROOT/puls3_flutter"
ENV_FILE="${PULS3_ENV_FILE:-$SERVER_DIR/.env}"
CHROMEDRIVER="${CHROMEDRIVER:-chromedriver}"
TIMEOUT_SECONDS="${PULS3_E2E_TIMEOUT_SECONDS:-180}"
API_URL="http://localhost:8180/"
DRIVER_PORT=4444

case "${1:-}" in
  -h | --help)
    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "error: unknown option '$1' (use --help)." >&2
    exit 1
    ;;
esac

for command in dart flutter curl "$CHROMEDRIVER"; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: '$command' not found. Install it first (see --help)." >&2
    exit 1
  }
done
for file in "$ENV_FILE" "$SERVER_DIR/.env.local-soroban"; do
  [ -f "$file" ] || {
    echo "error: $file is missing. Run scripts/setup-local-soroban.sh and set up puls3_server/.env." >&2
    exit 1
  }
done

# A database of its own, created for this run and dropped after it: the
# sandbox's contracts are new on every setup, and job ids restart with them, so
# hires left by an earlier run would collide with this run's jobs.
E2E_DB=puls3_e2e
COMPOSE=(docker compose -f "$SERVER_DIR/docker-compose.yaml" --env-file "$ENV_FILE")
db() {
  "${COMPOSE[@]}" exec -T postgres_test     psql -U postgres -v ON_ERROR_STOP=1 -c "$1" >/dev/null
}

WORK="$(mktemp -d)"
SERVER_PID=""
DRIVER_PID=""
cleanup() {
  [ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null || true
  [ -z "$DRIVER_PID" ] || kill "$DRIVER_PID" 2>/dev/null || true
  db "DROP DATABASE IF EXISTS $E2E_DB WITH (FORCE)" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Creating the $E2E_DB database..."
db "DROP DATABASE IF EXISTS $E2E_DB WITH (FORCE)"
db "CREATE DATABASE $E2E_DB"

# Serverpod accepts only its own run modes, so the development mode is pointed
# at the run's database and fixed ports with its environment overrides. The
# seed (which stores the agent's key in custody) and the server share them, so
# a run never touches development data.
e2e_database_env() {
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  export SERVERPOD_DATABASE_HOST=localhost
  export SERVERPOD_DATABASE_PORT=9090
  export SERVERPOD_DATABASE_NAME="$E2E_DB"
  export SERVERPOD_DATABASE_USER=postgres
  export SERVERPOD_DATABASE_PASSWORD="${POSTGRES_TEST_PASSWORD:?set POSTGRES_TEST_PASSWORD in $ENV_FILE}"
  export SERVERPOD_REDIS_ENABLED=false
  export SERVERPOD_API_SERVER_PORT=8180
  export SERVERPOD_API_SERVER_PUBLIC_PORT=8180
  export SERVERPOD_INSIGHTS_SERVER_PORT=8181
  export SERVERPOD_WEB_SERVER_PORT=8182
}

echo "Seeding the sandbox..."
# The seed's own Serverpod has shut down when this subshell returns, so the
# server below gets the ports.
(
  e2e_database_env
  cd "$SERVER_DIR"
  dart run tool/e2e_seed_local.dart "$WORK"
)

echo "Starting the server on the test database..."
(
  e2e_database_env
  set -a
  # shellcheck disable=SC1091
  . "$WORK/server.env"
  set +a
  export SERVERPOD_APPLY_MIGRATIONS=true
  export PULS3_TRACKER_ENABLED=true
  export PULS3_TRACKER_INTERVAL_SECONDS=2
  cd "$SERVER_DIR"
  exec dart bin/main.dart --mode development
) >"$WORK/server.log" 2>&1 &
SERVER_PID=$!

deadline=$((SECONDS + TIMEOUT_SECONDS))
until curl -fsS --max-time 2 "$API_URL" >/dev/null 2>&1; do
  if ! kill -0 "$SERVER_PID" 2>/dev/null || [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: the server did not start. Its log:" >&2
    head -n 25 "$WORK/server.log" >&2
    echo "..." >&2
    tail -n 15 "$WORK/server.log" >&2
    exit 1
  fi
  sleep 2
done
echo "Server is up at $API_URL."

if ! curl -fsS --max-time 2 "http://localhost:$DRIVER_PORT/status" >/dev/null 2>&1; then
  "$CHROMEDRIVER" --port="$DRIVER_PORT" >"$WORK/chromedriver.log" 2>&1 &
  DRIVER_PID=$!
  sleep 2
fi

echo "Driving the app in headless Chrome..."
status=0
(
  cd "$FLUTTER_DIR"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/hire_flow_e2e_test.dart \
    -d web-server --release --headless --browser-name=chrome \
    --web-port=8190 \
    --dart-define-from-file="$WORK/defines.json"
) || status=$?

if [ "$status" -ne 0 ]; then
  echo "error: the browser E2E failed. Last server log lines:" >&2
  tail -n 40 "$WORK/server.log" >&2
fi
exit "$status"
