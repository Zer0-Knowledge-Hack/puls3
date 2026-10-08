#!/usr/bin/env bash
# Deploys the Agent Escrow contract to Stellar testnet, allow-lists the USDC Stellar
# Asset Contract (SAC), and can drive one recorded test job and one direct SAC payment.
# Results are merged into contracts/deployments/testnet.json (the `escrow` and
# `direct_payment` slots only); other slots are never altered.
#
# Usage:
#   scripts/deploy-escrow-testnet.sh [--redeploy] [--test-job] [--direct-payment] [<stellar-identity>]
#
#   (no mode flag)    Build, deploy and allow-list USDC. Skips the deploy when the recorded
#                     escrow still answers and points at the recorded identity registry.
#   --redeploy        Force a new deploy (for example after a testnet reset).
#   --test-job        Run create_job -> fund -> submit -> complete once and record the four
#                     transaction hashes. Does not deploy unless --redeploy is also given.
#   --direct-payment  Pay the agent's price through the USDC SAC to a muxed address whose
#                     id is the hire id, and record the transaction hash.
#
# The identity comes from the first positional argument or $STELLAR_ACCOUNT; it is the
# escrow admin and, unless $AGENT_WALLET_ACCOUNT says otherwise, the provider wallet.
# Only Stellar CLI identity names are read: no key material is read, logged or written.
#
# Env:
#   STELLAR_ACCOUNT         deploy/admin identity (or the positional argument)
#   AGENT_WALLET_ACCOUNT    provider wallet identity (default: the deploy identity)
#   CLIENT_ACCOUNT          client/evaluator identity, required by --test-job and --direct-payment;
#                           must differ from the provider wallet
#   TEST_JOB_EXPIRY_SECONDS required by --test-job, no default; must be in (86400, 2592000]
#   TEST_JOB_AGENT          seed agent id used as provider (default: agt-001)
#   DIRECT_PAYMENT_HIRE_ID  required by --direct-payment, no default; the muxed id
#   SEED_FILE               seed file with the agents and prices (default: demo-agents.json)
#   DEPLOY_RECORD_FILE      deployment record (default: contracts/deployments/testnet.json)
#   ESCROW_WASM             prebuilt escrow wasm; when unset the script builds it
#
# Exit codes: 0 ok; 1 any error. A failed step reports itself and the hashes obtained so far.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$REPO_ROOT/contracts"
DEPLOYMENTS_DIR="$CONTRACTS_DIR/deployments"
RECORD_FILE="${DEPLOY_RECORD_FILE:-$DEPLOYMENTS_DIR/testnet.json}"
SEED_FILE="${SEED_FILE:-$DEPLOYMENTS_DIR/demo-agents.json}"

# Documented constructor values (agent-escrow-payment). Deliberately not configurable.
FEE_BPS=0
MAX_EXPIRY=2592000
APPROVAL_WINDOW=86400
# Circle testnet USDC issuer, documented in spikes/payments-poc/README.md. The SAC id is
# derived from it at run time instead of being hard-coded.
USDC_ASSET="USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"
# Fixed strings whose SHA-256 values are the on-chain deliverable and reason. Both the
# strings and the hashes are recorded so anyone can recompute them.
JOB_DESCRIPTION="puls3 testnet evidence job"
JOB_DELIVERABLE_TEXT="puls3 testnet evidence deliverable"
JOB_REASON_TEXT="puls3 testnet evidence approval"
REGISTRY_PROBE_AGENT_ID=1

REDEPLOY=0
DO_TEST_JOB=0
DO_DIRECT=0
POSITIONAL=""
for arg in "$@"; do
  case "$arg" in
    --redeploy) REDEPLOY=1 ;;
    --test-job) DO_TEST_JOB=1 ;;
    --direct-payment) DO_DIRECT=1 ;;
    -*)
      echo "error: unknown option '$arg'." >&2
      exit 1
      ;;
    *) [ -n "$POSITIONAL" ] || POSITIONAL="$arg" ;;
  esac
done
DO_DEPLOY=1
if [ "$REDEPLOY" -eq 0 ] && { [ "$DO_TEST_JOB" -eq 1 ] || [ "$DO_DIRECT" -eq 1 ]; }; then
  DO_DEPLOY=0
fi

