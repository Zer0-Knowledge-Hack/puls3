#!/usr/bin/env bash
# Offline regression tests for scripts/fund-testnet-accounts.sh.
# No network, no real Stellar CLI: PATH stubs stand in for `stellar` and `curl`.
# Run from anywhere: bash scripts/tests/fund-accounts.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/fund-testnet-accounts.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

# strkey <prefix> <fill>: prefix + <fill> repeated to 56 characters, the shape of a
# Stellar strkey. Built at run time so the secret scan never sees a seed-shaped literal.
strkey() { local s="$1"; while [ "${#s}" -lt 56 ]; do s="$s$2"; done; printf '%s' "${s:0:56}"; }
# Syntactically valid public keys. Not real accounts.
KEY_RAW="$(strkey GRAW R)"
KEY_ALICE="$(strkey GALICE A)"
KEY_ISSUER="$(strkey GISSUER I)"
FAKE_SEED="$(strkey SFAKE Q)"

STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/stellar" <<STUBEOF
#!/usr/bin/env bash
# Fake stellar CLI. State lives in \$STUB_STATE_DIR, every call is appended to \$STUB_CALLS.
# Env knobs: STUB_NO_ISSUER (issuer identity does not exist until generated),
#   STUB_FAIL_STEP (change-trust | payment | generate), STUB_NOHASH_STEP (same steps),
#   STUB_TX_STYLE (signing: print "Signing transaction: <hash>" like stellar-cli 28.1).
next_hash() {
  local n=0
  [ ! -f "\$STUB_STATE_DIR/counter" ] || n="\$(cat "\$STUB_STATE_DIR/counter")"
  n=\$((n + 1))
  echo "\$n" >"\$STUB_STATE_DIR/counter"
  printf '%064x' "\$n"
}
write_hash() {
  if [ "\${STUB_FAIL_STEP:-}" = "\$1" ]; then echo "error: simulated failure in \$1" >&2; exit 1; fi
  [ "\${STUB_NOHASH_STEP:-}" != "\$1" ] || return 0
  # stellar-cli 28.1 \`tx new\` prints only the hash it signs; other commands print a link.
  if [ "\${STUB_TX_STYLE:-}" = "signing" ]; then echo "ℹ️ Signing transaction: \$(next_hash)" >&2
  else echo "🔗 https://stellar.expert/explorer/testnet/tx/\$(next_hash)" >&2; fi
}
echo "\$*" >>"\$STUB_CALLS"
case "\$1 \$2" in
  "keys address")
    case "\$3" in
      alice) echo "$KEY_ALICE" ;;
      puls3-test-usdc-issuer|my-issuer)
        if [ -n "\${STUB_NO_ISSUER:-}" ] && [ ! -f "\$STUB_STATE_DIR/issuer" ]; then exit 1; fi
        echo "$KEY_ISSUER" ;;
      *) echo "error: no identity '\$3'" >&2; exit 1 ;;
    esac ;;
  "keys generate")
    if [ "\${STUB_FAIL_STEP:-}" = "generate" ]; then echo "error: simulated failure in generate" >&2; exit 1; fi
    touch "\$STUB_STATE_DIR/issuer" ;;
  "keys "*) echo "SSECRETKEYMATERIAL" ;; # show/secret would print a key; never expected
  "tx new")
    case "\$3" in
      change-trust) write_hash change-trust ;;
      payment) write_hash payment ;;
      *) echo "stub: unexpected tx \$3" >&2; exit 9 ;;
    esac ;;
  "contract asset") echo "CTESTSAC" ;;
  "contract id") echo "CTESTSAC" ;;
  *) echo "stub: unexpected call \$*" >&2; exit 9 ;;
esac
STUBEOF
chmod +x "$STUB_DIR/stellar"

cat >"$STUB_DIR/curl" <<'STUBEOF'
#!/usr/bin/env bash
# Fake curl for Friendbot. Writes the body to -o, prints the -w status code.
# Env knobs: STUB_FRIENDBOT_EXISTING (space-separated addresses already funded),
#   STUB_FRIENDBOT_DOWN (any value: answer 502).
out="" url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    -w) shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
echo "curl $url" >>"$STUB_CALLS"
addr="${url##*addr=}"
n=0
[ ! -f "$STUB_STATE_DIR/counter" ] || n="$(cat "$STUB_STATE_DIR/counter")"
n=$((n + 1))
echo "$n" >"$STUB_STATE_DIR/counter"
if [ -n "${STUB_FRIENDBOT_DOWN:-}" ]; then
  echo "bad gateway" >"$out"; printf '502'; exit 0
