#!/usr/bin/env bash
# Offline regression tests for scripts/deploy-escrow-testnet.sh.
# No network, no real Stellar CLI: a PATH stub stands in for `stellar`.
# Run from anywhere: bash scripts/tests/escrow-deploy.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/deploy-escrow-testnet.sh"
SEED_FILE="$REPO_ROOT/contracts/deployments/demo-agents.json"

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

STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/stellar" <<'STUBEOF'
#!/usr/bin/env bash
# Fake stellar CLI. State lives in $STUB_STATE_DIR, every call is appended to $STUB_CALLS.
# Env knobs: STUB_ESCROW_REGISTRY, STUB_ALLOWED, STUB_ALLOW_NOEFFECT, STUB_REG_FAIL,
#   STUB_VERSION_FAIL, STUB_AGENT_ID, STUB_WALLET, STUB_FAIL_STEP, STUB_NOHASH_STEP,
#   STUB_DEPLOY_ID, STUB_JOB_STATE, STUB_FEE_BPS.
arg() { local want="$1"; shift; while [ $# -gt 0 ]; do if [ "$1" = "$want" ]; then echo "$2"; return; fi; shift; done; }
next_hash() {
  local n=0
  [ ! -f "$STUB_STATE_DIR/counter" ] || n="$(cat "$STUB_STATE_DIR/counter")"
  n=$((n + 1))
  echo "$n" >"$STUB_STATE_DIR/counter"
  printf '%064x' "$n"
}
if [ "$1" = "keys" ]; then
  echo "keys $*" >>"$STUB_CALLS"
  if [ "$2" = "address" ]; then
    case "$3" in
      missing-id) exit 1 ;;
      *) printf 'G%s\n' "$(echo "$3" | tr 'a-z-' 'A-Z_')"; exit 0 ;;
    esac
  fi
  # `keys show` would print a secret; the script under test must never reach it.
  echo "SSECRETKEYMATERIAL"
  exit 0
fi
if [ "$1" = "strkey" ]; then
  echo "$*" >>"$STUB_CALLS"
  if [ "$2" = "decode" ]; then echo '{"public_key_ed25519": "00aa11bb"}'; else echo "MMUXEDADDRESS"; fi
  exit 0
fi
if [ "$1" = "contract" ] && [ "$2" = "build" ]; then echo "build $*" >>"$STUB_CALLS"; exit 0; fi
if [ "$1" = "contract" ] && [ "$2" = "id" ]; then echo "id $*" >>"$STUB_CALLS"; echo "CUSDCSAC"; exit 0; fi
if [ "$1" = "contract" ] && [ "$2" = "deploy" ]; then
  echo "deploy $*" >>"$STUB_CALLS"
  echo "ℹ️ Transaction hash is $(next_hash)" >&2
  echo "${STUB_DEPLOY_ID:-CESCROWNEW}"
  exit 0
