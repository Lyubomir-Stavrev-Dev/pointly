#!/bin/bash
# Build a ~30s Instagram Reel showcasing the 3 Pro standalone features:
# Presenter Cues · Presenter Zoom · Countdown Timer
# Uses existing App Store screenshots (shot6/7/9) with Ken Burns effect.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg required: brew install ffmpeg" >&2; exit 1; }

W=1080; H=1920; FPS=30
VID_W=992; VID_H=558; VID_X=44; VID_Y=604
ENC=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r "$FPS")
OUT="$DIR/out"
WORK="$DIR/.work/reel-pro"
PNGS="$DIR/shorts/out"
SHOTS="$DIR/../screenshots/out"

mkdir -p "$OUT" "$WORK" "$PNGS"

render() { # $1=html $2=png
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=$W,$H \
    --default-background-color=00000000 \
    --screenshot="$2" "file://$1" 2>/dev/null
  echo "  rendered $(basename "$2")"
}

frame_html() { # $1=hook html
  cat <<EOF
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:${W}px; height:${H}px; overflow:hidden; }
  body {
    background:#07070f;
    background-image: radial-gradient(700px 500px at 50% -8%, rgba(233,69,140,0.16), transparent 60%),
                      radial-gradient(900px 600px at 50% 112%, rgba(244,100,77,0.20), transparent 62%),
                      linear-gradient(160deg, #12101f 0%, #0a0912 55%, #07070f 100%);
    font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
    position:relative; color:#fff;
  }
  .hook { position:absolute; top:0; left:0; width:${W}px; height:600px;
          display:flex; align-items:center; justify-content:center; text-align:center; padding:0 64px; }
  .hook h1 { font-size:84px; font-weight:800; letter-spacing:-0.02em; line-height:1.14; }
  .hook em { font-style:normal;
             background:linear-gradient(90deg,#F4644D,#FF8C42);
             -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }
  .window { position:absolute; left:40px; top:600px; width:1000px; height:566px; border-radius:10px;
            background:linear-gradient(120deg,#F4644D,#FF8C42,#E9458C);
            box-shadow:0 30px 90px rgba(244,100,77,0.28); }
  .brand { position:absolute; left:0; bottom:130px; width:${W}px;
           display:flex; flex-direction:column; align-items:center; }
  .brand img { width:128px; height:128px; border-radius:30px;
               box-shadow:0 18px 60px rgba(244,100,77,0.35); margin-bottom:26px; }
  .name { font-size:54px; font-weight:800;
          background:linear-gradient(90deg,#F4644D,#FF8C42);
          -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }
  .cta  { font-size:33px; font-weight:700; color:#fff; margin-top:16px; }
  .url  { font-size:25px; font-weight:600; color:rgba(255,255,255,0.55); margin-top:10px; letter-spacing:0.02em; }
</style></head>
<body>
  <div class="hook"><h1>$1</h1></div>
  <div class="window"></div>
  <div class="brand">
    <img src="../cards/icon.png" alt="">
    <div class="name">Pointly</div>
    <div class="cta">Free on the Mac App Store</div>
    <div class="url">trypointly.com</div>
  </div>
</body></html>
EOF
}

caption_html() { # $1=caption text
  cat <<EOF
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:${W}px; height:${H}px; overflow:hidden; background:transparent; }
  body { font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
         display:flex; align-items:flex-start; justify-content:center; padding-top:1226px; }
  .pill { display:flex; align-items:center; gap:18px;
          background:rgba(7,7,15,0.82); border:1px solid rgba(255,255,255,0.10);
          border-radius:20px; padding:22px 36px; box-shadow:0 18px 60px rgba(0,0,0,0.45); }
  .tick { width:10px; height:40px; border-radius:5px; flex:none;
          background:linear-gradient(180deg,#F4644D,#FF8C42); }
  .txt  { font-size:38px; font-weight:700; color:#fff; letter-spacing:-0.01em; white-space:nowrap; }
</style></head>
<body><div class="pill"><div class="tick"></div><div class="txt">$1</div></div></body></html>
EOF
}

build_seg() {
  local name="$1" hook="$2" caption="$3" shot="$4" dur="${5:-10}" zpx="${6:-0.00020}"

  echo "==> segment: $name"
  local frame="$PNGS/frame-pro-${name}.png"
  frame_html "$hook" > "$WORK/frame-${name}.html"
  render "$WORK/frame-${name}.html" "$frame"

  local hash; hash=$(md5 -q -s "$caption" | cut -c1-8)
  local cap="$PNGS/vcap-${hash}.png"
  if [ ! -f "$cap" ]; then
    caption_html "$caption" > "$WORK/vcap-${hash}.html"
    render "$WORK/vcap-${hash}.html" "$cap"
  fi

  local frames=$(( dur * FPS ))
  local capout; capout=$(awk -v d="$dur" 'BEGIN{printf "%.2f", d-0.55}')
  local vfout;  vfout=$(awk -v d="$dur"  'BEGIN{printf "%.2f", d-0.12}')
  local seg="$WORK/${name}.mp4"

  ffmpeg -nostdin -v error -y \
    -loop 1 -i "$frame" \
    -loop 1 -i "$SHOTS/$shot" \
    -loop 1 -i "$cap" \
    -filter_complex "
      [0:v]scale=${W}:${H},fps=${FPS},setsar=1[bg];
      [1:v]scale=1440:-2,
           zoompan=z='min(1+in*${zpx},1.10)':d=${frames}:x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':s=${VID_W}x${VID_H}:fps=${FPS},
           setsar=1,fade=t=in:st=0:d=0.18,fade=t=out:st=${vfout}:d=0.18[vid];
      [2:v]scale=${W}:${H},fps=${FPS},format=rgba,
           fade=t=in:st=0.30:d=0.35:alpha=1,fade=t=out:st=${capout}:d=0.40:alpha=1[cap];
      [bg][vid]overlay=${VID_X}:${VID_Y}[t];
      [t][cap]overlay=0:0,format=yuv420p[v]
    " \
    -map "[v]" -an -t "$dur" "${ENC[@]}" "$seg"

  echo "$name: ${dur}s done"
}

: > "$WORK/list.txt"

# 3 segments × 10s each = 30s reel (crossfades will trim ~1s at each join → ~28.5s final)
build_seg "cues"  \
  "Every click. Every key. <em>On screen.</em>" \
  "Presenter Cues — click ripples + keystrokes" \
  "shot6.png" 10 "0.00018"

build_seg "zoom" \
  "Freeze the screen. <em>Zoom into any detail.</em>" \
  "Presenter Zoom — freeze &amp; magnify live" \
  "shot9.png" 10 "0.00012"

build_seg "timer" \
  "Keep everyone <em>on time.</em>" \
  "Countdown Timer — 5, 10, 15 min presets" \
  "shot7.png" 10 "0.00022"

echo "==> Assembling final reel..."
# offset1 = 10 - 0.75 = 9.25  (cues→zoom crossfade)
# offset2 = 10 + 10 - 2×0.75 = 18.5  (zoom→timer crossfade)
ffmpeg -nostdin -v error -y \
  -i "$WORK/cues.mp4" \
  -i "$WORK/zoom.mp4" \
  -i "$WORK/timer.mp4" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=0.75:offset=9.25[v01];
    [v01][2:v]xfade=transition=fade:duration=0.75:offset=18.50[vout];
    anullsrc=channel_layout=stereo:sample_rate=48000[aout]
  " \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r "$FPS" \
  -c:a aac -b:a 128k -t 28.75 \
  "$OUT/reel-pro-features-9x16.mp4"

echo ""
echo "Done: $OUT/reel-pro-features-9x16.mp4"
ffprobe -v error -show_entries format=duration,size -of default "$OUT/reel-pro-features-9x16.mp4"