fi
case " ${STUB_FRIENDBOT_EXISTING:-} " in
  *" $addr "*)
    printf '{\n  "status": 400,\n  "detail": "createAccountAlreadyExist"\n}\n' >"$out"; printf '400'; exit 0 ;;
esac
printf '{\n  "successful": true,\n  "hash": "%064x",\n  "ledger": 1\n}\n' "$n" >"$out"
printf '200'
STUBEOF
chmod +x "$STUB_DIR/curl"

fresh_env() {
  rm -rf "$WORK/state" "$WORK/calls"
  mkdir -p "$WORK/state"
  : >"$WORK/calls"
}

export PATH="$STUB_DIR:$PATH" STUB_STATE_DIR="$WORK/state" STUB_CALLS="$WORK/calls"
unset STELLAR_NETWORK FRIENDBOT_URL TEST_USDC_ISSUER_ACCOUNT TEST_USDC_CODE TEST_USDC_AMOUNT

run_fund() { bash "$SCRIPT" "$@"; }

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

H1="$(printf '%064x' 1)"
H2="$(printf '%064x' 2)"
H3="$(printf '%064x' 3)"

echo "# argument and environment guards"
fresh_env
expect_exit "no accounts exits 1" 1 run_fund
expect_out "no accounts prints usage" "Usage:"
expect_no_call "no accounts sends nothing" "."
fresh_env
expect_exit "unknown option exits 1" 1 run_fund --bogus "$KEY_RAW"
expect_out "unknown option message" "unknown option '--bogus'"
fresh_env
expect_exit "non-testnet network exits 1" 1 env STELLAR_NETWORK=mainnet bash "$SCRIPT" "$KEY_RAW"
expect_out "non-testnet message" "only funds 'testnet'"
expect_no_call "non-testnet sends nothing" "curl"
fresh_env
expect_exit "unknown identity exits 1" 1 run_fund "$KEY_RAW" ghost
expect_out "unknown identity message" "'ghost' is neither a public key nor a Stellar CLI identity"
expect_no_call "unknown identity funds nobody (preflight first)" "curl"
fresh_env
expect_exit "secret seed argument exits 1" 1 run_fund "$FAKE_SEED"
expect_out "secret seed refused" "looks like a secret key"
expect_out_not "secret seed never echoed" "$FAKE_SEED"
expect_no_call "secret seed funds nobody" "curl"
fresh_env
expect_exit "invalid amount exits 1" 1 env TEST_USDC_AMOUNT=1.5 bash "$SCRIPT" "$KEY_RAW"
expect_out "invalid amount message" "TEST_USDC_AMOUNT"
expect_no_call "invalid amount funds nobody" "curl"
fresh_env
expect_exit "issuer as recipient exits 1" 1 run_fund puls3-test-usdc-issuer
expect_out "issuer as recipient message" "issuer"
expect_no_call "issuer as recipient sends no payment" "tx new payment"

echo "# XLM only"
fresh_env
expect_exit "xlm-only raw key exits 0" 0 run_fund --xlm-only "$KEY_RAW"
expect_call "calls Friendbot with the address" "curl https://friendbot.stellar.org/?addr=$KEY_RAW"
expect_out "prints the Friendbot tx hash" "xlm   $KEY_RAW tx $H1"
expect_no_call "xlm-only sends no asset payment" "tx new payment"
expect_no_call "xlm-only adds no trustline" "change-trust"
fresh_env
expect_exit "custom Friendbot URL exits 0" 0 env FRIENDBOT_URL=http://localhost:8000/friendbot bash "$SCRIPT" --xlm-only "$KEY_RAW"
expect_call "uses FRIENDBOT_URL" "curl http://localhost:8000/friendbot?addr=$KEY_RAW"
fresh_env
expect_exit "already funded account exits 0" 0 env STUB_FRIENDBOT_EXISTING="$KEY_RAW" bash "$SCRIPT" --xlm-only "$KEY_RAW"
expect_out "already funded is reported" "xlm   $KEY_RAW already funded"
fresh_env
expect_exit "Friendbot down exits 1" 1 env STUB_FRIENDBOT_DOWN=1 bash "$SCRIPT" --xlm-only "$KEY_RAW"
expect_out "Friendbot failure names the status" "HTTP 502"

