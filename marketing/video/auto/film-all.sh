#!/bin/bash
# Batch-film all clips unattended. ~10 minutes. Do not touch mouse/keyboard while running.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
LOG="$DIR/film-all.log"
: > "$LOG"
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

stage() { echo "$1" > "$DIR/stage/state.txt"; sleep 2.0; }
take() { # name script secs overlay
  say "TAKE $1"
  if ./film.sh "$1" "clips/$1.txt" "$3" "${4:-on}" >> "$LOG" 2>&1; then say "OK  $1"; else say "FAIL $1"; fi
}

say "shoot started"
stage slide.html
take 00-problem 00-problem.txt 8 off
take 01-summon  01-summon.txt  8 off
take 02-draw    02-draw.txt    10 on
take 10-clear   10-clear.txt   9 on
take 04-shapes  04-shapes.txt  9 on
take 05-spotlight 05-spotlight.txt 10 on
take 06-laser   06-laser.txt   10 on
stage doc.html
take 03-highlight 03-highlight.txt 9 on
stage secrets.html
take 07-blur    07-blur.txt    9 on
stage slide.html
take 08-cutmove 08-cutmove.txt 11 on
# cut&move leaves a lifted panel; try to dismiss before whiteboard
./mousetool -c "key delete cmd; sleep 0.6; key esc -; sleep 0.6" >> "$LOG" 2>&1
take 09-whiteboard 09-whiteboard.txt 13 on
# teardown: exit whiteboard, clear, hide overlay
./mousetool -c "key w cmd; sleep 1.2; key delete cmd; sleep 0.5; key p cmd+shift; sleep 1.0" >> "$LOG" 2>&1
say "shoot finished"
ls -la "$DIR/../raw/" | tee -a "$LOG"
