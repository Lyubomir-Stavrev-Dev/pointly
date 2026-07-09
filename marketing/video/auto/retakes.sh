#!/bin/bash
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
LOG="$DIR/retakes.log"; : > "$LOG"
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# close System Settings so it's not in frame
SPID=$(pgrep -x "System Settings" | head -1 || true)
if [ -n "${SPID:-}" ]; then ./mousetool -c "activate $SPID; sleep 0.6; key q cmd; sleep 1.0" >>"$LOG" 2>&1; fi

# relaunch Pointly so the new screen-recording grant applies
pkill -x Pointly 2>/dev/null; sleep 1.2
open "$DIR/../../../Pointly.app"; sleep 2.5

stage() { echo "$1" > "$DIR/stage/state.txt"; sleep 2.0; }
take() { say "TAKE $1"; if ./film.sh "$1" "clips/$1.txt" "$2" "${3:-on}" >>"$LOG" 2>&1; then say "OK $1"; else say "FAIL $1"; fi; }

stage slide.html
take 01-summon 8 off
take 08-cutmove 11 on
./mousetool -c "key esc -; sleep 0.5; key delete cmd; sleep 0.5" >>"$LOG" 2>&1
stage doc.html
take 03-highlight 10 on
# teardown
stage slide.html
./mousetool -c "key delete cmd; sleep 0.5; key p cmd+shift; sleep 1.0" >>"$LOG" 2>&1
say "retakes finished"
