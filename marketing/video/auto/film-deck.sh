#!/bin/bash
# One-shot, uninterrupted shoot of tool demos over the Pointly deck.
# Coordinates come from the deck's own layout (?coords dump at 1920x1243) —
# measured, not guessed:
#   statnum [1095,348,648,138]  hotbar [1658,498,85,388]  chartcard [1038,262,762,720]
#   bullets y-centers 652/722/792/863 (x from 165)   quote [120,507,902,218]
#   secret0 [756,564,483,58]  secret1 [843,685,396,58]  fbox0 [120,608,279,102]
# Records full-screen clips into ~/Desktop/pointly_teaser/tools/.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
MT="$DIR/mousetool"
OUT="$HOME/Desktop/pointly_teaser/tools"
mkdir -p "$OUT"
LOG="$OUT/_shoot.log"; : > "$LOG"
say(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
# a stale interactive capture blocks ALL subsequent ones ("cannot run two…")
pkill -x screencapture 2>/dev/null; sleep .5
# screencapture's final-location move is flaky on synced Desktop folders —
# capture into /tmp and mv into place ourselves
CAP=/tmp/pointly_cap; mkdir -p "$CAP"

DECK=$(pgrep -f "user-data-dir=/tmp/pointly-deck" | head -1)
[ -n "$DECK" ] || { say "deck not open"; exit 1; }
FILTER="${1:-}"
want(){ [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }

overlay_on(){ "$MT" -c "wins pointly" | grep -q "layer=100"; }
ensure(){ for _ in 1 2 3 4; do
    if overlay_on; then c=on; else c=off; fi
    [ "$c" = "$1" ] && return 0
    "$MT" -c "key p cmd+shift; sleep 1.2"
  done; }
goto(){ ensure off
  local seq="activate $DECK; sleep .5; key #115 -; sleep .5"
  for _ in $(seq 1 "$1"); do seq="$seq; key #124 -; sleep .35"; done
  "$MT" -c "$seq; sleep .5"; }
# rec name slide tool sizebumps secs choreo
rec(){
  local name="$1" slide="$2" tool="$3" bumps="$4" secs="$5" choreo="$6"
  want "$name" || return 0
  say "TAKE $name"
  goto "$slide"; ensure on
  "$MT" -c "key delete cmd; sleep .3"
  [ "$tool" != "-" ] && "$MT" -c "key $tool; sleep .5"
  local i=0; while [ $i -lt "$bumps" ]; do "$MT" -c "key = cmd"; i=$((i+1)); done
  "$MT" -c "move 960 1150 0.2"
  local t0=$(date +%s) tmpf="$CAP/$name.mov"
  screencapture -v -V "$secs" "$tmpf" 2>>"$LOG" &
  local R=$!
  sleep 1.0
  "$MT" -c "$choreo"
  wait $R
  if [ "$(stat -f %m "$tmpf" 2>/dev/null || echo 0)" -lt "$t0" ]; then
    say "FAIL $name — screencapture wrote no new file"; return 1
  fi
  mv -f "$tmpf" "$OUT/$name.mov"
  # undo size bumps to keep runs deterministic
  i=0; while [ $i -lt "$bumps" ]; do "$MT" -c "key - cmd"; i=$((i+1)); done
  "$MT" -c "key delete cmd; sleep .3"
  say "OK $name ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$name.mov" 2>/dev/null)s)"
}

say "shoot start (layout-exact coords)"

# — chart slide (2): number center (1296,417) —
rec 01-pen 2 "1 ctrl" 0 9 \
 "path 2.4 1540 417 1475 492 1300 519 1128 492 1058 417 1128 342 1300 315 1472 342 1546 417 1480 487; sleep 1.4"
rec 02-marker 2 "3 ctrl" 3 8 \
 "path 1.3 1100 508 1500 508; sleep .4; path 1.1 1105 528 1495 528; sleep 1.3"
rec 03-arrow 2 "6 ctrl" 0 8 \
 "drag 700 760 1140 470 1.1; sleep 1.5"
rec 04-line 2 "7 ctrl" 0 7 \
 "drag 700 1000 1640 730 1.0; sleep 1.3"
rec 05-rectangle 2 "r ctrl" 0 8 \
 "drag 1020 248 1818 998 1.5; sleep 1.4"
rec 06-ellipse 2 "e ctrl" 0 8 \
 "drag 1072 328 1770 508 1.3; sleep 1.4"
rec 07-spotlight 2 "s ctrl" 0 10 \
 "glide 1.8 960 1150 1296 417; sleep 1.6; glide 1.2 1296 417 1700 690; sleep 1.6"

# — bullets slide (3): rows y 652/722/792/863, text from x165 —
rec 08-highlighter 3 "2 ctrl" 4 9 \
 "path 1.6 165 652 1150 652; sleep .5; path 1.3 165 722 1000 722; sleep 1.3"
rec 09-laser 3 "l ctrl" 0 10 \
 "glide 3.4 300 652 1350 652 320 722 1250 722 330 792 1200 792 340 863 1100 863; sleep 1.2"

# — quote slide (4): quote block [120,507,902,218] —
rec 10-dotpen 4 "d ctrl" 3 8 \
 "path 1.8 135 740 1010 740; sleep 1.5"

# — whiteboard: rectangle boxes + arrow + pen check —
if want 13-whiteboard; then
say "TAKE 13-whiteboard"
goto 2; ensure on
"$MT" -c "key delete cmd; sleep .3; key w cmd; sleep 1.4; key r ctrl; sleep .4; move 700 1050 0.2"
screencapture -v -V 13 "$CAP/13-whiteboard.mov" 2>>"$LOG" & RW=$!
sleep 1.0
"$MT" -c "drag 600 450 880 620 1.0; sleep .4; drag 1060 450 1340 620 1.0; sleep .4; key 6 ctrl; sleep .3; drag 890 535 1050 535 0.8; sleep .4; key 1 ctrl; sleep .3; path 1.0 1130 700 1180 752 1280 640; sleep 1.4"
wait $RW
mv -f "$CAP/13-whiteboard.mov" "$OUT/13-whiteboard.mov" 2>>"$LOG"
"$MT" -c "key delete cmd; sleep .3; key w cmd; sleep 1.0"
say "OK 13-whiteboard"
fi

# — eraser (2): scribble across the top of the bars, erase it back —
rec 14-eraser 2 "1 ctrl" 0 11 \
 "path 1.4 1090 560 1250 520 1420 560 1590 520 1740 560; sleep .6; key 4 ctrl; sleep .4; path 1.7 1740 560 1590 520 1420 560 1250 520 1090 560; sleep 1.3"

# — blur (5) + cutmove (6): REQUIRE Pointly Screen Recording permission.
# Run explicitly:  ./film-deck.sh 11-blur   /   ./film-deck.sh 12-cutmove
if [ -n "$FILTER" ]; then
rec 11-blur 5 "b ctrl" 2 9 \
 "path 1.8 765 580 1230 580 1230 606 770 606; sleep .5; path 1.4 850 700 1232 700 1232 726 855 726; sleep 1.3"
rec 12-cutmove 6 "m ctrl" 0 12 \
 "drag 108 596 412 722 1.4; sleep 1.0; drag 260 659 900 950 1.5; sleep 1.8"
fi

ensure off
say "shoot finished — clips in $OUT"
ls -la "$OUT"/*.mov 2>/dev/null | tee -a "$LOG"
