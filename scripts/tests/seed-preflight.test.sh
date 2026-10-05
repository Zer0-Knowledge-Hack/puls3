#!/usr/bin/env bash
# Offline regression tests for scripts/seed-demo-agents.sh and the testnet guards.
# No network, no real Stellar CLI: a PATH stub stands in for `stellar`.
# Run from anywhere: bash scripts/tests/seed-preflight.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SEED_SH="$REPO_ROOT/scripts/seed-demo-agents.sh"
DEPLOY_SH="$REPO_ROOT/scripts/deploy-testnet.sh"
VALID_SEED="$REPO_ROOT/contracts/deployments/demo-agents.json"

PY=""
for candidate in python3 python; do
  if "$candidate" -c "" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  echo "error: python3 or python is required to build the test fixtures." >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

# expect_exit <label> <expected-code> <command...>
expect_exit() {
  local label="$1" want="$2"
  shift 2
  local out code
  out="$("$@" 2>&1)"
  code=$?
  LAST_OUT="$out"
  if [ "$code" -eq "$want" ]; then ok "$label"; else bad "$label" "exit $code, want $want: $out"; fi
}

# mutate <name> <python-body>: writes $WORK/<name>.json from the valid seed.
# The body edits `d` (the parsed seed) in place.
mutate() {
  "$PY" - "$VALID_SEED" "$WORK/$1.json" "$2" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
def setv(i, key, value):
    for m in d["agents"][i]["metadata"]:
        if m["key"] == key:
            m["value"] = value
            return
    d["agents"][i]["metadata"].append({"key": key, "value": value})
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
}

check_seed() { SEED_FILE="$1" bash "$SEED_SH" --check; }

echo "# --check validation"
expect_exit "valid seed passes --check" 0 check_seed "$VALID_SEED"

reject() { # reject <name> <python-body>
  mutate "$1" "$2"
  expect_exit "rejects $1" 1 check_seed "$WORK/$1.json"
}
reject skills-not-kebab 'setv(0, "skills", json.dumps(["Not Kebab"]))'
reject skills-empty 'setv(0, "skills", "[]")'
reject skills-six 'setv(0, "skills", json.dumps(["a","b","c","d","e","f"]))'
reject skills-not-array 'setv(0, "skills", "monitoring")'
reject price-zero 'setv(0, "priceUsdcStroops", "0")'
reject price-decimal 'setv(0, "priceUsdcStroops", "1.5")'
reject price-over-2pow53 'setv(0, "priceUsdcStroops", "9007199254740992")'
reject name-too-short 'setv(0, "name", "ab")'
reject name-too-long 'setv(0, "name", "x" * 49)'
reject description-too-short 'setv(0, "description", "short")'
reject description-too-long 'setv(0, "description", "x" * 281)'
reject too-few-agents 'd["agents"] = d["agents"][:5]'
reject too-many-agents 'd["agents"] = d["agents"] + [dict(d["agents"][0], uri="puls3://demo/extra-%d" % i) for i in range(2)]'
reject duplicate-uri 'd["agents"][1]["uri"] = d["agents"][0]["uri"]'
reject legacy-price-key 'setv(0, "price", "5000000")'
reject max-metadata-keys 'd["agents"][0]["metadata"] += [{"key": "k%d" % i, "value": "v"} for i in range(95)]'

echo "# node validator branch"
expect_exit "node branch: valid seed passes" 0 env SEED_JSON_RT=node SEED_FILE="$VALID_SEED" bash "$SEED_SH" --check
expect_exit "node branch: rejects legacy price key" 1 env SEED_JSON_RT=node SEED_FILE="$WORK/legacy-price-key.json" bash "$SEED_SH" --check
expect_exit "node branch: rejects bad skills" 1 env SEED_JSON_RT=node SEED_FILE="$WORK/skills-not-kebab.json" bash "$SEED_SH" --check
expect_exit "node branch: rejects price over 2^53-1" 1 env SEED_JSON_RT=node SEED_FILE="$WORK/price-over-2pow53.json" bash "$SEED_SH" --check

echo "# STELLAR_NETWORK guard"
expect_exit "seed script rejects non-testnet" 1 env STELLAR_NETWORK=mainnet bash "$SEED_SH" some-identity
case "$LAST_OUT" in *"only seeds 'testnet'"*) ok "seed guard message" ;; *) bad "seed guard message" "$LAST_OUT" ;; esac
expect_exit "deploy script rejects non-testnet" 1 env STELLAR_NETWORK=mainnet bash "$DEPLOY_SH" some-identity
case "$LAST_OUT" in *"only deploys to 'testnet'"*) ok "deploy guard message" ;; *) bad "deploy guard message" "$LAST_OUT" ;; esac

