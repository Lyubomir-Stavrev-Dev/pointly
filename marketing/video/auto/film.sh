#!/bin/bash
# Film one clip: record the screen while mousetool performs the choreography.
# Usage: ./film.sh <clip-name> <choreography.txt> <record-seconds> [startoverlay=on|off]
# Output: ../raw/<clip-name>.mov  (cropped to 16:9, menu bar removed)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="$1"; SCRIPT="$2"; SECS="$3"; STARTOVERLAY="${4:-on}"
TMP="$DIR/.take-$NAME.mov"
OUT="$DIR/../raw/$NAME.mov"
mkdir -p "$DIR/../raw"
rm -f "$TMP"

overlay_on() { "$DIR/mousetool" -c "wins pointly" | grep -q "layer=100"; }
ensure_overlay() { # $1 = on|off — toggle until verified, retrying up to 4x
  for _ in 1 2 3 4; do
    if overlay_on; then cur=on; else cur=off; fi
    [ "$cur" = "$1" ] && return 0
    "$DIR/mousetool" -c "key p cmd+shift; sleep 1.4"
  done
  echo "FAILED to set overlay=$1" >&2; exit 1
}

# --- pre-roll: known-good state ---
# 1. overlay OFF (stage raising works regardless, but keeps state deterministic)
ensure_overlay off
# 2. raise stage by activating its Chrome instance directly (no clicks, no focus races)
STAGEPID=$(pgrep -f "user-data-dir=/tmp/pointly-stage" | sort -n | head -1)
[ -n "$STAGEPID" ] || { echo "stage Chrome not running" >&2; exit 1; }
"$DIR/mousetool" -c "activate $STAGEPID; sleep 0.5"
# 3. clear leftover annotations (they persist across overlay toggles), then set start state
ensure_overlay on
"$DIR/mousetool" -c "key delete cmd; sleep 0.4"
if [ "$STARTOVERLAY" = "on" ]; then
  ensure_overlay on
else
  ensure_overlay off
fi
# 4. park cursor
"$DIR/mousetool" -c "move 950 950 0.2"

# --- record ---
screencapture -v -k -V "$SECS" "$TMP" &
REC=$!
sleep 1.0
"$DIR/mousetool" "$SCRIPT"
wait $REC
[ -f "$TMP" ] || { echo "recording failed" >&2; exit 1; }

# crop retina 3840x2486 -> 3840x2160 starting below the menu bar + stage titlebar
ffmpeg -nostdin -v error -y -i "$TMP" -vf "crop=3840:2160:0:130" -c:v libx264 -preset fast -crf 15 -pix_fmt yuv420p -an "$OUT"
rm -f "$TMP"
echo "saved raw/$NAME.mov ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s)"
