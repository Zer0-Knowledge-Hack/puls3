#!/usr/bin/env bash
# Bootstraps the local Soroban sandbox (#253).
#
# Assumes the `soroban_standalone` service from puls3_server/docker-compose.yaml
# is already running. It waits for RPC, deploys the three puls3 contracts,
# allow-lists the native SAC on the escrow and writes a git-ignored env file the
# server can source. It never reads, prints or commits a secret: the Stellar CLI
# keeps the local identity in its own key store.
#
# Usage:
#   scripts/setup-local-soroban.sh [--skip-build]
#
# Env:
#   PULS3_LOCAL_RPC_URL          default http://localhost:8000/rpc
#   PULS3_LOCAL_FRIENDBOT_URL    default http://localhost:8000/friendbot
#   PULS3_LOCAL_NETWORK          Stellar CLI network alias (default puls3-local)
#   PULS3_LOCAL_IDENTITY         Stellar CLI identity (default puls3-local-admin)
#   PULS3_LOCAL_ENV_FILE         output (default puls3_server/.env.local-soroban)
#   PULS3_LOCAL_TIMEOUT_SECONDS  RPC readiness timeout (default 120)
#   PULS3_LOCAL_SKIP_BUILD       1 uses the existing WASM instead of building
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$REPO_ROOT/contracts"
WASM_DIR="$CONTRACTS_DIR/target/wasm32v1-none/release"

RPC_URL="${PULS3_LOCAL_RPC_URL:-http://localhost:8000/rpc}"
FRIENDBOT_URL="${PULS3_LOCAL_FRIENDBOT_URL:-http://localhost:8000/friendbot}"
NETWORK="${PULS3_LOCAL_NETWORK:-puls3-local}"
IDENTITY="${PULS3_LOCAL_IDENTITY:-puls3-local-admin}"
ENV_FILE="${PULS3_LOCAL_ENV_FILE:-$REPO_ROOT/puls3_server/.env.local-soroban}"
TIMEOUT_SECONDS="${PULS3_LOCAL_TIMEOUT_SECONDS:-120}"
SKIP_BUILD="${PULS3_LOCAL_SKIP_BUILD:-0}"
# quickstart --local always uses this passphrase.
PASSPHRASE="Standalone Network ; February 2017"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h | --help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown option '$arg' (use --skip-build or --help)." >&2
      exit 1
      ;;
  esac
done

for command in stellar curl; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: '$command' not found. Install the Stellar CLI (contracts/README.md) and curl." >&2
    exit 1
  }
done

rpc_healthy() {
  curl -fsS --max-time 2 -X POST \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
    "$RPC_URL" 2>/dev/null |
    grep -q '"status"[[:space:]]*:[[:space:]]*"healthy"'
}

echo "Waiting for Soroban RPC at $RPC_URL (up to ${TIMEOUT_SECONDS}s)..."
deadline=$((SECONDS + TIMEOUT_SECONDS))
until rpc_healthy; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: RPC did not become healthy. Start it with:" >&2
    echo "  docker compose -f puls3_server/docker-compose.yaml up -d soroban_standalone" >&2
    exit 1
  fi
  sleep 2
done
echo "RPC is healthy."

# Point the CLI at this sandbox. Replacing the alias keeps a stale RPC URL or
# passphrase from a previous run out of the deploy.
stellar network rm "$NETWORK" >/dev/null 2>&1 || true
stellar network add "$NETWORK" \
  --rpc-url "$RPC_URL" \
  --network-passphrase "$PASSPHRASE" >/dev/null

if ! ADMIN="$(stellar keys address "$IDENTITY" 2>/dev/null)"; then
  echo "Generating local identity '$IDENTITY'..."
  stellar keys generate "$IDENTITY" >/dev/null
  ADMIN="$(stellar keys address "$IDENTITY")"
fi
ADMIN="$(printf '%s' "$ADMIN" | tr -d '[:space:]')"
if [ -z "$ADMIN" ]; then
  echo "error: identity '$IDENTITY' has no address." >&2
  exit 1
fi

# Friendbot starts a little after the RPC reports healthy, so retry. A refusal
# that persists is fine on a re-run: the account was funded the first time.
echo "Funding $ADMIN from the local Friendbot..."
funded=0
for _ in $(seq 1 30); do
  if curl -fsS "$FRIENDBOT_URL?addr=$ADMIN" >/dev/null 2>&1; then
    funded=1
    break
  fi
  sleep 2
done
if [ "$funded" != 1 ]; then
  echo "note: Friendbot did not fund $ADMIN (already funded or Friendbot not ready)." >&2
fi

build_if_needed() { # build_if_needed <package> <wasm>
  local package="$1" wasm="$2"
  if [ -f "$wasm" ]; then
    return 0
  fi
  if [ "$SKIP_BUILD" = 1 ]; then
    echo "error: $wasm is missing and --skip-build was given." >&2
    echo "Build it with: (cd contracts && stellar contract build --package $package)" >&2
    return 1
  fi
  echo "Building $package..."
  (cd "$CONTRACTS_DIR" && stellar contract build --package "$package")
}

