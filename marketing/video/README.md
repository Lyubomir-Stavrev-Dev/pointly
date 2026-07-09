# Pointly marketing videos

Everything needed to produce the App Store preview and ad videos. Three steps:

1. **Record** the raw clips (~30–45 min) — follow `recording-guide.md`, drop trimmed clips into `raw/`.
2. **(Optional) Music** — drop a licensed track as `music.mp3` (or `.m4a`/`.wav`) here.
3. **Assemble:**
   ```bash
   brew install ffmpeg   # one-time
   ./assemble.sh appstore   # 27s App Store preview, 1920x1080
   ./assemble.sh ad45       # main ad in 16:9 + 1:1 + 9:16
   ./assemble.sh ad15       # 15s paid-social cutdown in 16:9 + 1:1 + 9:16
   ```
   Finished files land in `out/`.

## What's what

| File | Purpose |
|---|---|
| `script-appstore-preview.md` | Shot-by-shot storyboard for the App Store preview + Apple's rules |
| `script-ad.md` | 45s ad + 15s cutdown storyboards + platform notes |
| `recording-guide.md` | Screen-recording setup and exactly what to perform per clip |
| `edl-*.txt` | Edit decision lists — order, captions, durations. Edit these to re-cut without touching scripts |
| `cards/*.html` | Branded title cards + caption overlay template (Pointly dark + orange gradient) |
| `render-cards.sh` | Renders cards/captions to PNG via headless Chrome (called automatically) |
| `assemble.sh` | ffmpeg pipeline: normalizes clips, overlays captions, fades, concats, mixes music, exports all formats |

## Re-cutting
Change a caption or clip length → edit the matching `edl-*.txt` line and re-run `assemble.sh`. Caption overlays regenerate automatically. Cards are plain HTML — tweak `cards/outro.html` etc. and re-run.

## Uploading
- **App Store Connect:** version page → App Previews → upload `out/appstore-preview-1920x1080.mp4`, then set the **poster frame** to the Spotlight moment. Previews go through review with the build.
- **Ads:** 16:9 → YouTube/web, 1:1 → feeds, 9:16 → Reels/TikTok/Shorts. Set the platform CTA button to "Download" with the Mac App Store link.
