# Pointly — App Store screenshots

Rendered PNGs are in `out/` at **2880×1800** (Mac App Store Retina size, 16:10).
Sources are the `shot*.html` files; regenerate with `./render.sh` (uses headless
Chrome at 2× device scale). Edit `style.css` for shared styling.

## Upload order & captions (App Store Connect)

| # | File | Theme | Suggested caption |
|---|------|-------|-------------------|
| 1 | `out/shot1.png` | Hero — annotate live | Draw, highlight, and mark up on top of any app in real time. |
| 2 | `out/shot2.png` | Tools & shortcuts | Every tool a single keystroke away. |
| 3 | `out/shot3.png` | Spotlight & laser (Pro) | Focus every eye with Spotlight and the laser pointer. |
| 4 | `out/shot4.png` | Cut & Move (Pro) | Lift any region of your screen and reposition it. |
| 5 | `out/shot5.png` | Whiteboard (Pro) | A full-screen grid canvas whenever you need one. |

The first two screenshots do most of the selling — Apple shows them first in
search and on the product page. Keep that order.

## Notes
- Designed at 1440×900 CSS px; `render.sh` outputs at 2× → 2880×1800.
- Toolbar, tooltip, colors, and tools mirror the real app UI.
- To tweak copy or layout, edit the `.html`, then `./render.sh shotN.html`.