fi
id="$(arg --id "$@")"
src="$(arg --source-account "$@")"
while [ "$1" != "--" ] && [ $# -gt 0 ]; do shift; done
shift
fn="$1"; shift
echo "$fn $* #id=$id #src=$src" >>"$STUB_CALLS"
write_hash() { # write_hash <step>: print the tx link on stderr unless the step is scripted to omit it
  if [ "${STUB_FAIL_STEP:-}" = "$1" ]; then echo "error: simulated failure in $1" >&2; exit 1; fi
  if [ "${STUB_NOHASH_STEP:-}" != "$1" ]; then echo "🔗 https://stellar.expert/explorer/testnet/tx/$(next_hash)" >&2; fi
}
case "$fn" in
  version) [ -z "${STUB_VERSION_FAIL:-}" ] || exit 1; echo '"0.1.0"' ;;
  identity_registry) echo "\"${STUB_ESCROW_REGISTRY:-CREGISTRYID}\"" ;;
  fee_bps) echo "${STUB_FEE_BPS:-0}" ;;
  max_expiry) echo 2592000 ;;
  approval_window) echo 86400 ;;
  treasury) echo null ;;
  agent_exists) [ -z "${STUB_REG_FAIL:-}" ] || { echo "error: no such function" >&2; exit 1; }; echo true ;;
  get_agent_wallet) [ -z "${STUB_REG_FAIL:-}" ] || { echo "error: no such function" >&2; exit 1; }; echo "\"${STUB_WALLET:-GADMIN}\"" ;;
  agent_id_by_uri) echo "${STUB_AGENT_ID:-1}" ;;
  is_token_allowed)
    if [ -f "$STUB_STATE_DIR/allowed" ] && [ -z "${STUB_ALLOW_NOEFFECT:-}" ]; then echo true
    else echo "${STUB_ALLOWED:-false}"; fi ;;
  set_token_allowed) write_hash set_token_allowed; touch "$STUB_STATE_DIR/allowed" ;;
  create_job) write_hash create_job; echo 0 ;;
  fund) write_hash fund ;;
  submit) write_hash submit ;;
  complete) write_hash complete ;;
  transfer) write_hash transfer ;;
  get_job) echo "{\"state\":${STUB_JOB_STATE:-3},\"budget\":\"5000000\"}" ;;
  *) echo "stub: unexpected call $fn" >&2; exit 9 ;;
esac
STUBEOF
chmod +x "$STUB_DIR/stellar"

# fresh_env: resets stub state, the record file and the call log.
fresh_env() {
  rm -rf "$WORK/state" "$WORK/calls" "$WORK/record.json" "$WORK/fake.wasm"
  mkdir -p "$WORK/state"
  : >"$WORK/calls"
  printf 'fake-escrow-wasm' >"$WORK/fake.wasm"
  cat >"$WORK/record.json" <<'JSON'
{
  "network": "testnet",
  "deployer": "GDEPLOYER",
  "identity_registry": { "contract_id": "CREGISTRYID", "wasm_hash_sha256": "abc" },
  "reputation_registry": null
}
JSON
}

# The stub, state, record and wasm paths are exported once; individual tests add knobs with `env`.
export PATH="$STUB_DIR:$PATH" STUB_STATE_DIR="$WORK/state" STUB_CALLS="$WORK/calls"
export DEPLOY_RECORD_FILE="$WORK/record.json" ESCROW_WASM="$WORK/fake.wasm" SEED_FILE STELLAR_ACCOUNT=admin
unset STELLAR_NETWORK

run_deploy() { bash "$SCRIPT" "$@"; }

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

calls_have() { grep -q -- "$1" "$WORK/calls"; }
expect_call() { if calls_have "$2"; then ok "$1"; else bad "$1" "no call matching '$2'"; fi; }
expect_no_call() { if calls_have "$2"; then bad "$1" "unexpected call matching '$2'"; else ok "$1"; fi; }
expect_out() { case "$LAST_OUT" in *"$2"*) ok "$1" ;; *) bad "$1" "output lacks '$2': $LAST_OUT" ;; esac; }
expect_out_not() { case "$LAST_OUT" in *"$2"*) bad "$1" "output has '$2'" ;; *) ok "$1" ;; esac; }

# json_get <file> <python-expression over d>: prints the value.
json_get() { "$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));print($2)" "$1"; }
expect_json() { # expect_json <label> <expression> <expected>
  local got
  got="$(json_get "$WORK/record.json" "$2" 2>&1 | tr -d '\r')"
  if [ "$got" = "$3" ]; then ok "$1"; else bad "$1" "got '$got', want '$3'"; fi
}

