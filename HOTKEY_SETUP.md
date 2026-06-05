# 🔑 Hotkey Setup Guide

## Issue: Command+Control+P Not Working

The hotkey **⌘⌃P** (Command+Control+P) requires **Accessibility permissions** on macOS to work globally.

## ✅ Solution: Grant Accessibility Permissions

### Step 1: Open System Settings
1. Click the **Apple menu** (🍎) in the top-left corner
2. Select **System Settings** (or **System Preferences** on older macOS)

### Step 2: Navigate to Accessibility
1. Click **Privacy & Security** (or **Security & Privacy**)
2. Click **Accessibility** in the left sidebar

### Step 3: Add Pointly
1. Click the **+** (plus) button
2. Navigate to `/Users/lyubomirstavrev/Desktop/pointly/`
3. Select **Pointly.app**
4. Click **Open**

### Step 4: Enable Pointly
1. Make sure **Pointly.app** is checked/enabled in the list
2. If it's already there but unchecked, check the box

### Step 5: Restart Pointly
1. Quit Pointly (click menu bar icon → Quit Pointly)
2. Open Pointly.app again
3. Try **⌘⌃P** - it should work now!

---

## 🎯 Alternative: Use Menu Bar Icon

If hotkeys still don't work, you can always:
- **Click the menu bar icon** (pencil icon)
- Select **"Show Overlay"** or **"Hide Overlay"**

---

## 📋 Available Hotkeys

Once permissions are granted:

### Global Hotkeys (work anywhere):
- **⌘⌃P** - Toggle overlay (Command+Control+P)
- **⌘⇧P** - Toggle overlay (Command+Shift+P) - fallback
- **⌘⌥P** - Toggle overlay (Command+Option+P) - fallback
- **⌘⌃H** - Show help window (Command+Control+H)
- **F10, F11, F12** - Alternative overlay toggle keys

### Overlay Hotkeys (when overlay is active):
- **Tab** - Switch between Draw/Interact mode
- **Esc** - Hide overlay
- **H** - Toggle help overlay
- **⌘Z** - Undo last action
- **⌘⇧Z** - Redo last undone action
- **1-6** - Select drawing tools

---

## 🔍 Troubleshooting

### Hotkeys Still Don't Work?

1. **Check Console logs**:
   - Open **Console.app**
   - Filter for "Pointly"
   - Look for "✅ Registered" or "❌ Failed to register" messages

2. **Verify permissions**:
   - Go back to System Settings → Privacy & Security → Accessibility
   - Make sure Pointly.app is **checked** and **enabled**

3. **Try restarting**:
   - Quit Pointly completely
   - Restart your Mac (if needed)
   - Open Pointly.app again

4. **Check for conflicts**:
   - Make sure no other app is using the same hotkey
   - Try the alternative hotkeys (⌘⇧P, F10, F11, F12)

---

## 💡 Why Accessibility Permissions?

macOS requires Accessibility permissions for apps to:
- Monitor global keyboard events
- Register system-wide hotkeys
- Capture keyboard input when the app is not in focus

This is a security feature to prevent malicious apps from capturing your keystrokes.


