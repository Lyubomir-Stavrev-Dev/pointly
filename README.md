# Pointly

A screen annotation tool for macOS — floating toolbar, live drawing, spotlight, and more.

## Download

[![Download](https://img.shields.io/badge/⬇%20Download-Pointly%20v1.1.0-FF6B6B?style=for-the-badge)](https://github.com/Lyubomir-Stavrev-Dev/pointly/releases/latest/download/Pointly-v1.1.0.zip)

> **macOS 14+** · Unzip → drag **Pointly.app** to `/Applications`
>
> On first launch macOS may say "unidentified developer" — go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## Features

| Tool | What it does |
|---|---|
| **Pen** | Smooth freehand drawing |
| **Highlighter** | Semi-transparent highlight |
| **Marker** | Textured marker strokes |
| **Eraser** | Remove annotations |
| **Laser Pointer** | Animated glow pointer that fades |
| **Spotlight** | Darkens screen except cursor area |
| **Text** | Click to place text labels |
| **Shapes** | Rectangle, ellipse, triangle, diamond — outline or filled |
| **Arrow / Line** | Straight arrows and lines |
| **Select** | Rubber-band select, move, resize, delete |
| **Cursor** | Click through the overlay to apps behind |

- Adaptive **Size Bar** — controls thickness, blur radius, spotlight size, or font size depending on the active tool
- **Undo / Redo** — full history
- **Export** — PNG, PDF, or JPEG
- Toggle overlay with **⌘⇧P** or the menu bar icon
- **Escape** toggles Draw ↔ Interact mode
- **Backspace** deletes selected annotations

## Requirements

- macOS 14.0 (Sonoma) or later
- Screen Recording permission (prompted on first launch)

## Build from source

```bash
git clone https://github.com/Lyubomir-Stavrev-Dev/pointly.git
cd pointly
bash create_app_bundle.sh
open Pointly.app
```

## License

Copyright © 2024 Pointly. All rights reserved.
