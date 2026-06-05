# 🔍 How to Debug Hotkeys with Console.app

## What is Console.app?

**Console.app** is macOS's built-in log viewer that shows all system and application logs in real-time. It's perfect for debugging why hotkeys aren't working.

## 📋 Step-by-Step Guide

### Step 1: Open Console.app
1. Press **⌘Space** (Command+Space) to open Spotlight
2. Type **"Console"**
3. Press **Enter** to open Console.app

### Step 2: Filter for Pointly Logs
1. In the search box at the top-right, type: **`Pointly`**
2. This will show only logs from the Pointly app

### Step 3: Test the Hotkey
1. Make sure Pointly is running (check menu bar for the pencil icon)
2. Press **⌘⌃P** (Command+Control+P)
3. Watch the Console for messages

## 🔍 What to Look For

### ✅ If Hotkeys Are Working:
You should see messages like:
```
🔑 Setting up global hotkeys...
✅ Accessibility permissions granted
✅ Global hotkey monitor registered successfully
🔍 Key detected: keyCode=35, modifiers=...
✅ ⌘⌃P detected - toggling overlay
```

### ❌ If Hotkeys Are NOT Working:
You might see:
```
⚠️  Accessibility permissions not granted
❌ Failed to register global hotkey monitor
```

OR you might see nothing at all (which means the key isn't being detected).

## 🛠️ Common Issues & Solutions

### Issue 1: "Accessibility permissions not granted"
**Solution:**
1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Make sure **Pointly.app** is listed and **enabled** (toggle is ON)
3. If not listed, click **+** and add Pointly.app
4. **Restart Pointly** after granting permissions

### Issue 2: No messages appear when pressing ⌘⌃P
**Possible causes:**
- App doesn't have focus (try clicking menu bar icon first)
- Another app is using the same hotkey
- Permissions not granted

**Solution:**
- Try clicking the Pointly menu bar icon first to give it focus
- Then press ⌘⌃P
- Check if another app (like Cursor, VS Code, etc.) is using ⌘⌃P

### Issue 3: "Key detected" but "not toggling"
**This means:**
- The key is being detected
- But the modifier check is failing

**Solution:**
- Check the console for the exact modifier values
- Try alternative hotkeys: **⌘⇧P** or **⌘⌥P**

## 📊 Understanding the Logs

### Key Detection Messages:
- `🔍 Key detected: keyCode=35` = P key was pressed
- `🔍 Key detected: keyCode=4` = H key was pressed
- `keyCode=35` = P key
- `keyCode=4` = H key

### Modifier Flags:
- `modifiers=...` shows the raw modifier flags
- Look for: `Cmd=...`, `Ctrl=...`, `Shift=...`, `Opt=...`

### Success Messages:
- `✅ ⌘⌃P detected` = Hotkey was recognized and action triggered
- `✅ Global hotkey monitor registered` = Monitor is active

## 🎯 Quick Test

1. **Open Console.app**
2. **Filter for "Pointly"**
3. **Press ⌘⌃P**
4. **Look for:**
   - `🔍 Key detected` = Key is being seen
   - `✅ ⌘⌃P detected` = Hotkey worked!
   - Nothing = Key not detected (permissions issue)

## 💡 Alternative: Use Terminal

You can also check logs in Terminal:
```bash
log stream --predicate 'process == "Pointly"' --level debug
```

This will show Pointly logs in real-time in your terminal.

---

**Need Help?** Share the console output and I can help debug further!