deploy_contract() { # deploy_contract <wasm> [constructor args...]
  local wasm="$1"
  shift
  local id
  id="$(stellar contract deploy \
    --wasm "$wasm" \
    --source-account "$IDENTITY" \
    --network "$NETWORK" \
    -- "$@")"
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  if [ -z "$id" ]; then
    echo "error: 'stellar contract deploy' printed no contract id for $wasm." >&2
    return 1
  fi
  printf '%s' "$id"
}

IDENTITY_WASM="$WASM_DIR/identity_registry.wasm"
REPUTATION_WASM="$WASM_DIR/reputation_registry.wasm"
ESCROW_WASM="$WASM_DIR/escrow.wasm"
build_if_needed identity-registry "$IDENTITY_WASM"
build_if_needed reputation-registry "$REPUTATION_WASM"
build_if_needed escrow "$ESCROW_WASM"

echo "Deploying identity-registry..."
IDENTITY_ID="$(deploy_contract "$IDENTITY_WASM" \
  --owner "$ADMIN" \
  --name "Puls3 Local" \
  --symbol "P3LOCAL")"

echo "Deploying reputation-registry..."
REPUTATION_ID="$(deploy_contract "$REPUTATION_WASM" \
  --owner "$ADMIN" \
  --identity-registry "$IDENTITY_ID")"

# The documented constructor: zero fee, no treasury, 30-day max expiry and a
# one-day approval window (same values the testnet deploy uses).
echo "Deploying escrow..."
ESCROW_ID="$(deploy_contract "$ESCROW_WASM" \
  --admin "$ADMIN" \
  --identity-registry "$IDENTITY_ID" \
  --fee-bps 0 \
  --max-expiry 2592000 \
  --approval-window 86400)"

# Local mode has no USDC issuer. The native SAC stands in for the payment token:
# it is a real SAC with 7 decimals, so the same stroop amounts work.
SAC_ID="$(stellar contract id asset --asset native --network "$NETWORK" | tr -d '[:space:]')"
if [ -z "$SAC_ID" ]; then
  echo "error: could not derive the native SAC id." >&2
  exit 1
fi

# The id is only derived above: a fresh network has no native SAC instance, so
# `fund` cannot move XLM until it is deployed. Deploying twice is harmless.
echo "Deploying the native SAC..."
if ! stellar contract asset deploy   --asset native   --source-account "$IDENTITY"   --network "$NETWORK" >/dev/null 2>&1; then
  echo "note: native SAC deploy did not succeed (already deployed?)." >&2
fi

echo "Allow-listing the native SAC on the escrow..."
stellar contract invoke \
  --id "$ESCROW_ID" \
  --source-account "$IDENTITY" \
  --network "$NETWORK" \
  -- set_token_allowed \
  --caller "$ADMIN" \
  --token "$SAC_ID" \
  --allowed true >/dev/null

allowed="$(stellar contract invoke \
  --id "$ESCROW_ID" \
  --source-account "$IDENTITY" \
  --network "$NETWORK" \
  --send=no \
  -- is_token_allowed \
  --token "$SAC_ID")"
if ! printf '%s' "$allowed" | grep -q 'true'; then
  echo "error: escrow does not report the native SAC as allowed (got '$allowed')." >&2
  exit 1
fi

mkdir -p "$(dirname "$ENV_FILE")"
TMP_ENV="$(mktemp "${ENV_FILE}.XXXXXX")"
trap 'rm -f "$TMP_ENV"' EXIT
cat >"$TMP_ENV" <<EOF
# Generated by scripts/setup-local-soroban.sh (#253). Do not commit.
# Source it before starting the server:
#   set -a; . puls3_server/.env.local-soroban; set +a
PULS3_STELLAR_RPC_URL=$RPC_URL
PULS3_STELLAR_NETWORK_PASSPHRASE="$PASSPHRASE"
PULS3_STELLAR_USDC_SAC=$SAC_ID
PULS3_STELLAR_IDENTITY_REGISTRY=$IDENTITY_ID
PULS3_STELLAR_REPUTATION_REGISTRY=$REPUTATION_ID
PULS3_STELLAR_ESCROW=$ESCROW_ID
PULS3_STELLAR_SIMULATION_SOURCE=$ADMIN
STELLAR_ACCOUNT=$IDENTITY
STELLAR_NETWORK=$NETWORK
EOF
mv -f "$TMP_ENV" "$ENV_FILE"
trap - EXIT

echo
echo "Local contracts:"
echo "  identity_registry:   $IDENTITY_ID"
echo "  reputation_registry: $REPUTATION_ID"
echo "  escrow:              $ESCROW_ID"
echo "  native SAC:          $SAC_ID"
echo "  admin:               $ADMIN"
echo
echo "Wrote $ENV_FILE"
echo "Load it with: set -a; . ${ENV_FILE#"$REPO_ROOT"/}; set +a"
