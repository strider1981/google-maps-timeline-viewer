#!/usr/bin/env bash
# Static checks for timeline-woosmap.html: inline scripts must parse, and no Google / data-API usage may remain.
set -u
FILE="${1:-timeline-woosmap.html}"
TMP="${TMPDIR:-/tmp}/check-woosmap.$$"
mkdir -p "$TMP"
status=0

# 1. Syntax: extract each inline <script> block and run node --check on it.
awk -v dir="$TMP" '
  /<script[^>]*>/ && !/src=/ { inblock=1; n++; next }
  /<\/script>/ && inblock { inblock=0; close(dir "/s" n ".js"); next }
  inblock { print > (dir "/s" n ".js") }
' "$FILE"
for f in "$TMP"/s*.js; do
  [ -e "$f" ] || continue
  if ! node --check "$f" 2> "$TMP/err.txt"; then
    echo "SYNTAX FAIL in $(basename "$f"):"; head -5 "$TMP/err.txt"; status=1
  fi
done

# 2. Forbidden patterns.
for pat in 'google\.maps' 'googleapis\.com' 'importLibrary' 'AdvancedMarkerElement' 'PinElement' 'new Place(' 'fetchFields' 'GoogleMapsOverlay' 'gm_authFailure' 'e\.latLng' 'open({ map' '[a-zA-Z]\.map = null' 'marker\.map = map'; do
  c=$(grep -c -- "$pat" "$FILE")
  if [ "$c" -gt 0 ]; then echo "FORBIDDEN '$pat': $c"; status=1; fi
done

# 3. fetch() targets must not leave the allowed hosts (only CDN scripts are external).
if grep -n 'fetch(' "$FILE" | grep -v 'fetch(url' | grep -E 'https?://' | grep -vE 'cdnjs\.cloudflare\.com|cdn\.jsdelivr\.net|unpkg\.com|sdk\.woosmap\.com'; then
  echo "FORBIDDEN fetch target"; status=1
fi
if grep -nE 'const url = `https?://' "$FILE"; then echo "FORBIDDEN url constant"; status=1; fi

rm -rf "$TMP"
[ $status -eq 0 ] && echo OK
exit $status
