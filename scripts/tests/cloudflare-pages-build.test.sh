#!/usr/bin/env bash
# Offline regression tests for scripts/cloudflare-pages-build.sh.
# No network, no real Flutter: a PATH stub stands in for `git`, and the stub
# clone provides a fake `flutter` that records how it was called.
# Run from anywhere: bash scripts/tests/cloudflare-pages-build.test.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
BUILD_SH="$REPO_ROOT/scripts/cloudflare-pages-build.sh"
CI_YML="$REPO_ROOT/.github/workflows/ci.yml"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ($2)"; }

# A fake `git` whose clone creates <dest>/bin/flutter. The fake flutter logs
# its working directory and arguments. GIT_STUB_FAIL=1 makes the clone fail.
mkdir -p "$WORK/stubs"
cat > "$WORK/stubs/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$STUB_LOG"
[ "${GIT_STUB_FAIL:-0}" = 1 ] && exit 128
dest="${!#}"
mkdir -p "$dest/bin"
cat > "$dest/bin/flutter" <<'FLUTTER'
#!/usr/bin/env bash
echo "flutter cwd=$(basename "$PWD") $*" >> "$STUB_LOG"
FLUTTER
chmod +x "$dest/bin/flutter"
EOF
chmod +x "$WORK/stubs/git"

# run_build <log-file> [env assignments...]
run_build() {
  local log="$1"
  shift
  : > "$log"
  env PATH="$WORK/stubs:$PATH" STUB_LOG="$log" \
    PULS3_FLUTTER_DIR="$WORK/flutter-$(basename "$log")" "$@" \
    bash "$BUILD_SH" > "$log.out" 2>&1
}

script_version="$(sed -n 's/^FLUTTER_VERSION=\([0-9.]*\)$/\1/p' "$BUILD_SH")"

# 1. The script pins the same Flutter version as every CI job.
ci_versions="$(sed -n "s/.*flutter-version: '\([0-9.]*\)'.*/\1/p" "$CI_YML" | sort -u)"
if [ -n "$script_version" ] && [ "$ci_versions" = "$script_version" ]; then
  ok "Flutter version matches CI ($script_version)"
else
  bad "Flutter version matches CI" "script '$script_version', CI '$ci_versions'"
fi

# 2. It clones that version shallowly and builds the release web app in puls3_flutter.
log="$WORK/success"
if run_build "$log"; then
  ok "build exits 0"
else
  bad "build exits 0" "$(cat "$log.out")"
fi
if grep -q -- "git clone https://github.com/flutter/flutter.git -b $script_version --depth 1 " "$log"; then
  ok "clones the pinned Flutter version"
else
  bad "clones the pinned Flutter version" "$(cat "$log")"
fi
if grep -qx "flutter cwd=puls3_flutter build web --release" "$log"; then
  ok "runs flutter build web --release in puls3_flutter"
else
  bad "runs flutter build web --release in puls3_flutter" "$(cat "$log")"
fi

# 3. A failed clone stops the build before Flutter runs.
log="$WORK/clone-fails"
if run_build "$log" GIT_STUB_FAIL=1; then
  bad "failed clone exits non-zero" "exit 0"
else
  ok "failed clone exits non-zero"
fi
if grep -q '^flutter' "$log"; then
  bad "failed clone skips flutter" "$(cat "$log")"
else
  ok "failed clone skips flutter"
fi

echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