echo "# stale metadata detection (stubbed stellar CLI)"
STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/stellar" <<STUBEOF
#!/usr/bin/env bash
# Fake stellar CLI. Env: STUB_OWNER, STUB_DRIFT ("<agent-id>:<key>" or empty), STUB_STATE, STUB_CALLS,
# STUB_WALLET (registry wallet of every agent, "null" for none), STUB_UNSEEDED (a seed URI not yet registered),
# STUB_FAIL_BIND (non-empty makes set_agent_wallet fail).
if [ "\$1" = "keys" ]; then
  if [ "\$3" = "other-wallet" ]; then echo "GOTHERWALLET"; else echo "GCALLER"; fi
  exit 0
fi
shift
while [ "\$1" != "--" ] && [ \$# -gt 0 ]; do shift; done
shift
fn="\$1"; shift
arg() { local want="\$1"; shift; while [ \$# -gt 0 ]; do if [ "\$1" = "\$want" ]; then echo "\$2"; return; fi; shift; done; }
echo "\$fn \$*" >>"\$STUB_CALLS"
case "\$fn" in
  total_agents) echo 8 ;;
  agent_id_by_uri)
    u="\$(arg --agent-uri "\$@")"
    if [ -n "\${STUB_UNSEEDED:-}" ] && [ "\$u" = "\$STUB_UNSEEDED" ]; then echo null; else echo "\$((10#\${u##*-}))"; fi ;;
  register_full)
    u="\$(arg --agent-uri "\$@")"
    echo "https://stellar.expert/explorer/testnet/tx/\$(printf '%064x' 4096)" >&2
    echo "\$((10#\${u##*-}))" ;;
  get_agent_wallet)
    if [ "\${STUB_WALLET:-GCALLER}" = "null" ]; then echo null; else echo "\"\${STUB_WALLET:-GCALLER}\""; fi ;;
  set_agent_wallet)
    [ -z "\${STUB_FAIL_BIND:-}" ] || { echo "error: simulated bind failure" >&2; exit 1; }
    echo "https://stellar.expert/explorer/testnet/tx/\$(printf '%064x' 255)" >&2 ;;
  owner_of) echo "\"\$STUB_OWNER\"" ;;
  get_metadata)
    id="\$(arg --agent-id "\$@")"; key="\$(arg --key "\$@")"
    if [ "\$STUB_DRIFT" = "\$id:\$key" ] && ! grep -qx "\$id:\$key" "\$STUB_STATE"; then echo '"00"'; exit 0; fi
    "$PY" - "$VALID_SEED" "\$id" "\$key" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
a = d["agents"][int(sys.argv[2]) - 1]
v = [m["value"] for m in a["metadata"] if m["key"] == sys.argv[3]]
print('"%s"' % v[0].encode("utf-8").hex() if v else "null")
PYEOF
    ;;
  set_metadata) echo "\$(arg --agent-id "\$@"):\$(arg --key "\$@")" >>"\$STUB_STATE" ;;
  *) echo "stub: unexpected call \$fn" >&2; exit 9 ;;
esac
STUBEOF
chmod +x "$STUB_DIR/stellar"

run_seed() { # run_seed <owner> <drift> [flags...]
  local owner="$1" drift="$2"
  shift 2
  : >"$WORK/state"
  : >"$WORK/calls"
  PATH="$STUB_DIR:$PATH" STUB_OWNER="$owner" STUB_DRIFT="$drift" \
    STUB_STATE="$WORK/state" STUB_CALLS="$WORK/calls" bash "$SEED_SH" demo-id "$@"
}

expect_exit "in-sync registry exits 0" 0 run_seed GCALLER ""
expect_exit "stale metadata exits 3" 3 run_seed GCALLER "1:name"
case "$LAST_OUT" in *"stale"*"name"*) ok "stale report names the key" ;; *) bad "stale report names the key" "$LAST_OUT" ;; esac
if grep -q '^set_metadata' "$WORK/calls"; then bad "default mode never writes" "set_metadata called"; else ok "default mode never writes"; fi

