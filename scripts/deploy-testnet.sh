#!/usr/bin/env bash
# Builds and deploys the Identity Registry (#13) to Stellar testnet (#15).
# Writes contracts/deployments/testnet.json on success and prints the explorer URL.
#
# Usage:
#   scripts/deploy-testnet.sh [<stellar-identity>]
#
# The deploy identity comes from the first positional argument or $STELLAR_ACCOUNT.
# Reputation Registry (#14) is NOT deployed here; testnet.json reserves a null slot for it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$REPO_ROOT/contracts"
DEPLOYMENTS_DIR="$CONTRACTS_DIR/deployments"
RECORD_FILE="$DEPLOYMENTS_DIR/testnet.json"

IDENTITY="${1:-${STELLAR_ACCOUNT:-}}"
if [ -z "$IDENTITY" ]; then
  echo "error: deploy identity is missing." >&2
  echo "Provide it as the first argument or set STELLAR_ACCOUNT to a Stellar CLI identity." >&2
  echo "Example: scripts/deploy-testnet.sh my-testnet-key" >&2
  exit 1
fi

NETWORK="${STELLAR_NETWORK:-testnet}"
if [ -z "$NETWORK" ]; then
  echo "error: STELLAR_NETWORK is set but empty; unset it or set it to 'testnet'." >&2
  exit 1
fi

REGISTRY_NAME="${REGISTRY_NAME:-Puls3 Agent}"
REGISTRY_SYMBOL="${REGISTRY_SYMBOL:-P3AGENT}"

command -v stellar >/dev/null 2>&1 || {
  echo "error: 'stellar' CLI not found. Install it first (see contracts/README.md Prerequisites)." >&2
  exit 1
}

echo "Building identity-registry..."
(
  cd "$CONTRACTS_DIR"
  stellar contract build --package identity-registry
)

WASM="$CONTRACTS_DIR/target/wasm32v1-none/release/identity_registry.wasm"
if [ ! -f "$WASM" ]; then
  echo "error: expected WASM artifact not found at $WASM after build." >&2
  exit 1
fi

ADMIN_ADDRESS="$(stellar keys address "$IDENTITY" 2>/dev/null || true)"
if [ -z "$ADMIN_ADDRESS" ]; then
  echo "error: Stellar identity '$IDENTITY' does not exist or has no address." >&2
  echo "Create or fund it first: stellar keys generate $IDENTITY --network $NETWORK" >&2
  exit 1
fi

echo "Deploying identity-registry to $NETWORK as $IDENTITY ($ADMIN_ADDRESS)..."
CONTRACT_ID="$(stellar contract deploy \
  --wasm "$WASM" \
  --source-account "$IDENTITY" \
  --network "$NETWORK" \
  -- \
  --owner "$ADMIN_ADDRESS" \
  --name "$REGISTRY_NAME" \
  --symbol "$REGISTRY_SYMBOL")"
CONTRACT_ID="$(echo "$CONTRACT_ID" | tr -d '[:space:]')"
if [ -z "$CONTRACT_ID" ]; then
  echo "error: 'stellar contract deploy' printed no contract ID." >&2
  exit 1
fi

WASM_HASH="$(sha256sum "$WASM" | awk '{print $1}')"
DEPLOYED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOROBAN_SDK="$(grep -E '^soroban-sdk *= *"' "$CONTRACTS_DIR/Cargo.toml" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -z "$SOROBAN_SDK" ]; then
  echo "error: could not read soroban-sdk version from contracts/Cargo.toml." >&2
  exit 1
fi

mkdir -p "$DEPLOYMENTS_DIR"
cat > "$RECORD_FILE" <<EOF
{
  "network": "$NETWORK",
  "deployed_at_utc": "$DEPLOYED_AT",
  "deployer": "$ADMIN_ADDRESS",
  "soroban_sdk": "$SOROBAN_SDK",
  "identity_registry": {
    "contract_id": "$CONTRACT_ID",
    "wasm_hash_sha256": "$WASM_HASH",
    "constructor": {
      "owner": "$ADMIN_ADDRESS",
      "name": "$REGISTRY_NAME",
      "symbol": "$REGISTRY_SYMBOL"
    }
  },
  "reputation_registry": null
}
EOF

echo "Deployment recorded in contracts/deployments/testnet.json"
echo "Explorer: https://stellar.expert/explorer/${NETWORK}/contract/${CONTRACT_ID}"
