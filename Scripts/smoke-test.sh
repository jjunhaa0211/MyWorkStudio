#!/bin/zsh
#
# smoke-test.sh — Local full-pipeline test runner.
# CI uses individual steps in .github/workflows/build.yml instead.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$ROOT_DIR/Doffice.xcworkspace"

DESIGNSYSTEM_DERIVED="${DESIGNSYSTEM_DERIVED_DATA_PATH:-$ROOT_DIR/build-designsystem-smoke}"
KIT_DERIVED="${DOFFICEKIT_DERIVED_DATA_PATH:-$ROOT_DIR/build-dofficekit-smoke}"
APP_DERIVED="${APP_DERIVED_DATA_PATH:-$ROOT_DIR/build-app-smoke}"

if command -v tuist >/dev/null 2>&1; then
  TUIST_VERSION="$(tuist version 2>/dev/null | sed -n '1p')"
  if [[ "$TUIST_VERSION" == 3.* ]]; then
    echo "[smoke] 0/4 Refresh workspace via Tuist $TUIST_VERSION"
    tuist generate --no-open >/dev/null
  fi
fi

echo "[smoke] 1/4 DesignSystem tests"
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme DesignSystem \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath "$DESIGNSYSTEM_DERIVED"

echo "[smoke] 2/4 DofficeKit tests"
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme DofficeKit \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath "$KIT_DERIVED"

echo "[smoke] 3/4 Release build"
xcodebuild build \
  -workspace "$WORKSPACE" \
  -scheme Doffice \
  -destination 'platform=macOS' \
  -configuration Release \
  ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath "$APP_DERIVED"

APP_BINARY="$APP_DERIVED/Build/Products/Release/Doffice.app/Contents/MacOS/Doffice"
if [[ ! -x "$APP_BINARY" ]]; then
  echo "[smoke] Missing app binary at $APP_BINARY" >&2
  exit 1
fi

echo "[smoke] 4/4 App launch smoke test"
DOFFICE_SMOKE_TEST=1 "$APP_BINARY" --smoke-test --smoke-timeout=25

echo "[smoke] completed"