echo "# XLM and test USDC"
fresh_env
expect_exit "identity account exits 0" 0 run_fund alice
expect_call "Friendbot gets the identity's address" "curl https://friendbot.stellar.org/?addr=$KEY_ALICE"
expect_call "deploys the test asset SAC" "contract asset deploy --asset PUSDC:$KEY_ISSUER"
expect_call "trustline signed by the recipient identity" "tx new change-trust --source-account alice --line PUSDC:$KEY_ISSUER"
expect_call "issuer pays the default amount" "tx new payment --source-account puls3-test-usdc-issuer --destination $KEY_ALICE --asset PUSDC:$KEY_ISSUER --amount 1000000000"
expect_out "prints the SAC id" "CTESTSAC"
expect_out "prints the trustline tx hash" "trust $KEY_ALICE tx $H2"
expect_out "prints the payment tx hash" "usdc  $KEY_ALICE tx $H3"
expect_no_call "never reads key material" "^keys \(show\|secret\)"
fresh_env
expect_exit "stellar-cli 28.1 output (signing hash only) exits 0" 0 env STUB_TX_STYLE=signing bash "$SCRIPT" alice
expect_out "trustline hash from the signing line" "trust $KEY_ALICE tx $H2"
expect_out "payment hash from the signing line" "usdc  $KEY_ALICE tx $H3"
fresh_env
expect_exit "custom asset and amount exit 0" 0 env TEST_USDC_ISSUER_ACCOUNT=my-issuer TEST_USDC_CODE=TUSDC TEST_USDC_AMOUNT=5000000 bash "$SCRIPT" alice
expect_call "custom issuer and code" "tx new payment --source-account my-issuer --destination $KEY_ALICE --asset TUSDC:$KEY_ISSUER --amount 5000000"
fresh_env
expect_exit "missing issuer is created" 0 env STUB_NO_ISSUER=1 bash "$SCRIPT" alice
expect_call "issuer generated and funded on testnet" "keys generate puls3-test-usdc-issuer --fund --network testnet"
fresh_env
expect_exit "issuer creation failure exits 1" 1 env STUB_NO_ISSUER=1 STUB_FAIL_STEP=generate bash "$SCRIPT" alice
expect_no_call "no payment without an issuer" "tx new payment"
fresh_env
expect_exit "raw key gets USDC when it already trusts the asset" 0 run_fund "$KEY_RAW"
expect_no_call "raw key: no trustline attempt (needs the account's key)" "change-trust"
expect_call "raw key: payment sent" "tx new payment --source-account puls3-test-usdc-issuer --destination $KEY_RAW"
fresh_env
expect_exit "raw key without trustline exits 1" 1 env STUB_FAIL_STEP=payment bash "$SCRIPT" "$KEY_RAW"
expect_out "raw key failure explains the trustline" "change-trust --source-account <identity-of-$KEY_RAW> --line PUSDC:$KEY_ISSUER"
fresh_env
expect_exit "trustline failure exits 1" 1 env STUB_FAIL_STEP=change-trust bash "$SCRIPT" alice
expect_no_call "no payment after a failed trustline" "tx new payment"
fresh_env
expect_exit "payment without tx hash exits 1" 1 env STUB_NOHASH_STEP=payment bash "$SCRIPT" alice
expect_out_not "no success line without a hash" "usdc  $KEY_ALICE tx"
fresh_env
expect_exit "one failure still funds the others, exits 1" 1 env STUB_FRIENDBOT_DOWN=1 bash "$SCRIPT" --xlm-only "$KEY_RAW" alice
expect_call "second account still attempted" "curl https://friendbot.stellar.org/?addr=$KEY_ALICE"
expect_out "failure summary" "failed: 2"

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
