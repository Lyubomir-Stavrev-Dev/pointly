#!/bin/bash
# Assemble a finished marketing video from raw screen recordings + branded cards.
#
#   ./assemble.sh appstore   -> out/appstore-preview-1920x1080.mp4  (15-30s enforced warning)
#   ./assemble.sh ad45       -> out/ad45-16x9.mp4 + ad45-1x1.mp4 + ad45-9x16.mp4
#   ./assemble.sh ad15       -> out/ad15-16x9.mp4 + ad15-1x1.mp4 + ad15-9x16.mp4
#
# Reads edl-<cut>.txt. Raw clips live in raw/, cards in cards/ (rendered on demand).
# Optional music: drop music.mp3 / music.m4a / music.wav next to this script.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CUT="${1:-}"
[ -n "$CUT" ] || { echo "usage: $0 <appstore|ad45|ad15>" >&2; exit 1; }
EDL="$DIR/edl-$CUT.txt"
[ -f "$EDL" ] || { echo "no such cut: $EDL" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg required: brew install ffmpeg" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe required: brew install ffmpeg" >&2; exit 1; }

W=1920; H=1080; FPS=30; BG="0x07070f"
ENC=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r "$FPS")
OUT="$DIR/out"; WORK="$DIR/.work/$CUT"; CARDPNG="$DIR/cards/out"
rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"

bash "$DIR/render-cards.sh"

probe_dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
fmin() { awk -v a="$1" -v b="$2" 'BEGIN{print (a<b)?a:b}'; }
fsub() { awk -v a="$1" -v b="$2" 'BEGIN{v=a-b; if(v<0)v=0; print v}'; }

i=0
LIST="$WORK/list.txt"; : > "$LIST"
while IFS='|' read -r kind name caption maxdur; do
  i=$((i+1)); seg="$WORK/$(printf '%03d' "$i").mp4"
  if [ "$kind" = "card" ]; then
    dur="$caption"  # for card lines the 3rd field is the duration
    png="$CARDPNG/$name.png"
    [ -f "$png" ] || { echo "missing card: $png" >&2; exit 1; }
    fo=$(fsub "$dur" 0.3)
    ffmpeg -nostdin -v error -y -loop 1 -t "$dur" -i "$png" -filter_complex \
      "[0:v]scale=$W:$H,fps=$FPS,fade=t=in:st=0:d=0.25,fade=t=out:st=$fo:d=0.3,format=yuv420p[v]" \
      -map "[v]" -an "${ENC[@]}" "$seg"
  elif [ "$kind" = "clip" ]; then
    src="$DIR/raw/$name.mov"
    [ -f "$src" ] || src="$DIR/raw/$name.mp4"
    [ -f "$src" ] || { echo "missing clip: raw/$name.mov (see recording-guide.md)" >&2; exit 1; }
    clipdur=$(probe_dur "$src")
    # head-trim: skip recorder pre-roll so the clip starts on the action
    case "$name" in
      00-problem) head=1.6 ;;
      01-summon)  head=1.4 ;;
      *)          head=1.9 ;;
    esac
    avail=$(fsub "$clipdur" "$head")
    dur=$avail
    [ -n "${maxdur:-}" ] && dur=$(fmin "$avail" "$maxdur")
    hash=$(md5 -q -s "$caption" | cut -c1-8)
    cap="$CARDPNG/cap-$hash.png"
    [ -f "$cap" ] || { echo "missing caption overlay: $cap (run render-cards.sh)" >&2; exit 1; }
    capout=$(fsub "$dur" 0.55)
    vfout=$(fsub "$dur" 0.12)
    ffmpeg -nostdin -v error -y -ss "$head" -i "$src" -loop 1 -i "$cap" -filter_complex \
      "[0:v]scale=$W:$H:force_original_aspect_ratio=decrease,pad=$W:$H:(ow-iw)/2:(oh-ih)/2:color=$BG,fps=$FPS,setsar=1,fade=t=in:st=0:d=0.12,fade=t=out:st=$vfout:d=0.12[base];
       [1:v]scale=$W:$H,format=rgba,fade=t=in:st=0.25:d=0.35:alpha=1,fade=t=out:st=$capout:d=0.4:alpha=1[cap];
       [base][cap]overlay=0:0,format=yuv420p[v]" \
      -map "[v]" -an -t "$dur" "${ENC[@]}" "$seg"
  else
    echo "bad EDL line kind: $kind" >&2; exit 1
  fi
  echo "file '$seg'" >> "$LIST"
  echo "segment $i: $kind $name (${dur}s)"
done < <(grep -v '^\s*#' "$EDL" | grep -v '^\s*$')

MASTER="$WORK/master-video.mp4"
ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$LIST" -c copy "$MASTER"
TOTAL=$(probe_dur "$MASTER")
echo "total duration: ${TOTAL}s"

if [ "$CUT" = "appstore" ]; then
  awk -v t="$TOTAL" 'BEGIN{ if (t<15 || t>30) print "WARNING: App Store previews must be 15-30s — currently " t "s. Adjust edl-appstore.txt." }'
fi

# --- audio ---
MUSIC=""
for ext in mp3 m4a wav; do [ -f "$DIR/music.$ext" ] && MUSIC="$DIR/music.$ext" && break; done
FINAL_169="$WORK/final-16x9.mp4"
AFADE=$(fsub "$TOTAL" 1.4)
if [ -n "$MUSIC" ]; then
  echo "mixing music: $(basename "$MUSIC")"
  ffmpeg -nostdin -v error -y -i "$MASTER" -stream_loop -1 -i "$MUSIC" -map 0:v -map 1:a \
    -af "afade=t=in:st=0:d=0.5,afade=t=out:st=$AFADE:d=1.4" \
    -c:v copy -c:a aac -b:a 256k -ar 48000 -ac 2 -shortest "$FINAL_169"
else
  echo "no music.{mp3,m4a,wav} found — adding silent stereo track (required for App Store upload)"
  ffmpeg -nostdin -v error -y -i "$MASTER" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
    -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "$FINAL_169"
fi

# --- exports ---
if [ "$CUT" = "appstore" ]; then
  cp "$FINAL_169" "$OUT/appstore-preview-1920x1080.mp4"
  echo "==> out/appstore-preview-1920x1080.mp4"
else
  cp "$FINAL_169" "$OUT/$CUT-16x9.mp4"
  ffmpeg -nostdin -v error -y -i "$FINAL_169" -vf "scale=1080:-2,pad=1080:1080:(ow-iw)/2:(oh-ih)/2:color=$BG" \
    -c:a copy "${ENC[@]}" "$OUT/$CUT-1x1.mp4"
  ffmpeg -nostdin -v error -y -i "$FINAL_169" -vf "scale=1080:-2,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=$BG" \
    -c:a copy "${ENC[@]}" "$OUT/$CUT-9x16.mp4"
  echo "==> out/$CUT-16x9.mp4, out/$CUT-1x1.mp4, out/$CUT-9x16.mp4"
fi