IDENTITY="${POSITIONAL:-${STELLAR_ACCOUNT:-}}"
if [ -z "$IDENTITY" ]; then
  echo "error: deploy identity is missing." >&2
  echo "Provide it as the first argument or set STELLAR_ACCOUNT to a Stellar CLI identity." >&2
  echo "Example: scripts/deploy-escrow-testnet.sh my-testnet-key" >&2
  exit 1
fi

NETWORK="${STELLAR_NETWORK:-testnet}"
if [ "$NETWORK" != "testnet" ]; then
  echo "error: this script only deploys to 'testnet' (got '$NETWORK')." >&2
  echo "Unset STELLAR_NETWORK or set it to 'testnet'." >&2
  exit 1
fi

# Check that the interpreter really runs: on Windows, `python3` can be a
# Microsoft Store alias that exists on PATH but only prints an install prompt.
PY=""
for candidate in python3 python; do
  if "$candidate" -c "" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  echo "error: 'python3' or 'python' is required to read and write $RECORD_FILE." >&2
  exit 1
fi

if [ ! -f "$RECORD_FILE" ]; then
  echo "error: required file not found: $RECORD_FILE (run scripts/deploy-testnet.sh first)." >&2
  exit 1
fi

# rec_get <dotted.path>: prints the value at the path in the record, empty when missing or null.
rec_get() {
  "$PY" -c '
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split("."):
    if isinstance(v, list):
        v = v[int(part)] if part.isdigit() and int(part) < len(v) else None
    elif isinstance(v, dict):
        v = v.get(part)
    else:
        v = None
    if v is None:
        break
print("" if v is None else v)
' "$RECORD_FILE" "$1" | tr -d '\r'
}

