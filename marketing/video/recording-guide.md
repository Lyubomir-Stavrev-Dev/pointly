# Recording guide — capturing the raw clips

Every clip is a plain screen recording of you actually using Pointly. Total shoot time: ~30–45 min.

## One-time setup (10 min)
1. **Display:** if possible set your display to a 16:9 resolution (e.g. 1920×1080 or 3840×2160 scaled). Retina is fine — the pipeline downscales, which makes footage extra crisp. Non-16:9 (MacBook 16:10) also works; the pipeline pads with the brand dark color, but 16:9 looks best.
2. **Clean the stage:** hide desktop icons (`defaults write com.apple.finder CreateDesktopIcons false; killall Finder` — revert after with `true`), auto-hide the Dock, close notification-heavy apps, enable **Do Not Disturb**.
3. **Menu bar:** keep it minimal — Pointly's icon should be easy to spot in `01-summon`.
4. **Cursor size:** System Settings → Accessibility → Display → bump pointer size slightly (~1.5×). Viewers must be able to follow it.
5. **Stage content** (what's behind the overlay — make it look real, not lorem ipsum):
   - A good-looking slide (Keynote, full screen) with a bar chart + a few bullets — used in most shots.
   - A doc or webpage with real-looking text — for the highlighter.
   - A fake "settings/email" view showing an email address or API key — for blur brush.
6. **Recorder:** QuickTime → File → New Screen Recording → record **entire screen**, no microphone. (Or `screencapture -v ~/Desktop/clip.mov`, stop with Ctrl-C.)

## How to perform
- Move the mouse **slower than feels natural** — smooth arcs, no jitter, brief pause before and after each stroke.
- Record each clip a couple of seconds longer than needed, then trim head/tail in QuickTime (⌘T) so the action starts almost immediately.
- One action per clip. If you fumble, just re-record — clips are 5 seconds each.
- Save/trim each clip into `marketing/video/raw/` with these exact names:

| File | Action to perform |
|---|---|
| `00-problem.mov` | (Ad only) Pointly OFF. On the slide, circle a number frantically with the plain cursor for ~4s. |
| `01-summon.mov` | Slide visible → press the global hotkey (or click the menu-bar icon) → overlay activates, wiggle the brand cursor once. |
| `02-draw.mov` | Pen: circle the chart's key number, then draw an arrow pointing at it. |
| `03-highlight.mov` | Highlighter: sweep across one key sentence in the doc. |
| `04-shapes.mov` | (Spare) Rectangle around a UI region, then an ellipse. |
| `05-spotlight.mov` | Spotlight: dim everything except the chart region. Hold ~2s. |
| `06-laser.mov` | Laser pointer: sweep down the slide's bullets, settle on the last one. |
| `07-blur.mov` | Blur brush: paint over the email/API key until unreadable. |
| `08-cutmove.mov` | Cut & Move: select the chart, let it lift, drag it to the other side of the screen. |
| `09-whiteboard.mov` | Whiteboard canvas: quickly sketch a 3-box flow with arrows. |
| `10-clear.mov` | With several annotations on screen, trigger Clear All. |

## Then assemble
```bash
cd marketing/video
./assemble.sh appstore   # → out/appstore-preview-1920x1080.mp4
./assemble.sh ad45       # → out/ad45-16x9.mp4, ad45-1x1.mp4, ad45-9x16.mp4
./assemble.sh ad15       # → out/ad15-16x9.mp4, ad15-1x1.mp4, ad15-9x16.mp4
```
Requires ffmpeg (`brew install ffmpeg`) and Chrome (already installed — used to render the branded cards).
Optional: drop a `music.mp3` (or `.m4a`/`.wav`) into `marketing/video/` and it gets mixed in with a fade-out automatically.
