#!/usr/bin/env bash
# Entry point of the browser E2E image (docker/e2e-browser/Dockerfile).
#
# Runs scripts/e2e-flutter-local.sh from the repository mounted at /repo
# against the compose services, reached by name on the compose network. The
# host script scripts/e2e-flutter-docker.sh starts it and mounts, over
# /repo/puls3_server/.env.local-soroban, a copy whose URLs name the sandbox
# service instead of localhost.
#
# Env (set by the host script):
#   POSTGRES_TEST_PASSWORD   password of the postgres_test service (required)
#   PULS3_E2E_DB_HOST        test PostgreSQL host (default postgres_test)
#   PULS3_E2E_DB_PORT        test PostgreSQL port (default 5432)
#
# Arguments, when given, run instead of the E2E (for example `bash`).
set -euo pipefail

REPO=/repo
SANDBOX_ENV="$REPO/puls3_server/.env.local-soroban"
RUN_DIR="$(mktemp -d)"
trap 'rm -rf "$RUN_DIR"' EXIT

[ -f "$REPO/scripts/e2e-flutter-local.sh" ] || {
  echo "error: the repository is not mounted at $REPO." >&2
  exit 1
}
[ -f "$SANDBOX_ENV" ] || {
  echo "error: $SANDBOX_ENV is missing. Run scripts/setup-local-soroban.sh on the host." >&2
  exit 1
}
: "${POSTGRES_TEST_PASSWORD:?pass POSTGRES_TEST_PASSWORD to the container}"

# The sandbox env file may come from a CRLF checkout; read a clean copy.
tr -d '\r' <"$SANDBOX_ENV" >"$RUN_DIR/sandbox.env"
(
  set -a
  # shellcheck disable=SC1091
  . "$RUN_DIR/sandbox.env"
  set +a
  : "${STELLAR_NETWORK:?STELLAR_NETWORK is missing in $SANDBOX_ENV}"
  # The seed invokes contracts with `--network "$STELLAR_NETWORK"`; the
  # container has no CLI config of its own, so the alias is defined here.
  stellar network rm "$STELLAR_NETWORK" >/dev/null 2>&1 || true
  stellar network add "$STELLAR_NETWORK" \
    --rpc-url "$PULS3_STELLAR_RPC_URL" \
    --network-passphrase "$PULS3_STELLAR_NETWORK_PASSPHRASE" >/dev/null
  echo "Stellar CLI network '$STELLAR_NETWORK' -> $PULS3_STELLAR_RPC_URL"
)

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# The env file the run script sources for the database password, written
# only inside the container and removed on exit.
(
  umask 077
  printf 'POSTGRES_TEST_PASSWORD=%q\n' "$POSTGRES_TEST_PASSWORD" >"$RUN_DIR/puls3.env"
)

# Run a CRLF-free copy: bash on Linux rejects `\r` at the end of lines. The
# copy is told where the repository is, since it no longer lives in it.
tr -d '\r' <"$REPO/scripts/e2e-flutter-local.sh" >"$RUN_DIR/e2e-flutter-local.sh"

status=0
PULS3_REPO_ROOT="$REPO" \
  PULS3_ENV_FILE="$RUN_DIR/puls3.env" \
  PULS3_E2E_DB_CLIENT=psql \
  PULS3_E2E_DB_HOST="${PULS3_E2E_DB_HOST:-postgres_test}" \
  PULS3_E2E_DB_PORT="${PULS3_E2E_DB_PORT:-5432}" \
  bash "$RUN_DIR/e2e-flutter-local.sh" || status=$?
exit "$status"
