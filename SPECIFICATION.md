Pointly – Project Blueprint Document
1. Project Overview
Vision

Pointly is a premium cross-platform annotation & presentation tool designed to make screen interaction clear, professional, and engaging.
It enables users to highlight, draw, and annotate directly on their screen with smooth, polished, and modern interactions.

Mission

To empower presenters, educators, designers, developers, and streamers with intuitive annotation tools that elevate communication and engagement during live or recorded sessions.

Core Use Cases

Presentations – highlight key points during slides.

Education – annotate in real-time while teaching.
    
Design/UX Reviews – mark issues during critiques.   

Product Demos & Sales – guide client focus to specific UI areas.

Streaming/Content – emphasize interactions in tutorials or recordings.

Differentiators

Modern UI/UX polish unlike legacy competitors.

Cross-platform roadmap (Mac + Windows).

Advanced Pro features (recording, keystroke visualization, collaboration).

Performance focus (smooth drawing at 4K+ resolutions).

2. Scope & Goals
MVP Scope (Phase 1 & 2)

Overlay toolbar with:

Pen, Highlighter, Eraser

Shapes (rectangle, ellipse, arrow, line)

Text labels

Hotkey activation & toolbar toggle

Undo/redo support with key combination

Color & thickness palette

Export annotation snapshot (image/PDF)

Minimal settings panel

Out of Scope for MVP

Multi-monitor support

Recording/timeline playback

Collaboration mode

Advanced export presets

Business subscription model

Long-Term Goals

Pro Features: keystroke visualization, advanced themes

Windows Release: Feature parity with Mac

3. Feature Breakdown
Annotation Tools

Pen: Smooth freehand drawing

Highlighter: Semi-transparent stroke

Shapes: Rectangle, ellipse, line, arrow

Text tool: Labels with styling options

Eraser: Full erase or stroke-level

Interaction Enhancements

Cursor spotlight ring

Click ripple animations

Keystroke visualization

Zoom/magnifier mode

Workflow & UI

Floating overlay toolbar

Hotkey activation (toggle tools instantly)

Layered annotation system

Undo/redo stack with key combination

Multi-monitor awareness (future)

Customizable palette

Settings

Global hotkey configuration

Toolbar theme (dark/light)

Startup behavior (menubar/tray)

Snap-to-grid & straight-line assist

Export presets

Advanced / Pro

Annotation export (PDF/image)

Multi-monitor support

Keystroke visualization

Collaboration mode (later)

Monetization

Free: Pen, highlighter, spotlight, basic settings

Pro ($5–10/mo or $50 lifetime): Shapes, text, export, hotkeys, themes, recording

Business license: Collaboration + admin features

4. Technology & Architecture
Chosen Stack

Mac First (Swift + SwiftUI)

Premium feel, system-native performance

Tight integration with macOS overlay & permissions

Windows Next (WinUI 3 or Electron/React)

Shared drawing logic ported from Mac engine

Alternatives
Option	Pros	Cons
SwiftUI (Mac)	Best native UX	Mac-only
Electron + React	Easier portability	Heavier, less "native"
Tauri (Rust+Web)	Shared core engine	Ecosystem still maturing
Avalonia (C#)	Cross-platform UI	Less polished Mac UX