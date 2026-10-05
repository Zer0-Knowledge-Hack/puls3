#!/usr/bin/env bash
# Seeds demo agents (#15) into the deployed Identity Registry on Stellar testnet.
# Idempotent: URIs already present (agent_id_by_uri) are skipped, never duplicated.
# Re-running is safe; it only registers URIs that are still missing.
#
# Usage:
#   scripts/seed-demo-agents.sh [--check] [--sync-metadata] [<stellar-identity>]
#
# The identity comes from the first positional argument or $STELLAR_ACCOUNT and
# becomes the owner of every newly registered demo agent.
#
#   --check          Validate the seed file offline and exit. Needs no identity,
#                    no stellar CLI and no network.
#   --sync-metadata  Repair registered agents whose on-chain metadata drifted from
#                    the seed file (owner only). Without it, drift is only reported.
#
# Env: SEED_FILE overrides the seed file (used by tests).
#
# Exit codes: 0 ok; 1 error, invalid seed, or caller is not the agent owner;
#             3 stale on-chain metadata found and --sync-metadata was not given.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENTS_DIR="$REPO_ROOT/contracts/deployments"
RECORD_FILE="$DEPLOYMENTS_DIR/testnet.json"
SEED_FILE="${SEED_FILE:-$DEPLOYMENTS_DIR/demo-agents.json}"

CHECK_ONLY=0
SYNC_METADATA=0
POSITIONAL=""
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --sync-metadata) SYNC_METADATA=1 ;;
    -*)
      echo "error: unknown option '$arg'." >&2
      exit 1
      ;;
    *) [ -n "$POSITIONAL" ] || POSITIONAL="$arg" ;;
  esac
done

NETWORK="${STELLAR_NETWORK:-testnet}"
if [ "$NETWORK" != "testnet" ]; then
  echo "error: this script only seeds 'testnet' (got '$NETWORK')." >&2
  echo "Unset STELLAR_NETWORK or set it to 'testnet'." >&2
  exit 1
fi

if [ ! -f "$SEED_FILE" ]; then
  echo "error: required file not found: $SEED_FILE" >&2
  exit 1
fi

# Check that the interpreter really runs: on Windows, `python3` can be a
# Microsoft Store alias that exists on PATH but only prints an install prompt.
# SEED_JSON_RT=node forces the node branch (used by tests).
JSON_RT=""
for candidate in python3 python; do
  [ "${SEED_JSON_RT:-}" != "node" ] || break
  if "$candidate" -c "" >/dev/null 2>&1; then
    JSON_RT="python"
    PY="$candidate"
    break
  fi
done
if [ -n "$JSON_RT" ]; then
  :
elif command -v node >/dev/null 2>&1; then
  JSON_RT="node"
else
  echo "error: neither 'python3' nor 'node' found; one is required to parse $SEED_FILE." >&2
  exit 1
fi

