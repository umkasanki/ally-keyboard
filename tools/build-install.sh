#!/bin/bash
# Build AllyKeyboard and install it to /Applications, signed with the stable
# identity from tools/setup-signing.sh — the same identity CI uses, so a locally
# installed build and a downloaded release are the same application to macOS and
# the Accessibility grant carries over between them.
#
# Falls back to ad-hoc if the identity is missing, and says so, because a silent
# fallback is how you discover months later that the grant keeps resetting.
set -euo pipefail
cd "$(dirname "$0")/.."

KC="$HOME/Library/Keychains/allykeyboard.keychain-db"
NAME="AllyKeyboard Self-Signed"
IDENTITY="-"
EXTRA=()

if security find-identity "$KC" 2>/dev/null | grep -qF "$NAME"; then
  security unlock-keychain -p allykeyboard "$KC"
  IDENTITY="$NAME"
  EXTRA=("OTHER_CODE_SIGN_FLAGS=--keychain $KC")
  echo "Signing as: $NAME"
else
  echo "WARNING: no stable identity — signing ad-hoc, the Accessibility grant will reset."
  echo "         run tools/setup-signing.sh once to fix that."
fi

rm -rf build
xcodebuild -project AllyKeyboard/AllyKeyboard.xcodeproj \
           -scheme AllyKeyboard -configuration Release \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
           ${EXTRA[@]+"${EXTRA[@]}"} build | tail -3

APP=build/Build/Products/Release/AllyKeyboard.app
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E 'Authority|Signature|Identifier=' || true

osascript -e 'tell application "AllyKeyboard" to quit' 2>/dev/null || true
pkill -x AllyKeyboard 2>/dev/null || true
sleep 1
rm -rf /Applications/AllyKeyboard.app
cp -R "$APP" /Applications/AllyKeyboard.app
open /Applications/AllyKeyboard.app
echo "Installed and launched /Applications/AllyKeyboard.app"
