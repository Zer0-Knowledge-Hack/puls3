#!/usr/bin/env bash
# Runs the browser E2E of the hire flow (#256) inside a Linux container.
#
# The same journey as scripts/e2e-flutter-local.sh, with a pinned toolchain
# (docker/e2e-browser/Dockerfile: Flutter, Stellar CLI, Chrome for Testing and
# its chromedriver). On native Windows the local script cannot pass: Dart's
# Platform.environment upper-cases variable names there, so the server never
# finds SERVERPOD_PASSWORD_walletAuthSigningKey and wallet sign-in fails.
#
# The container joins the compose network and reaches soroban_standalone and
# postgres_test by name. The repository is mounted read-write, but every
# .dart_tool/, build/ and Flutter ephemeral directory, and the pub cache, live
# in named volumes, so the host's Windows artifacts are left alone.
#
# Needs:
#   docker compose -f puls3_server/docker-compose.yaml up -d \
#     soroban_standalone postgres_test redis_test
#   bash scripts/setup-local-soroban.sh
#
# Usage:
#   scripts/e2e-flutter-docker.sh
#
# Env:
#   PULS3_ENV_FILE             file with POSTGRES_TEST_PASSWORD (default puls3_server/.env)
#   PULS3_E2E_IMAGE            image (default puls3-e2e-browser:<hash of docker/e2e-browser>)
#   PULS3_E2E_REBUILD          1 rebuilds the image even when it exists
#   PULS3_E2E_DOCKER_NETWORK   network to join (default: the sandbox container's)
#   PULS3_E2E_TIMEOUT_SECONDS  server readiness timeout (default 180)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$REPO_ROOT/puls3_server"
ENV_FILE="${PULS3_ENV_FILE:-$SERVER_DIR/.env}"
SANDBOX_ENV="$SERVER_DIR/.env.local-soroban"
IMAGE_DIR="$REPO_ROOT/docker/e2e-browser"
# The tag is the hash of the image's sources (with  stripped, so a CRLF and an
# LF checkout agree): a changed Dockerfile builds a new image, an unchanged one
# is reused without exporting it again.
IMAGE_HASH="$(cat "$IMAGE_DIR/Dockerfile" "$IMAGE_DIR/entrypoint.sh" | tr -d '' |
  sha256sum | cut -c1-12)"
IMAGE="${PULS3_E2E_IMAGE:-puls3-e2e-browser:$IMAGE_HASH}"
VOLUME_PREFIX=puls3-e2e-browser

case "${1:-}" in
  -h | --help)
    sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;
  *)
    echo "error: unknown option '$1' (use --help)." >&2
    exit 1
    ;;
esac

command -v docker >/dev/null 2>&1 || {
  echo "error: 'docker' not found." >&2
  exit 1
}
docker info >/dev/null 2>&1 || {
  echo "error: Docker is not running." >&2
  exit 1
}
for file in "$ENV_FILE" "$SANDBOX_ENV"; do
  [ -f "$file" ] || {
    echo "error: $file is missing. Run scripts/setup-local-soroban.sh and set up puls3_server/.env." >&2
    exit 1
  }
done

# Paths handed to Docker on Windows (Git Bash) must be Windows paths, and Git
# Bash must not rewrite the container paths (/repo, ...) in the arguments.
host_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}
docker_raw() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker "$@"; }

COMPOSE=(docker_raw compose -f "$(host_path "$SERVER_DIR/docker-compose.yaml")"
  --env-file "$(host_path "$ENV_FILE")")
for service in soroban_standalone postgres_test; do
  [ -n "$("${COMPOSE[@]}" ps -q --status running "$service" 2>/dev/null)" ] || {
    echo "error: the $service service is not running. Start it with:" >&2
    echo "  docker compose -f puls3_server/docker-compose.yaml up -d soroban_standalone postgres_test redis_test" >&2
    exit 1
  }