# Validates seed file $1 offline. Prints one error per line to stderr, exits non-zero if invalid.
# Rules: 6-8 agents; unique non-empty URIs; per-agent unique keys with the legacy
# "price" key rejected; name 3-48, description 10-280, skills a JSON array of 1-5
# kebab-case ids, priceUsdcStroops a positive decimal integer string <= 2^53-1;
# key <= 64 chars, value <= 4096 UTF-8 bytes; distinct keys + 2 <= 100
# (the contract's MAX_METADATA_KEYS, leaving room for agentWallet and one spare).
validate_seed() {
  if [ "$JSON_RT" = "python" ]; then
    "$PY" - "$1" <<'PYEOF'
import json, re, sys
errors = []
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    agents = d["agents"]
    assert isinstance(agents, list)
except Exception as e:
    print("error: seed file is not valid JSON with an 'agents' array: %s" % e, file=sys.stderr)
    sys.exit(1)
kebab = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
if not 6 <= len(agents) <= 8:
    errors.append("expected 6-8 agents, found %d" % len(agents))
seen = set()
for i, a in enumerate(agents):
    uri = a.get("uri") if isinstance(a, dict) else None
    tag = "agent #%d (%s)" % (i + 1, uri)
    if not isinstance(uri, str) or not uri:
        errors.append("agent #%d: uri must be a non-empty string" % (i + 1))
        continue
    if uri in seen:
        errors.append("%s: duplicate uri" % tag)
    seen.add(uri)
    meta = a.get("metadata")
    if not isinstance(meta, list):
        errors.append("%s: metadata must be an array" % tag)
        continue
    kv = {}
    for m in meta:
        k, v = (m.get("key"), m.get("value")) if isinstance(m, dict) else (None, None)
        if not isinstance(k, str) or not k or not isinstance(v, str):
            errors.append("%s: every metadata entry needs a string key and a string value" % tag)
            continue
        if k in kv:
            errors.append("%s: duplicate metadata key '%s'" % (tag, k))
        if len(k) > 64:
            errors.append("%s: key '%s' is longer than 64 characters" % (tag, k))
        if len(v.encode("utf-8")) > 4096:
            errors.append("%s: value of '%s' is longer than 4096 bytes" % (tag, k))
        kv[k] = v
    if "price" in kv:
        errors.append("%s: legacy key 'price' is deprecated; use priceUsdcStroops" % tag)
    for req in ("id", "name", "description", "skills", "priceUsdcStroops"):
        if req not in kv:
            errors.append("%s: missing metadata key '%s'" % (tag, req))
    if "name" in kv and not 3 <= len(kv["name"]) <= 48:
        errors.append("%s: name must be 3-48 characters" % tag)
    if "description" in kv and not 10 <= len(kv["description"]) <= 280:
        errors.append("%s: description must be 10-280 characters" % tag)
    if "priceUsdcStroops" in kv:
        p = kv["priceUsdcStroops"]
        if not re.match(r"^[1-9][0-9]*$", p) or int(p) > 2**53 - 1:
            errors.append("%s: priceUsdcStroops must be a positive integer string <= 2^53-1" % tag)
    if "skills" in kv:
        try:
            sk = json.loads(kv["skills"])
            good = isinstance(sk, list) and 1 <= len(sk) <= 5 and all(isinstance(x, str) and kebab.match(x) for x in sk)
        except ValueError:
            good = False
        if not good:
            errors.append("%s: skills must be a JSON array of 1-5 kebab-case ids" % tag)
    if len(kv) + 2 > 100:
        errors.append("%s: %d distinct metadata keys + 2 exceeds MAX_METADATA_KEYS (100)" % (tag, len(kv)))
for e in errors:
    print("error: " + e, file=sys.stderr)
sys.exit(1 if errors else 0)
PYEOF
  else
    node - "$1" <<'JSEOF'
const fs = require('fs');
const errors = [];
let agents;
try {
  agents = JSON.parse(fs.readFileSync(process.argv[process.argv.length - 1], 'utf8')).agents;
  if (!Array.isArray(agents)) throw new Error('agents is not an array');
} catch (e) {
  console.error("error: seed file is not valid JSON with an 'agents' array: " + e.message);
  process.exit(1);
}
const kebab = /^[a-z0-9]+(-[a-z0-9]+)*$/;
if (agents.length < 6 || agents.length > 8) errors.push('expected 6-8 agents, found ' + agents.length);
const seen = new Set();
agents.forEach((a, i) => {
  const uri = a && a.uri;
  const tag = 'agent #' + (i + 1) + ' (' + uri + ')';
  if (typeof uri !== 'string' || !uri) { errors.push('agent #' + (i + 1) + ': uri must be a non-empty string'); return; }
  if (seen.has(uri)) errors.push(tag + ': duplicate uri');
  seen.add(uri);
  if (!Array.isArray(a.metadata)) { errors.push(tag + ': metadata must be an array'); return; }
  const kv = new Map();
  for (const m of a.metadata) {
    const k = m && m.key, v = m && m.value;
    if (typeof k !== 'string' || !k || typeof v !== 'string') { errors.push(tag + ': every metadata entry needs a string key and a string value'); continue; }
    if (kv.has(k)) errors.push(tag + ": duplicate metadata key '" + k + "'");
    if (k.length > 64) errors.push(tag + ": key '" + k + "' is longer than 64 characters");
    if (Buffer.byteLength(v, 'utf8') > 4096) errors.push(tag + ": value of '" + k + "' is longer than 4096 bytes");
    kv.set(k, v);
  }
  if (kv.has('price')) errors.push(tag + ": legacy key 'price' is deprecated; use priceUsdcStroops");
  for (const req of ['id', 'name', 'description', 'skills', 'priceUsdcStroops']) {
    if (!kv.has(req)) errors.push(tag + ": missing metadata key '" + req + "'");
  }
  if (kv.has('name') && (kv.get('name').length < 3 || kv.get('name').length > 48)) errors.push(tag + ': name must be 3-48 characters');
  if (kv.has('description') && (kv.get('description').length < 10 || kv.get('description').length > 280)) errors.push(tag + ': description must be 10-280 characters');
  if (kv.has('priceUsdcStroops')) {
    const p = kv.get('priceUsdcStroops');
    if (!/^[1-9][0-9]*$/.test(p) || BigInt(p) > 9007199254740991n) errors.push(tag + ': priceUsdcStroops must be a positive integer string <= 2^53-1');
  }
  if (kv.has('skills')) {
    let good = false;
    try {
      const sk = JSON.parse(kv.get('skills'));
      good = Array.isArray(sk) && sk.length >= 1 && sk.length <= 5 && sk.every((x) => typeof x === 'string' && kebab.test(x));
    } catch (e) { good = false; }
    if (!good) errors.push(tag + ': skills must be a JSON array of 1-5 kebab-case ids');
  }
  if (kv.size + 2 > 100) errors.push(tag + ': ' + kv.size + ' distinct metadata keys + 2 exceeds MAX_METADATA_KEYS (100)');
});
errors.forEach((e) => console.error('error: ' + e));
process.exit(errors.length ? 1 : 0);
JSEOF
  fi
}

