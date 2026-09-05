#!/bin/bash
# One-off short: Laser + Number Stamps
# Timestamps: 00:04 laser | 00:14 orange numbers | 00:20 purple numbers | 00:26 end
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W=1080; H=1920; FPS=30
VID_W=992; VID_H=558; VID_X=44; VID_Y=604
ENC=(-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r "$FPS")
WORK="$DIR/.work/laser-nums"; SHORTS="$DIR/shorts"; PNGS="$SHORTS/out"
mkdir -p "$WORK" "$SHORTS" "$PNGS"
SRC="/Users/lyubomirstavrev/Desktop/laser_and_nums.mp4"
OUT="$DIR/out/short-laser-nums-9x16.mp4"

render() { # $1=html $2=png
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=$W,$H \
    --default-background-color=00000000 \
    --screenshot="$2" "file://$1" 2>/dev/null
  echo "rendered $(basename "$2")"
}

# --- Frame ---
FRAME_HTML="$SHORTS/frame-laser-nums.html"
cat > "$FRAME_HTML" <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:1080px; height:1920px; overflow:hidden; }
  body {
    background:#07070f;
    background-image: radial-gradient(700px 500px at 50% -8%, rgba(233,69,140,0.16), transparent 60%),
                      radial-gradient(900px 600px at 50% 112%, rgba(244,100,77,0.20), transparent 62%),
                      linear-gradient(160deg, #12101f 0%, #0a0912 55%, #07070f 100%);
    font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
    position:relative; color:#fff;
  }
  .hook { position:absolute; top:0; left:0; width:1080px; height:600px;
          display:flex; align-items:center; justify-content:center; text-align:center; padding:0 64px; }
  .hook h1 { font-size:84px; font-weight:800; letter-spacing:-0.02em; line-height:1.14; }
  .hook em { font-style:normal;
             background:linear-gradient(90deg,#F4644D,#FF8C42);
             -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }
  .window { position:absolute; left:40px; top:600px; width:1000px; height:566px; border-radius:10px;
            background:linear-gradient(120deg,#F4644D,#FF8C42,#E9458C);
            box-shadow:0 30px 90px rgba(244,100,77,0.28); }
  .brand { position:absolute; left:0; bottom:130px; width:1080px;
           display:flex; flex-direction:column; align-items:center; }
  .brand img { width:128px; height:128px; border-radius:30px;
               box-shadow:0 18px 60px rgba(244,100,77,0.35); margin-bottom:26px; }
  .name { font-size:54px; font-weight:800;
          background:linear-gradient(90deg,#F4644D,#FF8C42);
          -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }
  .cta { font-size:33px; font-weight:700; color:#fff; margin-top:16px; }
  .url { font-size:25px; font-weight:600; color:rgba(255,255,255,0.55); margin-top:10px; letter-spacing:0.02em; }
</style></head>
<body>
  <div class="hook"><h1>Laser focus. <em>Numbered steps.</em></h1></div>
  <div class="window"></div>
  <div class="brand"><img src="../cards/icon.png" alt="">
    <div class="name">Pointly</div>
    <div class="cta">Free on the Mac App Store</div>
    <div class="url">trypointly.com</div>
  </div>
</body></html>
EOF
FRAME_PNG="$PNGS/frame-laser-nums.png"
render "$FRAME_HTML" "$FRAME_PNG"

# --- Captions ---
cap_html() { # $1=text $2=outfile
  cat > "$2" <<CAPEOF
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:1080px; height:1920px; overflow:hidden; background:transparent; }
  body { font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;
         display:flex; align-items:flex-start; justify-content:center; padding-top:1226px; }
  .pill { display:flex; align-items:center; gap:18px;
          background:rgba(7,7,15,0.82); border:1px solid rgba(255,255,255,0.10);
          border-radius:20px; padding:22px 36px; box-shadow:0 18px 60px rgba(0,0,0,0.45); }
  .tick { width:10px; height:40px; border-radius:5px; flex:none;
          background:linear-gradient(180deg,#F4644D,#FF8C42); }
  .txt { font-size:38px; font-weight:700; color:#fff; letter-spacing:-0.01em; white-space:nowrap; }
</style></head>
<body><div class="pill"><div class="tick"></div><div class="txt">$1</div></div></body></html>
CAPEOF
}

cap_html "Laser Pointer — live on screen."  "$SHORTS/vcap-ln-laser.html"
cap_html "Orange Number Stamps."            "$SHORTS/vcap-ln-orange.html"
cap_html "Purple Number Stamps."            "$SHORTS/vcap-ln-purple.html"
render "$SHORTS/vcap-ln-laser.html"  "$PNGS/vcap-ln-laser.png"
render "$SHORTS/vcap-ln-orange.html" "$PNGS/vcap-ln-orange.png"
render "$SHORTS/vcap-ln-purple.html" "$PNGS/vcap-ln-purple.png"

# --- Compose ---
# cap fade in/out 0.35s; sections: laser 4-14s, orange 14-20s, purple 20-26.57s
ffmpeg -nostdin -v error -y \
  -loop 1 -i "$FRAME_PNG" \
  -i "$SRC" \
  -loop 1 -i "$PNGS/vcap-ln-laser.png" \
  -loop 1 -i "$PNGS/vcap-ln-orange.png" \
  -loop 1 -i "$PNGS/vcap-ln-purple.png" \
  -filter_complex "
    [0:v]scale=${W}:${H},fps=${FPS},setsar=1[bg];
    [1:v]scale=${VID_W}:${VID_H}:force_original_aspect_ratio=increase,crop=${VID_W}:${VID_H},fps=${FPS},setsar=1[vid];
    [2:v]scale=${W}:${H},fps=${FPS},format=rgba,
         fade=t=in:st=4.0:d=0.35:alpha=1,fade=t=out:st=13.65:d=0.35:alpha=1[cap1];
    [3:v]scale=${W}:${H},fps=${FPS},format=rgba,
         fade=t=in:st=14.0:d=0.35:alpha=1,fade=t=out:st=19.65:d=0.35:alpha=1[cap2];
    [4:v]scale=${W}:${H},fps=${FPS},format=rgba,
         fade=t=in:st=20.0:d=0.35:alpha=1,fade=t=out:st=26.2:d=0.35:alpha=1[cap3];
    [bg][vid]overlay=${VID_X}:${VID_Y}[t1];
    [t1][cap1]overlay=0:0[t2];
    [t2][cap2]overlay=0:0[t3];
    [t3][cap3]overlay=0:0,format=yuv420p[v]
  " \
  -map "[v]" -map 1:a -c:a aac -b:a 192k -t 26.57 "${ENC[@]}" "$OUT"

echo "==> $(basename "$OUT")"
open -R "$OUT"