done
NETWORK="${PULS3_E2E_DOCKER_NETWORK:-$(docker_raw inspect \
  -f '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{"\n"}}{{end}}' \
  "$("${COMPOSE[@]}" ps -q soroban_standalone)" | head -n 1)}"
[ -n "$NETWORK" ] || {
  echo "error: could not find the network of soroban_standalone." >&2
  exit 1
}

# Only the test database password is passed on, through the environment, so
# it never shows on a command line. A CRLF .env leaves a trailing \r.
POSTGRES_TEST_PASSWORD="$(
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  printf '%s' "${POSTGRES_TEST_PASSWORD:-}"
)"
POSTGRES_TEST_PASSWORD="${POSTGRES_TEST_PASSWORD%$'\r'}"
[ -n "$POSTGRES_TEST_PASSWORD" ] || {
  echo "error: set POSTGRES_TEST_PASSWORD in $ENV_FILE." >&2
  exit 1
}
export POSTGRES_TEST_PASSWORD

WORK="$(mktemp -d)"
# `flutter pub get` in the container rewrites this file with Linux paths; the
# host's copy is put back afterwards.
PLUGIN_FILES=(
  "$REPO_ROOT/puls3_flutter/.flutter-plugins-dependencies"
  "$REPO_ROOT/spikes/flutter-stellar-wallet/.flutter-plugins-dependencies"
)
for i in "${!PLUGIN_FILES[@]}"; do
  [ ! -f "${PLUGIN_FILES[$i]}" ] || cp -p "${PLUGIN_FILES[$i]}" "$WORK/plugins-$i"
done
cleanup() {
  for i in "${!PLUGIN_FILES[@]}"; do
    if [ -f "$WORK/plugins-$i" ]; then
      cp -p "$WORK/plugins-$i" "${PLUGIN_FILES[$i]}"
    fi
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

# The sandbox env file names localhost; inside the network it is the service.
# The copy holds public values only (URLs, passphrase, contract ids).
sed -E 's#//(localhost|127\.0\.0\.1):8000#//soroban_standalone:8000#g' \
  "$SANDBOX_ENV" >"$WORK/env.local-soroban"

if [ "${PULS3_E2E_REBUILD:-0}" = 1 ] || ! docker_raw image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE..."
  docker_raw build -t "$IMAGE" "$(host_path "$IMAGE_DIR")"
else
  echo "Reusing $IMAGE."
fi

# Linux build output of the workspace, one named volume per directory.
ARTIFACT_DIRS=(
  .dart_tool build
  puls3_domain/.dart_tool puls3_client/.dart_tool puls3_sdk/.dart_tool
  puls3_cli/.dart_tool puls3_mcp/.dart_tool
  puls3_server/.dart_tool puls3_server/build
  puls3_flutter/.dart_tool puls3_flutter/build
  puls3_flutter/linux/flutter/ephemeral puls3_flutter/windows/flutter/ephemeral
  puls3_flutter/macos/Flutter/ephemeral puls3_flutter/ios/Flutter/ephemeral
  spikes/flutter-stellar-wallet/.dart_tool
)
MOUNTS=(
  -v "$(host_path "$REPO_ROOT"):/repo"
  -v "$(host_path "$WORK/env.local-soroban"):/repo/puls3_server/.env.local-soroban:ro"
  -v "$VOLUME_PREFIX-pub-cache:/root/.pub-cache"
)
for dir in "${ARTIFACT_DIRS[@]}"; do
  MOUNTS+=(-v "$VOLUME_PREFIX-$(printf '%s' "$dir" | tr '/.' '--' | tr 'A-Z' 'a-z'):/repo/$dir")
done

echo "Running the browser E2E in $IMAGE on network $NETWORK..."
status=0
docker_raw run --rm --init --shm-size=2g \
  --network "$NETWORK" \
  -e POSTGRES_TEST_PASSWORD \
  -e PULS3_E2E_TIMEOUT_SECONDS="${PULS3_E2E_TIMEOUT_SECONDS:-180}" \
  "${MOUNTS[@]}" \
  "$IMAGE" || status=$?
exit "$status"
