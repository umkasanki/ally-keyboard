#!/bin/bash
# One-time: create a stable self-signed code-signing identity in a DEDICATED
# keychain so AllyKeyboard's Accessibility grant PERSISTS across rebuilds and the
# build can sign non-interactively over SSH.
#
# Why a dedicated keychain (not login): the login keychain is GUI-managed and
# refuses non-interactive codesign access over SSH ("User interaction is not
# allowed"). A separate keychain with a known throwaway password can be fully
# unlocked and partition-listed from the command line.
#
# Safe to run over SSH. Re-runnable.
set -euo pipefail

KC="$HOME/Library/Keychains/allykeyboard.keychain-db"
KCPASS="allykeyboard"      # throwaway; only guards a local self-signed cert
IDENTITY="AllyKeyboard Local"
CONF=/tmp/allykb-cert.conf
KEY=/tmp/allykb.key
CRT=/tmp/allykb.crt
P12=/tmp/allykb.p12

echo "[1/6] Generating self-signed code-signing cert..."
cat > "$CONF" <<CONFEOF
[req]
distinguished_name = req_dn
x509_extensions = v3
prompt = no
[req_dn]
CN = $IDENTITY
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CONFEOF
openssl req -x509 -newkey rsa:2048 -keyout "$KEY" -out "$CRT" -days 3650 -nodes -config "$CONF" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$KEY" -in "$CRT" -out "$P12" -passout pass:allykb -name "$IDENTITY" >/dev/null 2>&1

echo "[2/6] Creating dedicated keychain..."
security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || echo "  (already exists)"

echo "[3/6] Unlocking + disabling auto-lock..."
security unlock-keychain -p "$KCPASS" "$KC"
security set-keychain-settings "$KC"

echo "[4/6] Importing identity (codesign-accessible)..."
security import "$P12" -k "$KC" -P allykb -T /usr/bin/codesign 2>&1 | tail -1 || true

echo "[5/6] Allowing codesign to use the key non-interactively..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null

echo "[6/6] Adding keychain to the search list..."
EXISTING=$(security list-keychains -d user | sed "s/[[:space:]]*\"//; s/\"$//")
echo "$EXISTING" | grep -q "allykeyboard.keychain" || security list-keychains -d user -s "$KC" $EXISTING

# tidy up cert material
rm -f "$CONF" "$KEY" "$CRT" "$P12"

echo
echo "Done. Identity:"
security find-identity "$KC" | grep "$IDENTITY" || echo "  (not found - check import)"
echo
echo "Now build:  ./AllyKeyboard/build-signed.sh"
