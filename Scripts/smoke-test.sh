#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$ROOT_DIR/Doffice.xcworkspace"
LEGACY_PROJECT="$ROOT_DIR/Doffice/Doffice.xcodeproj"

DESIGNSYSTEM_DERIVED="${DESIGNSYSTEM_DERIVED_DATA_PATH:-$ROOT_DIR/build-designsystem-smoke}"
KIT_DERIVED="${DOFFICEKIT_DERIVED_DATA_PATH:-$ROOT_DIR/build-dofficekit-smoke}"
LEGACY_DERIVED="${LEGACY_DERIVED_DATA_PATH:-$ROOT_DIR/build-legacy-smoke}"
APP_DERIVED="${APP_DERIVED_DATA_PATH:-$ROOT_DIR/build-app-smoke}"

if command -v tuist >/dev/null 2>&1; then
  TUIST_VERSION="$(tuist version 2>/dev/null | sed -n '1p')"
  if [[ "$TUIST_VERSION" == 3.* ]]; then
    echo "[smoke] 0/5 Refresh workspace via Tuist $TUIST_VERSION"
    tuist generate --no-open >/dev/null
  fi
fi

echo "[smoke] 0.5/5 Legacy ↔ Modular source sync check"
# Critical shared files that must stay in sync between Projects/ and Doffice/
SYNC_PAIRS=(
  "Projects/DofficeKit/Sources/DofficeServer.swift:Doffice/Sources/DofficeServer.swift"
  "Projects/DofficeKit/Sources/SessionStore.swift:Doffice/Sources/SessionStore.swift"
  "Projects/DofficeKit/Sources/CrashLogger.swift:Doffice/Sources/CrashLogger.swift"
  "Projects/DofficeKit/Sources/VT100Terminal.swift:Doffice/Sources/VT100Terminal.swift"
)
SYNC_DRIFT=0
for pair in "${SYNC_PAIRS[@]}"; do
  IFS=: read -r modular legacy <<< "$pair"
  if [[ -f "$ROOT_DIR/$modular" && -f "$ROOT_DIR/$legacy" ]]; then
    # Compare function signatures and key patterns (not exact diff, since access modifiers differ)
    MOD_FUNCS=$(grep -cE '^\s*(public |private )?func ' "$ROOT_DIR/$modular" 2>/dev/null || echo 0)
    LEG_FUNCS=$(grep -cE '^\s*(public |private )?func ' "$ROOT_DIR/$legacy" 2>/dev/null || echo 0)
    if [[ "$MOD_FUNCS" != "$LEG_FUNCS" ]]; then
      echo "  ⚠️  Function count drift: $modular ($MOD_FUNCS) vs $legacy ($LEG_FUNCS)"
      SYNC_DRIFT=1
    fi
  fi
done
if [[ "$SYNC_DRIFT" -eq 1 ]]; then
  echo "  ⚠️  Source sync drift detected — review before release (non-blocking)"
fi

echo "[smoke] 1/5 DesignSystem tests"
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme DesignSystem \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath "$DESIGNSYSTEM_DERIVED"

echo "[smoke] 2/5 DofficeKit tests"
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme DofficeKit \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath "$KIT_DERIVED"

echo "[smoke] 3/5 Legacy Doffice tests"
xcodebuild test \
  -project "$LEGACY_PROJECT" \
  -scheme Doffice \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath "$LEGACY_DERIVED"

echo "[smoke] 4/5 Release build"
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

echo "[smoke] 5/5 App launch smoke test"
DOFFICE_SMOKE_TEST=1 "$APP_BINARY" --smoke-test --smoke-timeout=25

echo "[smoke] completed"