if ! validate_seed "$SEED_FILE"; then
  echo "error: seed file $SEED_FILE failed validation." >&2
  exit 1
fi
if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "ok: seed file $SEED_FILE is valid."
  exit 0
fi

IDENTITY="${POSITIONAL:-${STELLAR_ACCOUNT:-}}"
if [ -z "$IDENTITY" ]; then
  echo "error: seed identity is missing." >&2
  echo "Provide it as the first argument or set STELLAR_ACCOUNT to a Stellar CLI identity." >&2
  echo "Example: scripts/seed-demo-agents.sh my-testnet-key" >&2
  exit 1
fi

if [ ! -f "$RECORD_FILE" ]; then
  echo "error: required file not found: $RECORD_FILE" >&2
  exit 1
fi

command -v stellar >/dev/null 2>&1 || {
  echo "error: 'stellar' CLI not found. Install it first (see contracts/README.md Prerequisites)." >&2
  exit 1
}

# Prints one seed URI per line from seed file $1.
seed_uris() {
  if [ "$JSON_RT" = "python" ]; then
    "$PY" -c "import json,sys;print('\n'.join(a['uri'] for a in json.load(open(sys.argv[1]))['agents']))" "$1"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log(d.agents.map(a=>a.uri).join('\n'))" "$1"
  fi
}

# Prints the metadata JSON array for the agent with URI $2 in seed file $1.
# Values are UTF-8 text in the seed file; the contract takes Bytes, which the CLI reads as hex.
seed_metadata() {
  if [ "$JSON_RT" = "python" ]; then
    "$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps([{'key':m['key'],'value':m['value'].encode('utf-8').hex()} for m in [a for a in d['agents'] if a['uri']==sys.argv[2]][0].get('metadata',[])]))" "$1" "$2"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log(JSON.stringify((d.agents.find(a=>a.uri===process.argv[2]).metadata||[]).map(m=>({key:m.key,value:Buffer.from(m.value,'utf8').toString('hex')}))))" "$1" "$2"
  fi
}

# Prints "key<TAB>hex" lines (hex of the UTF-8 seed value) for the agent with URI $2 in seed file $1.
seed_key_hexes() {
  seed_metadata "$1" "$2" | tr -d '\r' | if [ "$JSON_RT" = "python" ]; then
    "$PY" -c "import json,sys;[print(m['key']+'\t'+m['value']) for m in json.load(sys.stdin)]"
  else
    node -e "JSON.parse(require('fs').readFileSync(0,'utf8')).forEach(m=>console.log(m.key+'\t'+m.value))"
  fi
}

record_contract_id() {
  if [ "$JSON_RT" = "python" ]; then
    "$PY" -c "import json,sys;print(json.load(open(sys.argv[1])).get('identity_registry',{}).get('contract_id',''))" "$1"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log((d.identity_registry||{}).contract_id||'')" "$1"
  fi
}

record_network() {
  if [ "$JSON_RT" = "python" ]; then
    "$PY" -c "import json,sys;print(json.load(open(sys.argv[1])).get('network',''))" "$1"
  else
    node -e "const fs=require('fs');const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));console.log(d.network||'')" "$1"
  fi
}