# rec_set <dotted.path> <json>: merges one value into the record (read-modify-write, atomic).
rec_set() {
  local tmp
  tmp="$(mktemp "$(dirname "$RECORD_FILE")/.record.XXXXXX")"
  "$PY" -c '
import json, sys
path, value, out = sys.argv[2], json.loads(sys.argv[3]), sys.argv[4]
d = json.load(open(sys.argv[1], encoding="utf-8"))
node = d
parts = path.split(".")
for part in parts[:-1]:
    node = node.setdefault(part, {})
node[parts[-1]] = value
with open(out, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
' "$RECORD_FILE" "$1" "$2" "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$RECORD_FILE"
}

# json_str <string>: prints a JSON string literal.
json_str() { "$PY" -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }

# seed_price <uri>: prints priceUsdcStroops of the seed agent with that URI.
seed_price() {
  "$PY" -c '
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
for a in d["agents"]:
    if a["uri"] == sys.argv[2]:
        for m in a.get("metadata", []):
            if m["key"] == "priceUsdcStroops":
                print(m["value"])
' "$SEED_FILE" "$1" | tr -d '\r'
}

# Strips quotes and whitespace from a CLI result.
clean() { printf '%s' "$1" | tr -d '"[:space:]'; }

# Prints the 64-hex transaction hash found in CLI log file $1, or nothing.
tx_hash_of() { grep -oE '(tx/|[Tt]ransaction hash is )[0-9a-f]{64}' "$1" | head -n 1 | grep -oE '[0-9a-f]{64}' || true; }

REGISTRY_ID="$(rec_get identity_registry.contract_id)"
if [ -z "$REGISTRY_ID" ] || [ "$REGISTRY_ID" = "TO-FILL" ]; then
  echo "error: no identity registry contract ID in $RECORD_FILE (run scripts/deploy-testnet.sh first)." >&2
  exit 1
fi

command -v stellar >/dev/null 2>&1 || {
  echo "error: 'stellar' CLI not found. Install it first (see contracts/README.md Prerequisites)." >&2
  exit 1
}

address_of() { stellar keys address "$1" 2>/dev/null || true; }

ADMIN_ADDRESS="$(address_of "$IDENTITY")"
if [ -z "$ADMIN_ADDRESS" ]; then
  echo "error: Stellar identity '$IDENTITY' does not exist or has no address." >&2
  echo "Create and fund it first: stellar keys generate $IDENTITY --fund --network $NETWORK" >&2
  exit 1
fi
WALLET_IDENTITY="${AGENT_WALLET_ACCOUNT:-$IDENTITY}"

ERR_LOG="$(mktemp)"
trap 'rm -f "$ERR_LOG"' EXIT

# read_call <contract-id> <fn> [args...]: read-only call, simulated and never sent.
read_call() {
  local id="$1"
  shift
  stellar contract invoke --id "$id" --network "$NETWORK" --source-account "$IDENTITY" --send=no \
    -- "$@" </dev/null 2>"$ERR_LOG"
}

# write_call <contract-id> <source-identity> <fn> [args...]: sends one transaction.
# Sets WRITE_OUT to the result and WRITE_HASH to the transaction hash (empty when absent).
write_call() {
  local id="$1" source="$2"
  shift 2
  WRITE_OUT="$(stellar contract invoke --id "$id" --network "$NETWORK" --source-account "$source" \
    -- "$@" </dev/null 2>"$ERR_LOG")" || return 1
  WRITE_HASH="$(tx_hash_of "$ERR_LOG")"
}

usdc_sac() {
  local sac
  sac="$(stellar contract id asset --asset "$USDC_ASSET" --network "$NETWORK" 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -z "$sac" ]; then
    echo "error: could not derive the USDC SAC id for $USDC_ASSET." >&2
    exit 1
  fi
  printf '%s' "$sac"
}

# ---------------------------------------------------------------- deploy + allow-list
deploy_phase() {
  local wasm="${ESCROW_WASM:-}"
  if [ -z "$wasm" ]; then
    echo "Building escrow..."
    (cd "$CONTRACTS_DIR" && stellar contract build --package escrow)
    wasm="$CONTRACTS_DIR/target/wasm32v1-none/release/escrow.wasm"
  fi
  if [ ! -f "$wasm" ]; then
    echo "error: escrow wasm artifact not found at $wasm." >&2
    exit 1
  fi

  # The escrow calls agent_exists and get_agent_wallet on the registry; both must answer.
  if ! read_call "$REGISTRY_ID" agent_exists --agent-id "$REGISTRY_PROBE_AGENT_ID" >/dev/null ||
    ! read_call "$REGISTRY_ID" get_agent_wallet --agent-id "$REGISTRY_PROBE_AGENT_ID" >/dev/null; then
    echo "error: identity registry $REGISTRY_ID does not answer agent_exists/get_agent_wallet: $(cat "$ERR_LOG")" >&2
    echo "The registry needs a redeploy; that is a separate decision (it changes every agent id)." >&2
    exit 1
  fi

  local existing bound
  existing="$(rec_get escrow.contract_id)"
  if [ "$REDEPLOY" -eq 0 ] && [ -n "$existing" ] &&
    read_call "$existing" version >/dev/null 2>&1; then
    bound="$(clean "$(read_call "$existing" identity_registry || true)")"
    if [ "$bound" = "$REGISTRY_ID" ]; then
      ESCROW_ID="$existing"
      echo "skip: escrow $ESCROW_ID already deployed for registry $REGISTRY_ID (use --redeploy to force)."
      return 0
    fi
  fi

  local wasm_hash deployed_at deploy_hash
  wasm_hash="$(sha256sum "$wasm" | awk '{print $1}')"
  echo "Deploying escrow to $NETWORK as $IDENTITY ($ADMIN_ADDRESS)..."
  ESCROW_ID="$(stellar contract deploy \
    --wasm "$wasm" \
    --source-account "$IDENTITY" \
    --network "$NETWORK" \
    -- \
    --admin "$ADMIN_ADDRESS" \
    --identity-registry "$REGISTRY_ID" \
    --fee-bps "$FEE_BPS" \
    --max-expiry "$MAX_EXPIRY" \
    --approval-window "$APPROVAL_WINDOW" 2>"$ERR_LOG")" || {
    echo "error: 'stellar contract deploy' failed: $(cat "$ERR_LOG")" >&2
    exit 1
  }
  ESCROW_ID="$(clean "$ESCROW_ID")"
  if [ -z "$ESCROW_ID" ]; then
    echo "error: 'stellar contract deploy' printed no contract ID." >&2
    exit 1
  fi
  deploy_hash="$(tx_hash_of "$ERR_LOG")"
  deployed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Recorded before the getters are checked so the contract id is never lost.
  rec_set escrow "$("$PY" -c '
import json, sys
cid, wasm_hash, tx, at, admin, registry, fee, max_exp, window = sys.argv[1:10]
print(json.dumps({
    "contract_id": cid, "wasm_hash_sha256": wasm_hash, "deploy_tx": tx or None,
    "deployed_at_utc": at,
    "constructor": {"admin": admin, "identity_registry": registry, "treasury": None,
                    "fee_bps": int(fee), "max_expiry": int(max_exp), "approval_window": int(window)},
    "allowed_tokens": [],
}))
' "$ESCROW_ID" "$wasm_hash" "$deploy_hash" "$deployed_at" "$ADMIN_ADDRESS" "$REGISTRY_ID" "$FEE_BPS" "$MAX_EXPIRY" "$APPROVAL_WINDOW")"

  echo "escrow contract id: $ESCROW_ID"
  echo "escrow wasm hash:   $wasm_hash"
  echo "  tx deploy: ${deploy_hash:-missing}"
  if [ -z "$deploy_hash" ]; then
    echo "error: the deploy printed no transaction hash; look it up on the explorer before recording it." >&2
    exit 1
  fi

  verify_getters
}

# Checks the deployed escrow answers the documented constructor values.
verify_getters() {
  local name want got
  for pair in "fee_bps:$FEE_BPS" "max_expiry:$MAX_EXPIRY" "approval_window:$APPROVAL_WINDOW" "treasury:null"; do
    name="${pair%%:*}"
    want="${pair#*:}"
    got="$(clean "$(read_call "$ESCROW_ID" "$name" || true)")"
    if [ "$got" != "$want" ]; then
      echo "error: escrow $name is '$got', expected '$want'." >&2
      exit 1
    fi
  done
}

allowlist_phase() {
  local sac allowed hash=""
  sac="$(usdc_sac)"
  allowed="$(clean "$(read_call "$ESCROW_ID" is_token_allowed --token "$sac" || true)")"
  if [ "$allowed" = "true" ]; then
    echo "skip: USDC SAC $sac already allowed."
    hash="$(rec_get escrow.allowed_tokens.0.tx)"
  else
    write_call "$ESCROW_ID" "$IDENTITY" set_token_allowed --caller "$ADMIN_ADDRESS" --token "$sac" --allowed true || {
      echo "error: step set_token_allowed failed: $(cat "$ERR_LOG")" >&2
      exit 1
    }
    hash="$WRITE_HASH"
    echo "  tx set_token_allowed: ${hash:-missing}"
    allowed="$(clean "$(read_call "$ESCROW_ID" is_token_allowed --token "$sac" || true)")"
    if [ "$allowed" != "true" ]; then
      echo "error: is_token_allowed($sac) is '$allowed' after set_token_allowed; expected true." >&2
      exit 1
    fi
  fi
  rec_set escrow.allowed_tokens "$("$PY" -c '
import json, sys
print(json.dumps([{"asset": sys.argv[1], "sac_id": sys.argv[2], "tx": sys.argv[3] or None}]))
' "$USDC_ASSET" "$sac" "$hash")"
  echo "USDC SAC $sac allowed on escrow $ESCROW_ID."
}

# ---------------------------------------------------------------- shared job inputs
# Resolves provider, client, agent and price. Fails before any transaction.
resolve_job_inputs() {
  if [ -z "${CLIENT_ACCOUNT:-}" ]; then
    echo "error: CLIENT_ACCOUNT is required (a Stellar CLI identity different from the provider wallet)." >&2
    exit 1
  fi
  PROVIDER_ADDRESS="$(address_of "$WALLET_IDENTITY")"
  CLIENT_ADDRESS="$(address_of "$CLIENT_ACCOUNT")"
  if [ -z "$PROVIDER_ADDRESS" ] || [ -z "$CLIENT_ADDRESS" ]; then
    echo "error: wallet identity '$WALLET_IDENTITY' or client identity '$CLIENT_ACCOUNT' does not exist." >&2
    exit 1
  fi
  if [ "$PROVIDER_ADDRESS" = "$CLIENT_ADDRESS" ]; then
    echo "error: CLIENT_ACCOUNT resolves to the provider wallet; the escrow rejects a client that is its own provider." >&2
    exit 1
  fi
  AGENT_URI="puls3://demo/${TEST_JOB_AGENT:-agt-001}"
  BUDGET="$(seed_price "$AGENT_URI")"
  if [ -z "$BUDGET" ]; then
    echo "error: no priceUsdcStroops for '$AGENT_URI' in $SEED_FILE." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------- test job
HASHES_LOG="$(mktemp)"
trap 'rm -f "$ERR_LOG" "$HASHES_LOG"' EXIT

fail_step() { # fail_step <step> <message>
  echo "error: step $1 $2" >&2
  if [ -s "$HASHES_LOG" ]; then
    echo "hashes so far:" >&2
    sed 's/^/  /' "$HASHES_LOG" >&2
  fi
  echo "Test job did not complete; nothing was recorded." >&2
  exit 1
}

# job_step <step> <source-identity> <fn> [args...]: one escrow transaction with its hash logged.
job_step() {
  local step="$1" source="$2"
  shift 2
  write_call "$ESCROW_ID" "$source" "$@" || fail_step "$step" "failed: $(cat "$ERR_LOG")"
  [ -n "$WRITE_HASH" ] || fail_step "$step" "produced no transaction hash"
  echo "  tx $step: $WRITE_HASH"
  echo "tx $step: $WRITE_HASH" >>"$HASHES_LOG"
}

test_job_phase() {
  local expiry="${TEST_JOB_EXPIRY_SECONDS:-}"
  if [ -z "$expiry" ]; then
    echo "error: TEST_JOB_EXPIRY_SECONDS is required (seconds from now, > $APPROVAL_WINDOW and <= $MAX_EXPIRY); there is no default." >&2
    exit 1
  fi
  case "$expiry" in
    *[!0-9]* | 0[0-9]*)
      echo "error: TEST_JOB_EXPIRY_SECONDS must be a plain positive integer (got '$expiry')." >&2
      exit 1
      ;;
  esac
  if [ "$expiry" -le "$APPROVAL_WINDOW" ] || [ "$expiry" -gt "$MAX_EXPIRY" ]; then
    echo "error: TEST_JOB_EXPIRY_SECONDS must be > $APPROVAL_WINDOW and <= $MAX_EXPIRY (got $expiry)." >&2
    exit 1
  fi
  resolve_job_inputs

  ESCROW_ID="$(rec_get escrow.contract_id)"
  if [ -z "$ESCROW_ID" ]; then
    echo "error: no escrow contract ID in $RECORD_FILE (run scripts/deploy-escrow-testnet.sh first)." >&2
    exit 1
  fi
  local sac agent_id wallet
  sac="$(usdc_sac)"
  agent_id="$(clean "$(read_call "$REGISTRY_ID" agent_id_by_uri --agent-uri "$AGENT_URI" || true)")"
  case "$agent_id" in
    '' | null | *[!0-9]*)
      echo "error: '$AGENT_URI' is not registered in $REGISTRY_ID (run scripts/seed-demo-agents.sh)." >&2
      exit 1
      ;;
  esac
  wallet="$(clean "$(read_call "$REGISTRY_ID" get_agent_wallet --agent-id "$agent_id" || true)")"
  if [ "$wallet" != "$PROVIDER_ADDRESS" ]; then
    echo "error: registry wallet of agent $agent_id is '$wallet', not the provider $PROVIDER_ADDRESS (run the seed to bind it)." >&2
    exit 1
  fi

  local deliverable reason expired_at job_id
  deliverable="$(printf '%s' "$JOB_DELIVERABLE_TEXT" | sha256sum | awk '{print $1}')"
  reason="$(printf '%s' "$JOB_REASON_TEXT" | sha256sum | awk '{print $1}')"
  expired_at=$(($(date +%s) + expiry))

  echo "Running the test job on escrow $ESCROW_ID (agent $agent_id, budget $BUDGET)..."
  job_step create_job "$CLIENT_ACCOUNT" create_job --caller "$CLIENT_ADDRESS" --provider "$PROVIDER_ADDRESS" \
    --evaluator "$CLIENT_ADDRESS" --expired-at "$expired_at" --description "$JOB_DESCRIPTION" \
    --agent-id "$agent_id" --token "$sac" --budget "$BUDGET"
  job_id="$(clean "$WRITE_OUT")"
  case "$job_id" in
    '' | *[!0-9]*) fail_step create_job "returned no numeric job id (got '$job_id')" ;;
  esac
  echo "job id: $job_id"
  job_step fund "$CLIENT_ACCOUNT" fund --caller "$CLIENT_ADDRESS" --job-id "$job_id" \
    --expected-budget "$BUDGET" --max-fee-bps "$FEE_BPS"
  job_step submit "$WALLET_IDENTITY" submit --caller "$PROVIDER_ADDRESS" --job-id "$job_id" --deliverable "$deliverable"
  job_step complete "$CLIENT_ACCOUNT" complete --caller "$CLIENT_ADDRESS" --job-id "$job_id" --reason "$reason"

  local job_state
  job_state="$(read_call "$ESCROW_ID" get_job --job-id "$job_id" || true)"
  # The CLI prints the JobState enum as its numeric discriminant (Completed = 3).
  case "$job_state" in
    *'"state":3'* | *'"state":"Completed"'*) ;;
    *) fail_step get_job "read-back is not Completed (state 3): $job_state" ;;
  esac

  rec_set escrow.test_job "$("$PY" -c '
