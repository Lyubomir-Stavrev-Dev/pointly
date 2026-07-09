#!/bin/bash
# Render title cards + caption overlays (transparent PNGs) via headless Chrome.
# Cards render at 2x (3840x2160) for crispness; ffmpeg scales them down.
# Caption PNGs are keyed by an md5 of the caption text (cap-<hash>.png), so the
# same clip can carry different captions in different cuts.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CARDS="$DIR/cards"
OUT="$CARDS/out"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME" >&2; exit 1; }
mkdir -p "$OUT"

render() { # $1=html path  $2=output png
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size=1920,1080 \
    --default-background-color=00000000 \
    --screenshot="$2" "file://$1" 2>/dev/null
  echo "rendered $(basename "$2")"
}

# 1) Static cards (every cards/*.html except the caption template)
for f in "$CARDS"/*.html; do
  name=$(basename "$f" .html)
  [ "$name" = "caption-template" ] && continue
  render "$f" "$OUT/$name.png"
done

# 2) Caption overlays — one per unique caption across all EDLs
template=$(cat "$CARDS/caption-template.html")
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
for edl in "$DIR"/edl-*.txt; do
  while IFS='|' read -r kind name caption _; do
    [ "$kind" = "clip" ] || continue
    hash=$(md5 -q -s "$caption" | cut -c1-8)
    png="$OUT/cap-$hash.png"
    [ -f "$png" ] && continue
    html="$tmpdir/cap-$hash.html"
    printf '%s' "${template//__CAPTION__/$caption}" > "$html"
    render "$html" "$png"
  done < <(grep -v '^\s*#' "$edl" | grep -v '^\s*$')
done
echo "cards ready in cards/out/"
