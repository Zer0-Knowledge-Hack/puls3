#!/usr/bin/env bash
# Offline checks that the configuration docs cover the code (#30):
#   - every environment variable read by the server, the app and the scripts is
#     listed in .env.example;
#   - every secret the code depends on is listed in docs/infra/secrets.md;
#   - the testnet values in .env.example match contracts/deployments/testnet.json;
#   - .env.example holds no secret and loads in bash and as a dart-define file.
# Run from anywhere: bash scripts/tests/env-inventory.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
ENV_EXAMPLE="$REPO_ROOT/.env.example"
SECRETS_DOC="$REPO_ROOT/docs/infra/secrets.md"
RECORD="$REPO_ROOT/contracts/deployments/testnet.json"

PY=""
for candidate in python3 python; do
  if "$candidate" -c "" >/dev/null 2>&1; then PY="$candidate"; break; fi
done
if [ -z "$PY" ]; then
  echo "error: python3 or python is required." >&2
  exit 2
fi

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

# Shell variables that look like env reads but are the scripts' own locals.
SCRIPT_LOCALS=" POSITIONAL "

# vars_read_in_code: one name per line, sorted, from Dart sources and scripts.
vars_read_in_code() {
  {
    # Dart: StellarConfig/TrackerLoopConfig read quoted PULS3_* names; the app
    # reads String.fromEnvironment('PULS3_*') (often split across lines).
    grep -rhoE "'PULS3_[A-Z0-9_]+'" \
      "$REPO_ROOT/puls3_server/lib" "$REPO_ROOT/puls3_flutter/lib" | tr -d "'"
    # Scripts: ${NAME:-default} reads of upper-case variables.
    grep -hoE '\$\{[A-Z][A-Z0-9_]*:-' "$REPO_ROOT"/scripts/*.sh |
      sed -E 's/^\$\{//; s/:-$//' |
      while read -r name; do
        case "$SCRIPT_LOCALS" in *" $name "*) ;; *) echo "$name" ;; esac
      done
  } | tr -d '\r' | sort -u
}

listed_in_env_example() { grep -qE "^(# )?$1=" "$ENV_EXAMPLE"; }

echo "# every variable read in code is in .env.example"
VARS="$(vars_read_in_code)"
if [ -n "$VARS" ]; then ok "found variables in code ($(echo "$VARS" | wc -l | tr -d ' '))"; else bad "found variables in code" "none"; fi
for name in $VARS; do
  if listed_in_env_example "$name"; then ok "$name in .env.example"; else bad "$name in .env.example" "missing"; fi
done
# Serverpod reads these itself; .env.example documents them commented out.
for name in SERVERPOD_RUN_MODE SERVERPOD_DATABASE_PASSWORD SERVERPOD_REDIS_PASSWORD SERVERPOD_SERVICE_SECRET; do
  if grep -qE "^# $name=" "$ENV_EXAMPLE"; then ok "$name documented (commented out)"; else bad "$name documented (commented out)" "missing or set"; fi
done

echo "# every secret is in docs/infra/secrets.md"
if [ -f "$SECRETS_DOC" ]; then
  ok "secrets.md exists"
  # Serverpod passwords: every key of passwords.example.yaml.
  KEYS="$(grep -oE '^ *#? *[A-Za-z]+: *<generate>' "$REPO_ROOT/puls3_server/config/passwords.example.yaml" |
    sed -E 's/^ *#? *//; s/:.*//' | sort -u)"
  # Docker passwords, CLI identities that hold keys, and the env alternatives.
  OTHERS="$(grep -oE '^[A-Z_]+=' "$REPO_ROOT/puls3_server/.env.example" | tr -d '=')
STELLAR_ACCOUNT AGENT_WALLET_ACCOUNT CLIENT_ACCOUNT TEST_USDC_ISSUER_ACCOUNT
SERVERPOD_DATABASE_PASSWORD SERVERPOD_REDIS_PASSWORD SERVERPOD_SERVICE_SECRET
PULS3_STELLAR_SIMULATION_SOURCE"
  for name in $KEYS $OTHERS; do
    name="$(echo "$name" | tr -d '\r')"
    if grep -q -- "\`$name\`" "$SECRETS_DOC"; then ok "$name in secrets.md"; else bad "$name in secrets.md" "missing"; fi
  done
  for column in "Secret" "Purpose" "Where it is stored" "Who has access" "How to rotate"; do
    if grep -qE "^\|.*$column" "$SECRETS_DOC"; then ok "secrets.md table has '$column'"; else bad "secrets.md table has '$column'" "missing"; fi
  done
else
  bad "secrets.md exists" "$SECRETS_DOC not found"
fi

echo "# .env.example testnet values match the deployment record"
check_value() { # check_value <name> <python expression over d (the record)>
  local want got
  want="$("$PY" -c "import json,sys;d=json.load(open(sys.argv[1]));print($2)" "$RECORD" | tr -d '\r')"
  got="$(grep -E "^$1=" "$ENV_EXAMPLE" | head -n 1 | cut -d= -f2- | tr -d '\r"')"
  if [ "$got" = "$want" ]; then ok "$1 = record"; else bad "$1 = record" "got '$got', want '$want'"; fi
}
check_value PULS3_STELLAR_ESCROW "d['escrow']['contract_id']"
check_value PULS3_ESCROW_CONTRACT "d['escrow']['contract_id']"
check_value PULS3_STELLAR_IDENTITY_REGISTRY "d['identity_registry']['contract_id']"
check_value PULS3_STELLAR_USDC_SAC "d['escrow']['allowed_tokens'][0]['sac_id']"

echo "# .env.example is safe and loadable"
if grep -qE '\bS[A-Z2-7]{55}\b' "$ENV_EXAMPLE"; then bad "no secret seed in .env.example" "found one"; else ok "no secret seed in .env.example"; fi
if out="$(env -i PATH="$PATH" bash -c 'set -euo pipefail; set -a; . "$1"; set +a; printf "%s|%s" "$PULS3_STELLAR_NETWORK_PASSPHRASE" "$REGISTRY_NAME"' _ "$ENV_EXAMPLE" 2>&1)" &&
  [ "$out" = "Test SDF Network ; September 2015|Puls3 Agent" ]; then
  ok "loads in bash (set -a; . ./.env)"
else
  bad "loads in bash (set -a; . ./.env)" "$out"
fi
# Same rules as flutter_tools' .env parser (--dart-define-from-file): every
# non-comment line is KEY=VALUE, and an unquoted value has no spaces.
if out="$("$PY" - "$ENV_EXAMPLE" <<'PYEOF'
import re, sys
bad = []
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$', line)
    if not m or (not re.match(r'^(".*"|\'.*\')$', m.group(2)) and " " in m.group(2)):
        bad.append(f"{n}: {line}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PYEOF
)"; then ok "parses as a dart-define file"; else bad "parses as a dart-define file" "$out"; fi

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
