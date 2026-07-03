#!/bin/bash
# Render each shot*.html to a 2880×1800 PNG (Mac App Store Retina size).
set -e
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/out"

shots=("$@")
if [ ${#shots[@]} -eq 0 ]; then
  shots=($(ls "$DIR"/shot*.html))
fi

for f in "${shots[@]}"; do
  name=$(basename "$f" .html)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=1440,900 \
    --default-background-color=00000000 \
    --screenshot="$DIR/out/$name.png" "file://$DIR/$name.html" 2>/dev/null
  echo "rendered $name.png -> $(sips -g pixelWidth -g pixelHeight "$DIR/out/$name.png" 2>/dev/null | grep pixel | tr '\n' ' ')"
done
