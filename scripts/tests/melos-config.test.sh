#!/usr/bin/env bash
# Offline checks for the Melos 8 configuration (#254).
# Melos 8 keeps its configuration in the root pubspec, not in melos.yaml.
# Run from anywhere: bash scripts/tests/melos-config.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PUBSPEC="$REPO_ROOT/pubspec.yaml"
README="$REPO_ROOT/README.md"
CONTRIBUTING="$REPO_ROOT/CONTRIBUTING.md"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

if [ -f "$PUBSPEC" ]; then ok "root pubspec exists"; else bad "root pubspec exists" "missing"; fi
if [ -f "$REPO_ROOT/melos.yaml" ]; then
  bad "Melos 8 config lives in pubspec.yaml" "melos.yaml must not exist"
else
  ok "Melos 8 config lives in pubspec.yaml"
fi

for needle in \
  "melos: ^8.10.1" \
  "melos:" \
  "analyze:" \
  '"test:unit":' \
  '"test:integration":' \
  '"test:e2e":'; do
  if grep -qF -- "$needle" "$PUBSPEC"; then
    ok "pubspec has $needle"
  else
    bad "pubspec has $needle" "missing"
  fi
done

# Slice the test:unit block and keep it away from integration.
unit_block="$(awk '/"test:unit":/{flag=1} /"test:integration":/{flag=0} flag' "$PUBSPEC")"
for needle in "ls -d test/*/" "integration|e2e|support|fixtures" "puls3_sdk" "puls3_mcp" "flutter test"; do
  if printf '%s' "$unit_block" | grep -qF -- "$needle"; then
    ok "test:unit runs $needle"
  else
    bad "test:unit runs $needle" "missing"
  fi
done
# The server lane runs every test folder but the excluded ones, so a new
# folder is never skipped silently.
server_lane="$(printf '%s' "$unit_block" | grep 'puls3_server)' | sed -E 's/^[[:space:]]*puls3_server\) //; s/ ;;$//')"
if [ -d "$REPO_ROOT/puls3_server/test" ]; then
  expected="$(cd "$REPO_ROOT/puls3_server" && ls -d test/*/ | grep -vE '/(integration|e2e|support|fixtures)/$' | tr '\n' ' ')"
  actual="$(cd "$REPO_ROOT/puls3_server" && eval "dart() { shift; printf '%s ' \"\$@\"; }; $server_lane")"
  if [ -n "$actual" ] && [ "$actual" = "$expected" ]; then
    ok "test:unit runs every server test folder but the excluded ones"
  else
    bad "test:unit runs every server test folder but the excluded ones" "got: $actual"
  fi
  case " $actual " in
    *" test/integration/ "*|*" test/e2e/ "*)
      bad "test:unit avoids integration and e2e tests" "found in: $actual" ;;
    *) ok "test:unit avoids integration and e2e tests" ;;
  esac
fi

integration_block="$(awk '/"test:integration":/{flag=1} /"test:e2e":/{flag=0} flag' "$PUBSPEC")"
if printf '%s' "$integration_block" | grep -qF "dart test test/integration"; then
  ok "test:integration runs the server integration suite"
else
  bad "test:integration runs the server integration suite" "missing"
fi

e2e_block="$(awk '/"test:e2e":/{flag=1} flag' "$PUBSPEC")"
if printf '%s' "$e2e_block" | grep -qF "test/e2e"; then
  ok "test:e2e targets the e2e suite"
else
  bad "test:e2e targets the e2e suite" "missing"
fi
if printf '%s' "$e2e_block" | grep -qF "#255"; then
  ok "test:e2e explains the #255 dependency"
else
  bad "test:e2e explains the #255 dependency" "missing"
fi

for doc in "$README" "$CONTRIBUTING"; do
  for command in "melos bs" "melos run analyze" "melos run test:unit" "melos run test:integration" "melos run test:e2e"; do
    if grep -qF -- "$command" "$doc"; then
      ok "$(basename "$doc") documents $command"
    else
      bad "$(basename "$doc") documents $command" "missing"
    fi
  done
done

if grep -q "melos:" "$REPO_ROOT/pubspec.lock"; then
  ok "pubspec.lock resolves melos"
else
  bad "pubspec.lock resolves melos" "missing"
fi

if command -v melos >/dev/null 2>&1; then
  listed="$(cd "$REPO_ROOT" && melos run --list 2>/dev/null || true)"
  for script in "analyze" "test:unit" "test:integration" "test:e2e"; do
    if printf '%s' "$listed" | grep -qx -- "$script"; then
      ok "melos lists $script"
    else
      bad "melos lists $script" "not listed"
    fi
  done
else
  echo "skip - melos is not installed; the configuration was checked statically"
fi

echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
