# App Store Preview — 27s storyboard

**Format:** 1920×1080, H.264, 30 fps, 15–30 s (Apple hard limit). Up to 3 previews per listing; this is Preview #1.
**Apple rules that matter:** footage must be primarily captured from the app itself; no hands, no people, no device frames; short text overlays are fine; the video autoplays **muted**, so it must work without sound. The **poster frame** (you pick it in App Store Connect) should be the most visually striking moment — use the Spotlight shot.

## Beat sheet

| # | Clip (`raw/`) | Dur | On screen | Caption overlay |
|---|---|---|---|---|
| 1 | `01-summon.mov` | 3.0s | A busy slide deck / dashboard. Menu-bar icon clicks (or hotkey), Pointly overlay activates, cursor becomes the glowing brand cursor. | One hotkey. Draw over anything. |
| 2 | `02-draw.mov` | 4.0s | Pen circles a number on a chart, then an arrow snaps toward it. Confident, smooth strokes in brand orange. | Point at what matters — live. |
| 3 | `03-highlight.mov` | 3.0s | Highlighter sweeps across a key sentence in a doc/webpage. | Highlight anything, in any app. |
| 4 | `05-spotlight.mov` | 3.5s | Spotlight dims the whole screen except one region. **Hero shot — poster frame here.** | Spotlight your focus. |
| 5 | `06-laser.mov` | 3.0s | Glowing laser pointer sweeps across slide bullets. | Present like it's a stage. |
| 6 | `07-blur.mov` | 3.0s | Blur brush wipes over an email address / API key before a demo. | Hide sensitive info instantly. |
| 7 | `08-cutmove.mov` | 4.0s | Cut & Move: select a region of the screen, it lifts off and gets repositioned. The "wait, what?" moment. | Grab your screen. Move it. |
| 8 | outro card | 2.5s | Dark brand card: icon + "Pointly" + gradient rule + "Free on the Mac App Store". | — |

**Total: ~26s** (safe inside the 30s limit; ffmpeg pipeline warns if you drift out of 15–30s).

## Direction notes
- Start with footage, not a logo — the first frame is what people see in search results.
- Every caption is a benefit, not a feature name. Sound-off first: the captions ARE the narration.
- Keep mouse movement slow and intentional; hesitant cursors read as bugs.
- Music: light, rhythmic, modern (no vocals). Cut beats 1→2 and 6→7 on the beat if possible.

## Previews #2 and #3 (optional, later)
- #2 "Teach": whiteboard canvas + shapes + undo/clear — aimed at teachers.
- #3 "Pro tools": 15s all-Pro montage (blur, spotlight, laser, cut & move) — doubles as an IAP explainer.
