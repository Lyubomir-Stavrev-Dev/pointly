# Pointly

A premium cross-platform annotation & presentation tool for macOS.

## Overview

Pointly enables smooth, professional screen annotation with a floating toolbar and modern UI. Perfect for presentations, education, design reviews, and streaming.

## Features

### MVP (Alpha/Beta)
- ✅ Floating overlay toolbar
- ✅ Pen tool with smooth drawing
- ✅ Highlighter with transparency
- ✅ Eraser functionality
- ✅ Shape tools (rectangle, ellipse, arrow, line)
- ✅ Text labels
- ✅ Undo/redo support
- ✅ Color & thickness customization
- ⏳ Export annotations (coming soon)

### Architecture

```
Pointly/
├── Sources/
│   ├── main.swift              # App entry point & menu bar
│   ├── Core/
│   │   └── OverlayWindowManager.swift  # Window overlay system
│   ├── UI/
│   │   ├── OverlayView.swift           # Main overlay interface
│   │   ├── FloatingToolbar.swift      # Draggable toolbar
│   │   ├── DrawingCanvas.swift        # Canvas rendering
│   │   └── SettingsView.swift         # Preferences window
│   └── State/
│       └── DrawingState.swift         # Combine-based state management
├── Tests/
└── Resources/
```

## Requirements

- macOS 13.0+ (Ventura)
- Xcode 15.0+
- Swift 5.9+
- Screen Recording permission

## Development

### Setup

```bash
cd pointly
swift package resolve
swift build
```

### Running

```bash
swift run Pointly
```

### Testing

```bash
swift test
```

## Design Specifications

- **Default pen color**: `#FF3B30` (Apple Red)
- **Highlighter opacity**: 40%
- **Stroke thickness**: 1-10px range
- **Drawing latency target**: < 10ms on Retina/4K
- **Icons**: SF Symbols (system native)
- **Toolbar**: Rounded corners, material background

## Permissions

Pointly requires **Screen Recording** permission in System Preferences > Security & Privacy > Privacy > Screen Recording to function properly.

## License

Copyright © 2024 Pointly. All rights reserved.
