# App Store Listing Copy — Pointly (ASC name: "Pointly Annotate")

Paste-ready metadata for App Store Connect. Character limits noted.

## ASO package (submit with the next version — name/subtitle/keywords are version-bound)

How ranking works: relevance (name > subtitle > keyword field; words are NOT
double-counted across fields) × performance (downloads velocity, ratings,
conversion). Metadata below maximizes relevance; PH launch + review prompts
drive performance.

**App name (30 max, highest keyword weight)** — current "Pointly Annotate" wastes 14 chars:
```
Pointly Annotate: Screen Draw
```
(29 — adds "screen" + "draw", the two highest-traffic terms, into the strongest field)

**Subtitle (30 max, second-highest weight)** — pick one, no words repeated from the name:
```
Laser pointer & spotlight live
```
(30) — or `Highlight & present anywhere` (28)

**Keywords (100 max)** — no words already in name/subtitle, no spaces after commas:
```
highlight,marker,pen,whiteboard,presentation,teaching,demo,markup,blur,recording,arrow,notes
```
(92 — 8 chars spare; consider adding `,zoom` if relevant)

**Also with the next version:**
- Upload the App Store preview video (`marketing/video/out/appstore-preview-1920x1080.mp4`) — video listings convert measurably better, and conversion feeds ranking.
- Reorder screenshots so the strongest (spotlight/draw) is first.

**Anytime (no review needed):**
- Promotional text — keep fresh with launches/updates.
- IAP prices → €12.99 / €39.99 (pending).

**Later, high-leverage:** localized metadata (DE, FR, ES, IT — even just name/subtitle/keywords) indexes extra keywords per storefront; big for the freshly unlocked EU.

**Performance levers (the other half):**
- ReviewManager already prompts after repeated use ✓ — early ratings matter most; a handful of honest 5★ from real users in week 1 moves rank visibly.
- Product Hunt launch → install spike → velocity signal.
- Respond to every App Store review (visible, improves conversion).

## Promotional Text (max 170)
Annotate anything on your screen — draw, highlight, spotlight, and point live. Perfect for demos, teaching, presentations, and screen recordings.

## Description
Pointly turns your entire screen into a canvas. Draw, highlight, and point at anything, live over any app — perfect for demos, online teaching, presentations, tutorials, and screen recordings.

FREE TOOLS
• Pen & arrows — draw and point anywhere on screen
• Highlighter — emphasize what matters
• Shapes & lines — clean rectangles, ellipses, and lines
• Quick clear & undo/redo

POINTLY PRO
• Blur Brush — hide sensitive info on the fly
• Laser Pointer — a glowing live pointer for presentations
• Spotlight — dim everything except your focus
• Dot Pen — smooth dotted emphasis
• Cut & Move — grab any part of the screen and reposition it
• Whiteboard Canvas — a full drawing surface

Pointly lives in your menu bar and stays out of the way until you need it. A global hotkey brings the overlay up instantly over whatever you're doing.

Upgrade to Pro once (lifetime) or subscribe annually.

POINTLY PRO SUBSCRIPTION
• Pointly Pro (annual): €12.99/year, auto-renews yearly until cancelled
• Pointly Pro+ (lifetime): €39.99 one-time purchase
Payment is charged to your Apple ID account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in App Store account settings.

Privacy Policy: https://trypointly.com/privacy
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Reply to App Review (rejection 3a09b983, Guideline 3.1.2c)
Paste in ASC → App Review message thread after updating the description:

> Hello, thank you for the review. We have updated the App Store metadata: the App Description now includes a functional link to the standard Apple Terms of Use (EULA) (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) alongside our Privacy Policy link, plus the subscription title, length, and price. The app itself already displays the subscription title, length, price, and functional Privacy Policy and Terms of Use links on the purchase screen. Please let us know if anything else is needed.

## Keywords (max 100, comma-separated, no spaces after commas)
annotate,screen,draw,highlight,spotlight,laser pointer,presentation,teaching,markup,whiteboard

## Support URL
https://trypointly.com/support

## Marketing URL
https://trypointly.com

## Notes
- Pro tools verified against `ProManager.proTools` (blurBrush, laserPointer, spotlight, dotPen, cutMove) + Whiteboard Canvas (gated separately via `isWhiteboardCanvas` in ProPaywallView).
- IAP: Pro Lifetime $39.99 (non-consumable), Pro Annual $12.99/yr.
