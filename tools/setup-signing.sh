#!/bin/bash
# One-time: give AllyKeyboard a stable self-signed identity, so the
# Accessibility grant survives every rebuild and every release.
#
# Without this the app is ad-hoc signed: each build has a different signature,
# macOS sees a different application, and the grant has to be given again. For
# a user whose only way to type is this keyboard, that is not a minor
# annoyance — it is being locked out until somebody else clicks the toggle.
#
# Why a dedicated keychain rather than login: the login keychain is GUI-managed
# and refuses non-interactive codesign access over SSH. A separate keychain with
# a throwaway password can be unlocked and partition-listed from the command
# line, which is what both the local build and CI need.
#
# Unlike the clicker's version of this script, the certificate is created here
# rather than exported from Keychain Access — so the .p12 exists from the start
# and can go straight into CI secrets without a GUI session.
#
# Safe over SSH. Re-runnable.
set -euo pipefail

NAME="AllyKeyboard Self-Signed"
KC="$HOME/Library/Keychains/allykeyboard.keychain-db"
KCPASS=allykeyboard          # throwaway; guards one local self-signed cert
STORE="$HOME/.allykeyboard-signing"
P12="$STORE/allykeyboard.p12"

mkdir -p "$STORE"; chmod 700 "$STORE"

if [ ! -f "$P12" ]; then
  echo "[1/4] Creating the certificate..."
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$STORE/key.pem" -out "$STORE/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
  openssl pkcs12 -export -inkey "$STORE/key.pem" -in "$STORE/cert.pem" \
    -out "$P12" -passout "pass:$KCPASS" -name "$NAME"
  chmod 600 "$STORE"/*
else
  echo "[1/4] Certificate already at $P12"
fi

echo "[2/4] Keychain..."
security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || echo "      (already exists)"
security unlock-keychain -p "$KCPASS" "$KC"
security set-keychain-settings "$KC"          # no auto-lock

echo "[3/4] Importing, and letting codesign use the key unattended..."
security import "$P12" -k "$KC" -P "$KCPASS" -A -T /usr/bin/codesign 2>&1 | tail -1
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null

echo "[4/4] Search list..."
EXISTING=$(security list-keychains -d user | sed 's/[[:space:]]*"//; s/"$//')
echo "$EXISTING" | grep -q allykeyboard.keychain || security list-keychains -d user -s "$KC" $EXISTING

echo
echo "Done. The identity signs but is not trusted for verification — that is"
echo "expected for a self-signed certificate and does not affect the grant."
security find-identity "$KC" | grep -F "$NAME" | head -2 || true
echo
echo "For releases, put the same identity into the repository secrets:"
echo "  gh secret set SIGNING_P12_BASE64 --repo umkasanki/ally-keyboard < <(base64 -i \"$P12\")"
echo "  gh secret set SIGNING_P12_PASSWORD --repo umkasanki/ally-keyboard --body $KCPASS"
