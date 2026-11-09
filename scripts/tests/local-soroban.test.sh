#!/usr/bin/env bash
# Offline regression tests for the local Soroban sandbox (#253).
# No Docker, no network and no real Stellar CLI: PATH stubs stand in for
# `stellar` and `curl`, and record how the setup script calls them.
# Run from anywhere: bash scripts/tests/local-soroban.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SETUP_SH="$REPO_ROOT/scripts/setup-local-soroban.sh"
COMPOSE_FILE="$REPO_ROOT/puls3_server/docker-compose.yaml"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

mkdir -p "$WORK/stubs"

cat >"$WORK/stubs/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >>"$STUB_LOG"
url="${!#}"
case "$url" in
  */rpc)
    [ "${STUB_RPC_HEALTHY:-1}" = 1 ] || exit 22
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"status":"healthy"}}'
    ;;
  */friendbot*)
    [ "${STUB_FRIENDBOT_FAIL:-0}" = 1 ] && exit 22
    printf '%s\n' '{}'
    ;;
  *) printf '%s\n' '{}' ;;
esac
EOF
chmod +x "$WORK/stubs/curl"

cat >"$WORK/stubs/stellar" <<'EOF'
#!/usr/bin/env bash
echo "stellar $*" >>"$STUB_LOG"
case "${1:-} ${2:-}" in
  "network ls") printf '%s\n' 'futurenet mainnet testnet puls3-local' ;;
  "network rm") exit 0 ;;
  "network add") exit 0 ;;
  "keys address") printf '%s\n' "${STUB_ADMIN:?STUB_ADMIN is required}" ;;
  "keys generate") exit 0 ;;
  "contract build") exit 0 ;;
  "contract deploy")
    case "$*" in
      *identity_registry.wasm*) printf '%s\n' 'CIDENTITY' ;;
      *reputation_registry.wasm*) printf '%s\n' 'CREPUTATION' ;;
      *escrow.wasm*) printf '%s\n' 'CESCROW' ;;
      *) printf '%s\n' 'CCONTRACT' ;;
    esac
    ;;
  "contract id") printf '%s\n' 'CSAC' ;;
  "contract invoke")
    case "$*" in
      *is_token_allowed*) printf '%s\n' 'true' ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$WORK/stubs/stellar"

admin="GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ"

# run_setup <log> <env-file> [env assignments...]
run_setup() {
  local log="$1" env_file="$2"
  shift 2
  : >"$log"
  env PATH="$WORK/stubs:$PATH" STUB_LOG="$log" STUB_ADMIN="$admin" \
    PULS3_LOCAL_ENV_FILE="$env_file" PULS3_LOCAL_TIMEOUT_SECONDS=2 "$@" \
    bash "$SETUP_SH" >"$log.out" 2>&1
}

echo "# compose service"
for needle in "soroban_standalone:" "stellar/quickstart:testing" '"8000:8000"' "--local" "getHealth"; do
  if grep -qF -- "$needle" "$COMPOSE_FILE"; then
    ok "docker-compose has $needle"
  else
    bad "docker-compose has $needle" "missing"
  fi
done

echo "# happy path"
LOG="$WORK/happy.log"
ENV_FILE="$WORK/local.env"
if run_setup "$LOG" "$ENV_FILE"; then
  ok "setup exits 0"
else
  bad "setup exits 0" "$(cat "$LOG.out")"
fi

if [ -f "$ENV_FILE" ]; then
  ok "writes the env file"
else
  bad "writes the env file" "$ENV_FILE missing"
fi

for expected in \
  "PULS3_STELLAR_RPC_URL=http://localhost:8000/rpc" \
  'PULS3_STELLAR_NETWORK_PASSPHRASE="Standalone Network ; February 2017"' \
  "PULS3_STELLAR_IDENTITY_REGISTRY=CIDENTITY" \
  "PULS3_STELLAR_REPUTATION_REGISTRY=CREPUTATION" \
  "PULS3_STELLAR_ESCROW=CESCROW" \
  "PULS3_STELLAR_USDC_SAC=CSAC" \
  "PULS3_STELLAR_SIMULATION_SOURCE=$admin" \
  "STELLAR_ACCOUNT=puls3-local-admin"; do
  if grep -qxF -- "$expected" "$ENV_FILE"; then
    ok "env has $expected"
  else
    bad "env has $expected" "$(cat "$ENV_FILE")"
  fi
done

if [ "$(grep -c 'contract deploy' "$LOG")" -eq 3 ]; then
  ok "deploys three contracts"
else
  bad "deploys three contracts" "$(grep 'contract deploy' "$LOG")"
fi

for needle in \
  "--owner $admin" \
  "--identity-registry CIDENTITY" \
  "--admin $admin" \
  "--fee-bps 0" \
  "--max-expiry 2592000" \
  "--approval-window 86400" \
  "set_token_allowed"; do
  if grep -qF -- "$needle" "$LOG"; then
    ok "deploy uses $needle"
  else
    bad "deploy uses $needle" "$(cat "$LOG")"
  fi
done

if grep -q "Friendbot did not fund" "$LOG.out"; then
  bad "a successful fund is quiet" "$(cat "$LOG.out")"
else
  ok "a successful fund is quiet"
fi

if grep -qE '\bS[A-Z2-7]{55}\b' "$ENV_FILE" "$LOG.out"; then
  bad "no secret seed in output or env" "found one"
else
  ok "no secret seed in output or env"
fi

echo "# an already-funded account is tolerated"
LOG2="$WORK/funded.log"
ENV2="$WORK/funded.env"
if run_setup "$LOG2" "$ENV2" STUB_FRIENDBOT_FAIL=1; then
  ok "a refused Friendbot re-fund still exits 0"
else
  bad "a refused Friendbot re-fund still exits 0" "$(cat "$LOG2.out")"
fi
if grep -q "Friendbot did not fund" "$LOG2.out"; then
  ok "the refused re-fund is explained"
else
  bad "the refused re-fund is explained" "$(cat "$LOG2.out")"
fi

echo "# RPC never healthy"
LOG3="$WORK/timeout.log"
ENV3="$WORK/timeout.env"
if run_setup "$LOG3" "$ENV3" STUB_RPC_HEALTHY=0; then
  bad "an unhealthy RPC exits non-zero" "exit 0"
else
  ok "an unhealthy RPC exits non-zero"
fi
if grep -q "RPC did not become healthy" "$LOG3.out"; then
  ok "the timeout explains how to start the sandbox"
else
  bad "the timeout explains how to start the sandbox" "$(cat "$LOG3.out")"
fi
if [ -e "$ENV3" ]; then
  bad "the timeout writes no env file" "$ENV3 exists"
else
  ok "the timeout writes no env file"
fi

echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