echo "# D1 prerequisites fail before any transaction"
fresh_env
expect_exit "missing identity exits 1" 1 env STELLAR_ACCOUNT= bash "$SCRIPT"
expect_out "missing identity message" "identity is missing"
expect_no_call "missing identity sends nothing" "^deploy "
fresh_env
expect_exit "unknown identity exits 1" 1 run_deploy missing-id
expect_out "unknown identity message" "does not exist"
expect_no_call "unknown identity sends nothing" "^deploy "
fresh_env
expect_exit "non-testnet network exits 1" 1 env STELLAR_NETWORK=mainnet bash "$SCRIPT"
expect_out "non-testnet message" "only deploys to 'testnet'"
expect_no_call "non-testnet sends nothing" "^deploy "
fresh_env
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));d['identity_registry']=None;json.dump(d,open(sys.argv[1],'w'))" "$WORK/record.json"
expect_exit "missing registry id exits 1" 1 run_deploy
expect_out "missing registry id message" "identity registry"
expect_no_call "missing registry id sends nothing" "^deploy "
fresh_env
rm -f "$WORK/fake.wasm"
expect_exit "missing wasm exits 1" 1 run_deploy
expect_out "missing wasm message" "wasm"
expect_no_call "missing wasm sends nothing (deploy)" "^deploy "
expect_no_call "missing wasm sends nothing (allow-list)" "^set_token_allowed "

echo "# registry preflight (task 1.1 contract)"
fresh_env
expect_exit "registry without get_agent_wallet/agent_exists exits 1" 1 env STUB_REG_FAIL=1 bash "$SCRIPT"
expect_out "preflight failure message" "registry"
expect_no_call "preflight failure sends nothing" "^deploy "
fresh_env
expect_exit "happy path exits 0" 0 run_deploy
expect_call "preflight calls agent_exists on the registry" "^agent_exists .*#id=CREGISTRYID"
expect_call "preflight calls get_agent_wallet on the registry" "^get_agent_wallet .*#id=CREGISTRYID"

echo "# D1 deploy with documented values"
expect_call "deploy passes fee_bps 0" "^deploy .*--fee-bps 0"
expect_call "deploy passes max_expiry 2592000" "^deploy .*--max-expiry 2592000"
expect_call "deploy passes approval_window 86400" "^deploy .*--approval-window 86400"
expect_call "deploy passes the registry from the record" "^deploy .*--identity-registry CREGISTRYID"
expect_call "deploy passes the admin address" "^deploy .*--admin GADMIN"
expect_no_call "deploy passes no treasury" "^deploy .*--treasury"
expect_out "prints the escrow contract id" "CESCROWNEW"
expect_out "prints the deploy tx hash" "0000000000000000000000000000000000000000000000000000000000000001"
expect_out "prints the wasm hash" "$(printf 'fake-escrow-wasm' | sha256sum | awk '{print $1}')"
expect_call "getters verified: fee_bps" "^fee_bps "
expect_call "getters verified: max_expiry" "^max_expiry "
expect_call "getters verified: approval_window" "^approval_window "
expect_call "getters verified: treasury" "^treasury "

echo "# D1 no secret leakage"
expect_no_call "never reads key material" "^keys show"
expect_out_not "no secret in output" "SSECRETKEYMATERIAL"

echo "# D2 record merge"
expect_json "escrow contract id recorded" "d['escrow']['contract_id']" "CESCROWNEW"
expect_json "escrow wasm hash recorded" "d['escrow']['wasm_hash_sha256']" "$(printf 'fake-escrow-wasm' | sha256sum | awk '{print $1}')"
expect_json "escrow deploy tx recorded" "d['escrow']['deploy_tx']" "0000000000000000000000000000000000000000000000000000000000000001"
expect_json "constructor records documented values" "(d['escrow']['constructor']['fee_bps'],d['escrow']['constructor']['max_expiry'],d['escrow']['constructor']['approval_window'],d['escrow']['constructor']['treasury'])" "(0, 2592000, 86400, None)"
expect_json "identity_registry preserved" "d['identity_registry']" "{'contract_id': 'CREGISTRYID', 'wasm_hash_sha256': 'abc'}"
expect_json "reputation_registry stays null" "d['reputation_registry']" "None"
expect_json "unrelated top-level keys preserved" "d['deployer']" "GDEPLOYER"

