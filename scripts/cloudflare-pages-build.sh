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

git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
export PATH="$FLUTTER_DIR/bin:$PATH"

cd "$REPO_ROOT/puls3_flutter"
flutter build web --release
