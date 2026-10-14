#!/usr/bin/env bash
# Build command for the Cloudflare Pages project `puls3`.
#
# Pages runs this from the repository root. It installs the Flutter version
# pinned for this branch and builds the web app into puls3_flutter/build/web
# (the Pages output directory). Keep FLUTTER_VERSION in sync with the
# `flutter-version` in .github/workflows/ci.yml; the test
# scripts/tests/cloudflare-pages-build.test.sh fails when they drift.
set -euo pipefail

FLUTTER_VERSION=3.44.4

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${PULS3_FLUTTER_DIR:-$REPO_ROOT/flutter}"

# The SEP-10 values the app checks every sign-in challenge against (#136).
# A static Pages build has no server-published config.json `auth`, so the
# Pages project pins them. All three are public; the key is the server's
# `G…` account, never its secret.
auth_vars=(PULS3_AUTH_SERVER_SIGNING_KEY PULS3_AUTH_HOME_DOMAIN PULS3_AUTH_WEB_AUTH_DOMAIN)
if [ -n "${PULS3_AUTH_SERVER_SIGNING_KEY:-}" ] &&
  ! [[ "$PULS3_AUTH_SERVER_SIGNING_KEY" =~ ^G[A-Z2-7]{55}$ ]]; then
  # The value is never echoed: it might be a secret seed.
  echo "PULS3_AUTH_SERVER_SIGNING_KEY must be the server's public G… address." >&2
  exit 1
fi
# A real hire or Studio signs in with the wallet, so it must not run with
# unpinned challenge checks.
if [ "${PULS3_HIRE:-}" = server ] || [ "${PULS3_STUDIO:-}" = server ]; then
  for name in "${auth_vars[@]}"; do
    if [ -z "${!name:-}" ]; then
      echo "PULS3_HIRE=server or PULS3_STUDIO=server needs $name (see puls3_server/README.md)." >&2
      exit 1
    fi
  done
fi

git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
export PATH="$FLUTTER_DIR/bin:$PATH"

build_args=(--release)
# Set PULS3_API_URL in the Pages project environment to point the app at the
# deployed server (see puls3_server/README.md).
if [ -n "${PULS3_API_URL:-}" ]; then
  build_args+=("--dart-define=PULS3_API_URL=$PULS3_API_URL")
fi
# Set PULS3_HIRE=server once the server accepts wallet sessions, so hires
# move real testnet USDC through the escrow. Unset keeps the labelled demo.
if [ -n "${PULS3_HIRE:-}" ]; then
  build_args+=("--dart-define=HIRE=$PULS3_HIRE")
fi
for name in "${auth_vars[@]}"; do
  if [ -n "${!name:-}" ]; then
    build_args+=("--dart-define=$name=${!name}")
  fi
done
# Set PULS3_STUDIO=server so the public Studio saves, test-runs and deploys
# for real. Unset keeps the labelled demo.
if [ -n "${PULS3_STUDIO:-}" ]; then
  build_args+=("--dart-define=STUDIO=$PULS3_STUDIO")
fi

cd "$REPO_ROOT/puls3_flutter"
flutter build web "${build_args[@]}"