echo "# D2 idempotency and --redeploy"
: >"$WORK/calls"
expect_exit "re-run exits 0" 0 run_deploy
expect_no_call "re-run skips the deploy" "^deploy "
expect_out "re-run reports the skip" "skip"
expect_json "re-run keeps the escrow id" "d['escrow']['contract_id']" "CESCROWNEW"
: >"$WORK/calls"
expect_exit "registry mismatch re-run exits 0" 0 env STUB_ESCROW_REGISTRY=COTHERREGISTRY bash "$SCRIPT"
expect_call "escrow bound to another registry is redeployed" "^deploy "
: >"$WORK/calls"
expect_exit "--redeploy exits 0" 0 env STUB_DEPLOY_ID=CESCROWTWO bash "$SCRIPT" --redeploy
expect_call "--redeploy forces a deploy" "^deploy "
expect_json "--redeploy updates the slot in place" "d['escrow']['contract_id']" "CESCROWTWO"
expect_json "--redeploy leaves one escrow slot and the registry intact" "(sorted(k for k in d if k.startswith('escrow')), d['identity_registry']['contract_id'], d['reputation_registry'])" "(['escrow'], 'CREGISTRYID', None)"

echo "# D3 allow-list"
fresh_env
expect_exit "fresh deploy allow-lists" 0 run_deploy
expect_call "allow-lists the USDC SAC as admin" "^set_token_allowed .*--caller GADMIN .*--token CUSDCSAC .*--allowed true"
n="$(grep -c '^set_token_allowed ' "$WORK/calls")"
if [ "$n" -eq 1 ]; then ok "allow-lists exactly one token"; else bad "allow-lists exactly one token" "$n calls"; fi
expect_call "SAC derived from the USDC asset on testnet" "^id contract id asset --asset USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5 --network testnet"
expect_call "verifies is_token_allowed" "^is_token_allowed .*--token CUSDCSAC"
expect_json "allow-list recorded" "(d['escrow']['allowed_tokens'][0]['sac_id'], d['escrow']['allowed_tokens'][0]['asset'])" "('CUSDCSAC', 'USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5')"
fresh_env
expect_exit "already allowed exits 0" 0 env STUB_ALLOWED=true bash "$SCRIPT"
expect_no_call "already allowed skips set_token_allowed" "^set_token_allowed "
fresh_env
expect_exit "allow-list without effect exits 1" 1 env STUB_ALLOW_NOEFFECT=1 bash "$SCRIPT"
expect_out "allow-list verification failure message" "is_token_allowed"

echo "# D5 --test-job input validation (no transaction on bad input)"
# deploy first so the record holds an escrow slot
fresh_env
run_deploy >/dev/null 2>&1
test_job() { # test_job [env assignments...] -- runs --test-job with a default valid environment
  : >"$WORK/calls"
  env CLIENT_ACCOUNT=client TEST_JOB_EXPIRY_SECONDS=100000 "$@" bash "$SCRIPT" --test-job
}
expect_exit "expiry unset exits 1" 1 env -u TEST_JOB_EXPIRY_SECONDS CLIENT_ACCOUNT=client bash "$SCRIPT" --test-job
expect_out "expiry unset message" "TEST_JOB_EXPIRY_SECONDS"
expect_no_call "expiry unset sends nothing" "^create_job "
for bad_expiry in 86400 0 2592001 abc -5 1e5 ""; do
  expect_exit "expiry '$bad_expiry' rejected" 1 test_job TEST_JOB_EXPIRY_SECONDS="$bad_expiry"
  expect_no_call "expiry '$bad_expiry' sends nothing" "^create_job "