RECORD_NETWORK="$(record_network "$RECORD_FILE")"
if [ "$RECORD_NETWORK" != "testnet" ]; then
  echo "error: $RECORD_FILE records network '$RECORD_NETWORK', not 'testnet'." >&2
  echo "Re-run scripts/deploy-testnet.sh to produce a testnet deployment record." >&2
  exit 1
fi

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
    -- "$@" </dev/null
}

ERR_LOG="$(mktemp)"
# The per-URI loop runs in a pipeline subshell, so drift is collected in a file.
STALE_LOG="$(mktemp)"
trap 'rm -f "$ERR_LOG" "$STALE_LOG"' EXIT

# Strips quotes and whitespace from a CLI result; Bytes come back as a quoted hex string.
clean() { printf '%s' "$1" | tr -d '"[:space:]'; }

# Compares on-chain metadata of agent $1 (seed URI $2) with the seed. Drift is logged to
# STALE_LOG; with --sync-metadata it is repaired instead (owner only, else exit 1).
# Only seed keys are touched: the deprecated legacy "price" key is never written.
reconcile_agent() {
  local agent_id="$1" uri="$2" owner key hex actual
  if [ "$SYNC_METADATA" -eq 1 ]; then
    owner="$(clean "$(invoke owner_of --token-id "$agent_id" || true)")"
    if [ "$owner" != "$CALLER" ]; then
      echo "error: $CALLER does not own agent $agent_id ('$uri'); --sync-metadata is owner only." >&2
      exit 1
    fi
  fi
  while IFS=$'\t' read -r key hex; do
    [ -n "$key" ] || continue
    actual="$(clean "$(invoke get_metadata --agent-id "$agent_id" --key "$key" || true)" | tr 'A-F' 'a-f')"
    [ "$actual" != "$hex" ] || continue
    if [ "$SYNC_METADATA" -eq 1 ]; then
      invoke set_metadata --caller "$CALLER" --agent-id "$agent_id" --key "$key" --value "$hex" >/dev/null 2>"$ERR_LOG" || {
        echo "error: syncing '$key' on agent $agent_id failed: $(cat "$ERR_LOG")" >&2
        exit 1
      }
      echo "synced: agent $agent_id key '$key'"
    else
      echo "stale: agent $agent_id ('$uri') key '$key' differs from the seed" | tee -a "$STALE_LOG"
    fi
  done < <(seed_key_hexes "$SEED_FILE" "$uri" | tr -d '\r')
}

BEFORE="$(invoke total_agents)"
echo "total_agents before: $BEFORE"
echo "Seeding demo agents into $CONTRACT_ID as $CALLER..."

seed_uris "$SEED_FILE" | tr -d '\r' | while IFS= read -r URI; do
  [ -n "$URI" ] || continue
  EXISTING="$(invoke agent_id_by_uri --agent-uri "$URI" || true)"
  if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
    echo "skip: '$URI' already registered as agent $EXISTING"
    reconcile_agent "$(clean "$EXISTING")" "$URI"
    continue
  fi
  METADATA="$(seed_metadata "$SEED_FILE" "$URI")"
  if [ "$METADATA" = "[]" ]; then
    OUTPUT="$(invoke register_with_uri --caller "$CALLER" --agent-uri "$URI" 2>"$ERR_LOG")" || {
      echo "error: registering '$URI' failed: $(cat "$ERR_LOG")" >&2
      if grep -q "UriAlreadyRegistered" "$ERR_LOG"; then
        echo "The URI was registered concurrently (agent_id_by_uri race); re-run the script." >&2
      fi
      exit 1
    }
  else
    OUTPUT="$(invoke register_full --caller "$CALLER" --agent-uri "$URI" --metadata "$METADATA" 2>"$ERR_LOG")" || {
      echo "error: registering '$URI' failed: $(cat "$ERR_LOG")" >&2
      if grep -q "UriAlreadyRegistered" "$ERR_LOG"; then
        echo "The URI was registered concurrently (agent_id_by_uri race); re-run the script." >&2
      fi
      exit 1
    }
  fi
  echo "registered: '$URI' -> agent $(echo "$OUTPUT" | tr -d '[:space:]')"
done

AFTER="$(invoke total_agents)"
echo "total_agents after: $AFTER"
if [ -s "$STALE_LOG" ]; then
  echo "error: on-chain metadata differs from the seed (see 'stale:' lines above)." >&2
  echo "Re-run with --sync-metadata as the agent owner to repair it." >&2
  exit 3
fi
echo "Done. Re-run this script any time; already-registered URIs are skipped."
