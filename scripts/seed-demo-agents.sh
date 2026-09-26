#!/usr/bin/env bash
# Seeds demo agents (#15) into the deployed Identity Registry on Stellar testnet.
# Idempotent: URIs already present (agent_id_by_uri) are skipped, never duplicated.
# Re-running is safe; it only registers URIs that are still missing.
#
# Usage:
#   scripts/seed-demo-agents.sh [<stellar-identity>]
#
# The identity comes from the first positional argument or $STELLAR_ACCOUNT and
# becomes the owner of every newly registered demo agent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENTS_DIR="$REPO_ROOT/contracts/deployments"
RECORD_FILE="$DEPLOYMENTS_DIR/testnet.json"
SEED_FILE="$DEPLOYMENTS_DIR/demo-agents.json"

IDENTITY="${1:-${STELLAR_ACCOUNT:-}}"
if [ -z "$IDENTITY" ]; then
  echo "error: seed identity is missing." >&2
  echo "Provide it as the first argument or set STELLAR_ACCOUNT to a Stellar CLI identity." >&2
  echo "Example: scripts/seed-demo-agents.sh my-testnet-key" >&2
  exit 1
fi

NETWORK="${STELLAR_NETWORK:-testnet}"
if [ -z "$NETWORK" ]; then
  echo "error: STELLAR_NETWORK is set but empty; unset it or set it to 'testnet'." >&2
  exit 1
fi

for f in "$RECORD_FILE" "$SEED_FILE"; do
  if [ ! -f "$f" ]; then
    echo "error: required file not found: $f" >&2
    exit 1
  fi
done

command -v stellar >/dev/null 2>&1 || {
  echo "error: 'stellar' CLI not found. Install it first (see contracts/README.md Prerequisites)." >&2
  exit 1
}
if command -v python3 >/dev/null 2>&1; then
  JSON_RT="python3"
elif command -v node >/dev/null 2>&1; then
  JSON_RT="node"
else
  echo "error: neither 'python3' nor 'node' found; one is required to parse $SEED_FILE." >&2
  exit 1
fi

# Prints one seed URI per line from seed file $1.
seed_uris() {
  if [ "$JSON_RT" = "python3" ]; then
    python3 -c "import json,sys;print('\n'.join(a['uri'] for a in json.load(open(sys.argv[1]))['agents']))" "$1"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log(d.agents.map(a=>a.uri).join('\n'))" "$1"
  fi
}

# Prints the metadata JSON array for the agent with URI $2 in seed file $1.
seed_metadata() {
  if [ "$JSON_RT" = "python3" ]; then
    python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps([a for a in d['agents'] if a['uri']==sys.argv[2]][0].get('metadata',[])))" "$1" "$2"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log(JSON.stringify(d.agents.find(a=>a.uri===process.argv[2]).metadata||[]))" "$1" "$2"
  fi
}

record_contract_id() {
  if [ "$JSON_RT" = "python3" ]; then
    python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('identity_registry',{}).get('contract_id',''))" "$1"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log((d.identity_registry||{}).contract_id||'')" "$1"
  fi
}

CONTRACT_ID="$(record_contract_id "$RECORD_FILE")"
if [ -z "$CONTRACT_ID" ] || [ "$CONTRACT_ID" = "TO-FILL" ]; then
  echo "error: no deployed contract ID in $RECORD_FILE (run scripts/deploy-testnet.sh first)." >&2
  exit 1
fi

CALLER="$(stellar keys address "$IDENTITY" 2>/dev/null || true)"
if [ -z "$CALLER" ]; then
  echo "error: Stellar identity '$IDENTITY' does not exist or has no address." >&2
  exit 1
fi

invoke() {
  stellar contract invoke \
    --id "$CONTRACT_ID" \
    --network "$NETWORK" \
    --source-account "$IDENTITY" \
    -- "$@"
}

BEFORE="$(invoke -- total_agents)"
echo "total_agents before: $BEFORE"
echo "Seeding demo agents into $CONTRACT_ID as $CALLER..."

seed_uris "$SEED_FILE" | while IFS= read -r URI; do
  [ -n "$URI" ] || continue
  EXISTING="$(invoke -- agent_id_by_uri --agent-uri "$URI" || true)"
  if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
    echo "skip: '$URI' already registered as agent $EXISTING"
    continue
  fi
  METADATA="$(seed_metadata "$SEED_FILE" "$URI")"
  if [ "$METADATA" = "[]" ]; then
    OUTPUT="$(invoke -- register_with_uri --caller "$CALLER" --agent-uri "$URI" 2>&1)" || {
      echo "error: registering '$URI' failed: $OUTPUT" >&2
      if echo "$OUTPUT" | grep -q "UriAlreadyRegistered"; then
        echo "The URI was registered concurrently (agent_id_by_uri race); re-run the script." >&2
      fi
      exit 1
    }
  else
    OUTPUT="$(invoke -- register_full --caller "$CALLER" --agent-uri "$URI" --metadata "$METADATA" 2>&1)" || {
      echo "error: registering '$URI' failed: $OUTPUT" >&2
      if echo "$OUTPUT" | grep -q "UriAlreadyRegistered"; then
        echo "The URI was registered concurrently (agent_id_by_uri race); re-run the script." >&2
      fi
      exit 1
    }
  fi
  echo "registered: '$URI' -> agent $OUTPUT"
done

AFTER="$(invoke -- total_agents)"
echo "total_agents after: $AFTER"
echo "Done. Re-run this script any time; already-registered URIs are skipped."