done
expect_exit "client unset exits 1" 1 env -u CLIENT_ACCOUNT TEST_JOB_EXPIRY_SECONDS=100000 bash "$SCRIPT" --test-job
expect_out "client unset message" "CLIENT_ACCOUNT"
expect_exit "client equal to provider exits 1" 1 test_job CLIENT_ACCOUNT=admin
expect_no_call "client equal to provider sends nothing" "^create_job "
expect_exit "agent not found exits 1" 1 test_job STUB_AGENT_ID=null
expect_no_call "agent not found sends nothing" "^create_job "
expect_exit "registry wallet different from provider exits 1" 1 test_job STUB_WALLET=GSOMEONEELSE
expect_out "wallet mismatch message" "wallet"
expect_no_call "wallet mismatch sends nothing" "^create_job "

echo "# D5 test job happy path"
expect_exit "expiry 86401 (lower bound + 1) accepted" 0 test_job TEST_JOB_EXPIRY_SECONDS=86401
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "expiry 2592000 (upper bound) accepted" 0 test_job TEST_JOB_EXPIRY_SECONDS=2592000
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "test job exits 0" 0 test_job
order="$(grep -oE '^(create_job|fund|submit|complete|get_job) ' "$WORK/calls" | tr -d ' ' | tr '\n' ',')"
if [ "$order" = "create_job,fund,submit,complete,get_job," ]; then ok "calls run in order create_job, fund, submit, complete, get_job"; else bad "call order" "$order"; fi
expect_call "create_job: client caller, wallet provider, client evaluator, agent 1, USDC, price budget" "^create_job .*--caller GCLIENT .*--provider GADMIN .*--evaluator GCLIENT .*--agent-id 1 .*--token CUSDCSAC .*--budget 5000000"
expect_no_call "create_job passes no hook" "^create_job .*--hook"
expect_call "create_job signed by the client" "^create_job .*#src=client"
expect_call "fund signed by the client with exact budget" "^fund .*--caller GCLIENT .*--expected-budget 5000000 .*--max-fee-bps 0 .*#src=client"
expect_call "submit signed by the provider wallet" "^submit .*--caller GADMIN .*#src=admin"
expect_call "complete signed by the evaluator" "^complete .*--caller GCLIENT .*#src=client"
exp="$(grep '^create_job ' "$WORK/calls" | sed -E 's/.*--expired-at ([0-9]+).*/\1/')"
now="$(date +%s)"
if [ -n "$exp" ] && [ "$exp" -ge $((now + 100000 - 60)) ] && [ "$exp" -le $((now + 100000 + 60)) ]; then ok "expired_at is now + TEST_JOB_EXPIRY_SECONDS"; else bad "expired_at" "got '$exp' now '$now'"; fi
expect_out "prints the job id" "job id: 0"
expect_json "job recorded as Completed" "d['escrow']['test_job']['state']" "Completed"
expect_json "job id and agent id recorded" "(d['escrow']['test_job']['job_id'], d['escrow']['test_job']['agent_id'], d['escrow']['test_job']['budget'])" "(0, 1, '5000000')"
expect_json "four distinct 64-hex tx hashes recorded" "(lambda t: (sorted(t), len(set(t.values())), all(len(v)==64 for v in t.values())))(d['escrow']['test_job']['txs'])" "(['complete', 'create_job', 'fund', 'submit'], 4, True)"
expect_json "deliverable and reason are recomputable sha256 hashes" "(lambda j, h: (j['deliverable_sha256']==h(j['deliverable_text']), j['reason_sha256']==h(j['reason_text'])))(d['escrow']['test_job'], lambda s: __import__('hashlib').sha256(s.encode()).hexdigest())" "(True, True)"
sub_hash="$(grep '^submit ' "$WORK/calls" | sed -E 's/.*--deliverable ([0-9a-f]{64}).*/\1/')"
rec_hash="$(json_get "$WORK/record.json" "d['escrow']['test_job']['deliverable_sha256']" | tr -d '\r')"
if [ -n "$sub_hash" ] && [ "$sub_hash" = "$rec_hash" ]; then ok "submit uses the recorded deliverable hash"; else bad "deliverable hash" "$sub_hash vs $rec_hash"; fi
expect_json "deploy slot untouched by the test job" "(d['escrow']['contract_id'], d['reputation_registry'])" "('CESCROWNEW', None)"