expect_exit "--sync-metadata repairs and exits 0" 0 run_seed GCALLER "1:name" --sync-metadata
if grep -q '^set_metadata .*--key name' "$WORK/calls"; then ok "sync wrote the drifted key"; else bad "sync wrote the drifted key" "no set_metadata"; fi
if grep -q -- '--key price$' "$WORK/calls" || grep -q -- '--key price ' "$WORK/calls"; then bad "legacy price key never written" "found"; else ok "legacy price key never written"; fi

# Idempotent rerun: the stub state now holds the repaired key, so nothing is stale.
: >"$WORK/calls"
PATH="$STUB_DIR:$PATH" STUB_OWNER=GCALLER STUB_DRIFT="1:name" STUB_STATE="$WORK/state" STUB_CALLS="$WORK/calls" \
  bash "$SEED_SH" demo-id --sync-metadata >/dev/null 2>&1
code=$?
if [ "$code" -eq 0 ] && ! grep -q '^set_metadata' "$WORK/calls"; then ok "idempotent rerun exits 0 without writes"; else bad "idempotent rerun" "exit $code"; fi

expect_exit "--sync-metadata as non-owner exits 1" 1 run_seed GSOMEONEELSE "1:name" --sync-metadata
if grep -q '^set_metadata' "$WORK/calls"; then bad "non-owner never writes" "set_metadata called"; else ok "non-owner never writes"; fi

echo "# agent wallet binding (D4)"
wallet_calls() { grep -c '^set_agent_wallet' "$WORK/calls"; }

expect_exit "wallet already bound to the owner exits 0" 0 run_seed GCALLER ""
if [ "$(wallet_calls)" -eq 0 ]; then ok "bound wallet never calls set_agent_wallet"; else bad "bound wallet never calls set_agent_wallet" "$(wallet_calls) calls"; fi
case "$LAST_OUT" in *"wallet: agent 1 already bound"*) ok "bound wallet is reported" ;; *) bad "bound wallet is reported" "$LAST_OUT" ;; esac

STUB_WALLET=null expect_exit "missing wallet exits 0" 0 run_seed GCALLER ""
if [ "$(wallet_calls)" -eq 8 ]; then ok "missing wallet binds all 8 agents"; else bad "missing wallet binds all 8 agents" "$(wallet_calls) calls"; fi
if grep -q '^set_agent_wallet --caller GCALLER --agent-id 8 --new-wallet GCALLER' "$WORK/calls"; then ok "bind passes caller, agent id and wallet"; else bad "bind arguments" "$(grep '^set_agent_wallet' "$WORK/calls" | tail -1)"; fi
case "$LAST_OUT" in *"wallet: agent 1 bound to GCALLER"*"$(printf '%064x' 255)"*) ok "bind logs agent id and tx hash" ;; *) bad "bind logs agent id and tx hash" "$LAST_OUT" ;; esac

STUB_WALLET=GSOMEONEELSE expect_exit "different wallet exits 0" 0 run_seed GCALLER ""
if [ "$(wallet_calls)" -eq 8 ]; then ok "different wallet is rebound for all 8 agents"; else bad "different wallet is rebound" "$(wallet_calls) calls"; fi

AGENT_WALLET_ACCOUNT=other-wallet expect_exit "separate target wallet exits 0" 0 run_seed GCALLER ""
if [ "$(wallet_calls)" -eq 8 ] && grep -q -- '--new-wallet GOTHERWALLET' "$WORK/calls"; then ok "AGENT_WALLET_ACCOUNT selects the target wallet"; else bad "AGENT_WALLET_ACCOUNT target" "$(wallet_calls) calls"; fi

STUB_UNSEEDED="puls3://demo/agt-008" expect_exit "newly registered agent exits 0" 0 run_seed GCALLER ""
case "$LAST_OUT" in *"registered: 'puls3://demo/agt-008' -> agent 8"*) ok "unseeded agent is registered" ;; *) bad "unseeded agent is registered" "$LAST_OUT" ;; esac
if grep -q '^get_agent_wallet --agent-id 8' "$WORK/calls"; then ok "wallet is checked after registering"; else bad "wallet is checked after registering" "no get_agent_wallet for 8"; fi
case "$LAST_OUT" in *"$(printf '%064x' 4096)"*) ok "registration logs its tx hash" ;; *) bad "registration logs its tx hash" "$LAST_OUT" ;; esac

STUB_WALLET=null STUB_FAIL_BIND=1 expect_exit "bind failure exits 1" 1 run_seed GCALLER ""
case "$LAST_OUT" in *"binding wallet"*) ok "bind failure names the step" ;; *) bad "bind failure names the step" "$LAST_OUT" ;; esac

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
