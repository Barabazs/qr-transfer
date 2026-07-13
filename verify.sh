#!/usr/bin/env bash
# verify.sh — verification baseline for qr-transfer/index.html
#   1. vendored-block integrity: the two VENDORED script blocks must be
#      byte-identical to the pinned npm artifacts (hashes from README.md table)
#   2. functional self-test: headless Chromium runs index.html?selftest and
#      the page must report data-selftest="pass"
# Usage: ./verify.sh [path/to/index.html]
#   SKIP_SELFTEST=1 ./verify.sh   # hash check only (fast)
set -u

HTML="${1:-$(dirname "$0")/index.html}"
[ -f "$HTML" ] || { echo "FAIL: $HTML not found" >&2; exit 1; }

# expected artifacts: name | sha256 | byte size  (must match README.md table)
EXPECTED="qrcode-generator@2.0.4 79ec86f82856005b1c887905cfccfcfbec3821ca61c7fd5a952faa5f778f791c 56694
jsqr@1.4.0 bc40c8a15196236b2314db0856f72ca0b49980cd5413b8c852a7349f5fee0859 256885"

fail=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# extract each vendored block: content starts on the line after the banner
# comment closes ("===== */") and ends on the line before "</script>".
awk '
  /VENDORED \(verbatim/ { inbanner=1 }
  inbanner && /===== \*\// { inbanner=0; capture=1; n++; next }
  capture && /^<\/script>$/ { capture=0; next }
  capture { print > (dir "/block" n ".js") }
' dir="$tmpdir" "$HTML"

i=0
while read -r name hash size; do
  i=$((i+1))
  block="$tmpdir/block$i.js"
  if [ ! -f "$block" ]; then
    echo "FAIL: vendored block $i ($name) not found in $HTML"; fail=1; continue
  fi
  # awk print appends \n to the final line; the pinned artifact has no
  # trailing newline, so the extracted block must be exactly size+1 bytes
  got_size=$(wc -c < "$block")
  got_hash=$(head -c "$size" "$block" | sha256sum | cut -d' ' -f1)
  if [ "$got_size" -ne "$((size+1))" ] || [ "$got_hash" != "$hash" ]; then
    echo "FAIL: vendored $name modified (size $got_size vs $((size+1)), sha256 $got_hash)"
    fail=1
  else
    echo "OK: vendored $name intact"
  fi
done <<EOF2
$EXPECTED
EOF2

[ "$fail" -ne 0 ] && exit 1

if [ "${SKIP_SELFTEST:-0}" = "1" ]; then
  echo "OK: selftest skipped (SKIP_SELFTEST=1)"; exit 0
fi

CHROME="${CHROME:-}"
for c in chromium chromium-browser google-chrome google-chrome-stable; do
  [ -n "$CHROME" ] && break
  command -v "$c" >/dev/null && CHROME=$c
done
[ -n "$CHROME" ] || { echo "FAIL: no chromium/chrome found (set CHROME=...)"; exit 1; }

dom=$("$CHROME" --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage \
  --user-data-dir="$tmpdir/profile" --virtual-time-budget=240000 --timeout=240000 \
  --dump-dom "file://$(cd "$(dirname "$HTML")" && pwd)/$(basename "$HTML")?selftest" 2>/dev/null)

case "$dom" in
  *'data-selftest="pass"'*) echo "OK: selftest passed" ;;
  *'data-selftest="fail"'*) echo "FAIL: selftest reported failures"; exit 1 ;;
  *) echo "FAIL: selftest did not complete (no data-selftest marker)"; exit 1 ;;
esac
echo "PASS: all checks"