echo "# D5 failure handling"
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "missing tx hash on fund exits 1" 1 test_job STUB_NOHASH_STEP=fund
expect_out "missing hash names the step" "fund"
expect_no_call "no submit after a missing hash" "^submit "
expect_out_not "no success claim after a missing hash" "Test job completed"
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "mid-flow failure exits 1" 1 test_job STUB_FAIL_STEP=submit
expect_out "failure names the failed step" "submit"
expect_out "failure reports create_job hash so far" "tx create_job:"
expect_out "failure reports fund hash so far" "tx fund:"
expect_no_call "no complete after a failed submit" "^complete "
expect_out_not "no success claim after a failure" "Test job completed"
expect_json "failed run records no Completed job" "d['escrow'].get('test_job', {}).get('state')" "None"
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "job not Completed on read-back exits 1" 1 test_job STUB_JOB_STATE=1
expect_out_not "no success claim when state differs" "Test job completed"
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "textual Completed state is accepted" 0 test_job STUB_JOB_STATE='"Completed"'
fresh_env
expect_exit "--test-job without an escrow slot exits 1" 1 test_job
expect_out "no escrow message" "escrow"
expect_no_call "no escrow sends nothing" "^create_job "

echo "# D5 secrets in the test-job path"
fresh_env
run_deploy >/dev/null 2>&1
expect_exit "test job for the secrets check exits 0" 0 test_job
expect_no_call "test job never reads key material" "^keys show"
expect_out_not "no secret in test-job output" "SSECRETKEYMATERIAL"

echo "# 2.9 --direct-payment"
fresh_env
run_deploy >/dev/null 2>&1
direct() { # direct [env assignments...]
  : >"$WORK/calls"
  env CLIENT_ACCOUNT=client DIRECT_PAYMENT_HIRE_ID=7 "$@" bash "$SCRIPT" --direct-payment
}
expect_exit "hire id unset exits 1" 1 direct DIRECT_PAYMENT_HIRE_ID=
expect_out "hire id unset message" "DIRECT_PAYMENT_HIRE_ID"
expect_no_call "hire id unset sends nothing" "^transfer "
expect_exit "hire id non-numeric exits 1" 1 direct DIRECT_PAYMENT_HIRE_ID=abc
expect_no_call "hire id non-numeric sends nothing" "^transfer "
expect_exit "client unset exits 1" 1 direct CLIENT_ACCOUNT=
expect_no_call "client unset sends nothing" "^transfer "
expect_exit "direct payment exits 0" 0 direct
expect_call "decodes the agent wallet address" "^strkey decode GADMIN"
expect_call "transfers the agent price to the muxed address from the client" "^transfer .*--from GCLIENT .*--to MMUXEDADDRESS .*--amount 5000000 .*#id=CUSDCSAC .*#src=client"
expect_out "prints the payment tx hash" "tx direct_payment:"
expect_json "direct payment hash recorded" "(len(d['direct_payment']['tx']), d['direct_payment']['hire_id'], d['direct_payment']['sac_id'], d['direct_payment']['amount'])" "(64, 7, 'CUSDCSAC', '5000000')"
expect_json "escrow slot and registry untouched by direct payment" "(d['escrow']['contract_id'], d['identity_registry']['contract_id'], d['reputation_registry'])" "('CESCROWNEW', 'CREGISTRYID', None)"
expect_exit "direct payment without tx hash exits 1" 1 direct STUB_NOHASH_STEP=transfer
expect_out_not "no success claim without a hash" "Direct payment completed"

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