import json, sys
a = sys.argv[1:]
txs = {}
for line in open(a[0], encoding="utf-8"):
    step, h = line.strip()[3:].split(": ")
    txs[step] = h
print(json.dumps({
    "job_id": int(a[1]), "agent_id": int(a[2]), "agent_uri": a[3], "budget": a[4],
    "state": "Completed", "client": a[5], "provider": a[6], "expired_at": int(a[7]),
    "description": a[8],
    "deliverable_text": a[9], "deliverable_sha256": a[10],
    "reason_text": a[11], "reason_sha256": a[12],
    "txs": txs,
}))
' "$HASHES_LOG" "$job_id" "$agent_id" "$AGENT_URI" "$BUDGET" "$CLIENT_ADDRESS" "$PROVIDER_ADDRESS" "$expired_at" \
    "$JOB_DESCRIPTION" "$JOB_DELIVERABLE_TEXT" "$deliverable" "$JOB_REASON_TEXT" "$reason")"
  echo "Test job completed: job $job_id is Completed on escrow $ESCROW_ID."
}

# ---------------------------------------------------------------- direct SAC payment
# Same rail as spikes/payments-poc/pay.sh: a USDC SAC transfer to the provider's muxed
# address whose muxed id is the hire id. This script only reads that spike's logic.
direct_payment_phase() {
  local hire_id="${DIRECT_PAYMENT_HIRE_ID:-}"
  case "$hire_id" in
    '' | *[!0-9]*)
      echo "error: DIRECT_PAYMENT_HIRE_ID is required and must be a non-negative integer; there is no default." >&2
      exit 1
      ;;
  esac
  resolve_job_inputs
  local sac agent_hex muxed hash
  sac="$(usdc_sac)"
  agent_hex="$(stellar strkey decode "$PROVIDER_ADDRESS" | sed -n 's/.*"public_key_ed25519": *"\([0-9a-f]*\)".*/\1/p')"
  if [ -z "$agent_hex" ]; then
    echo "error: could not decode the provider address $PROVIDER_ADDRESS." >&2
    exit 1
  fi
  muxed="$(stellar strkey encode "{\"muxed_account_ed25519\":{\"id\":$hire_id,\"ed25519\":\"$agent_hex\"}}" | tr -d '[:space:]')"
  if [ -z "$muxed" ]; then
    echo "error: could not build the muxed address for hire $hire_id." >&2
    exit 1
  fi

  echo "Paying $BUDGET stroops to $muxed (hire $hire_id) through USDC SAC $sac..."
  : >"$HASHES_LOG"
  write_call "$sac" "$CLIENT_ACCOUNT" transfer --from "$CLIENT_ADDRESS" --to "$muxed" --amount "$BUDGET" || {
    echo "error: step direct_payment failed: $(cat "$ERR_LOG")" >&2
    exit 1
  }
  hash="$WRITE_HASH"
  if [ -z "$hash" ]; then
    echo "error: step direct_payment produced no transaction hash; nothing was recorded." >&2
    exit 1
  fi
  echo "  tx direct_payment: $hash"
  rec_set direct_payment "$("$PY" -c '
import json, sys
a = sys.argv[1:]
print(json.dumps({"tx": a[0], "asset": a[1], "sac_id": a[2], "from": a[3], "to": a[4],
                  "to_muxed": a[5], "hire_id": int(a[6]), "amount": a[7]}))
' "$hash" "$USDC_ASSET" "$sac" "$CLIENT_ADDRESS" "$PROVIDER_ADDRESS" "$muxed" "$hire_id" "$BUDGET")"
  echo "Direct payment completed: hire $hire_id paid $BUDGET stroops."
}

ESCROW_ID="$(rec_get escrow.contract_id)"
if [ "$DO_DEPLOY" -eq 1 ]; then
  deploy_phase
  allowlist_phase
  echo "Escrow recorded in $RECORD_FILE"
  echo "Explorer: https://stellar.expert/explorer/${NETWORK}/contract/${ESCROW_ID}"
fi
if [ "$DO_TEST_JOB" -eq 1 ]; then test_job_phase; fi
if [ "$DO_DIRECT" -eq 1 ]; then direct_payment_phase; fi
