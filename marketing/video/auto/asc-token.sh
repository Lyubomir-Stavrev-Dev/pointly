#!/bin/bash
# Mint an App Store Connect JWT for an *individual* API key (no issuer ID).
# Usage: asc-token.sh <path-to-ApiKey_XXXX.p8>
set -euo pipefail
KEYFILE="$1"
KID=$(basename "$KEYFILE" .p8 | sed 's/^ApiKey_//; s/^AuthKey_//')
NOW=$(date +%s)
EXP=$((NOW + 1100))

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

HEADER=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$KID" | b64url)
PAYLOAD=$(printf '{"sub":"user","aud":"appstoreconnect-v1","iat":%d,"exp":%d}' "$NOW" "$EXP" | b64url)
SIGNING_INPUT="$HEADER.$PAYLOAD"

# ES256: sign, then convert DER signature to raw r||s (64 bytes)
DER=$(printf '%s' "$SIGNING_INPUT" | openssl dgst -sha256 -sign "$KEYFILE" | xxd -p | tr -d '\n')
SIG=$(python3 - "$DER" <<'PY'
import sys, base64
der = bytes.fromhex(sys.argv[1])
# minimal DER SEQUENCE{ INTEGER r, INTEGER s } parser
i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7f)
def read_int(b, i):
    assert b[i] == 0x02
    l = b[i+1]
    v = b[i+2:i+2+l].lstrip(b'\x00')
    return v.rjust(32, b'\x00'), i + 2 + l
r, i = read_int(der, i)
s, i = read_int(der, i)
print(base64.urlsafe_b64encode(r + s).decode().rstrip('='))
PY
)
echo "$SIGNING_INPUT.$SIG"
