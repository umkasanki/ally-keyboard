#!/bin/bash
# Build AllyKeyboard via Xcode and re-sign with a stable self-signed identity so
# the Accessibility grant PERSISTS across rebuilds. Run on macOS (works over SSH).
#
#   ./AllyKeyboard/build-signed.sh && open build/Build/Products/Debug/AllyKeyboard.app
#
# One-time signing setup lives in setup-signing.sh (creates the identity).
set -euo pipefail
cd "$(dirname "$0")"   # AllyKeyboard/ (dir with the .xcodeproj)

IDENTITY="AllyKeyboard Local"
KC="$HOME/Library/Keychains/allykeyboard.keychain-db"
DD="$PWD/build"

echo "[1/3] xcodebuild..."
xcodebuild -scheme AllyKeyboard -configuration Debug -derivedDataPath "$DD" build >/dev/null

APP="$DD/Build/Products/Debug/AllyKeyboard.app"

echo "[2/3] code signing..."
if [ -f "$KC" ] && security find-identity "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
    security unlock-keychain -p allykeyboard "$KC" 2>/dev/null || true
    codesign --force --deep --sign "$IDENTITY" --keychain "$KC" "$APP"
    echo "  signed with stable identity: $IDENTITY"
else
    codesign --force --deep --sign - "$APP"
    echo "  stable identity not found -> ad-hoc (grant resets each build)."
    echo "  run ./AllyKeyboard/setup-signing.sh once to make the grant persist."
fi

echo "[3/3] done: $APP"
