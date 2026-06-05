# 🔍 How to Filter Console.app for Pointly Logs

## The Problem
You're seeing general system logs instead of Pointly-specific logs. Here's how to fix it:

## ✅ Method 1: Filter in Console.app (Easiest)

1. **In Console.app, look for the search/filter box** (usually top-right)
2. **Type:** `Pointly` (case-sensitive)
3. **Press Enter**
4. You should now see only Pointly logs

## ✅ Method 2: Use Terminal (More Reliable)

Open Terminal and run:
```bash
log stream --predicate 'process == "Pointly"' --level debug
```

This will show **only** Pointly logs in real-time.

## ✅ Method 3: Check if Pointly is Running

1. **Check menu bar** - Do you see the pencil icon?
2. **If not running**, open Pointly.app:
   ```bash
   open /Users/lyubomirstavrev/Desktop/pointly/Pointly.app
   ```

## 🔍 What You Should See

After filtering, you should see messages like:
```
🔑 Setting up global hotkeys...
✅ Accessibility permissions granted
✅ Global hotkey monitor registered successfully
```

When you press ⌘⌃P, you should see:
```
🔍 Key detected: keyCode=35, modifiers=...
✅ ⌘⌃P detected - toggling overlay
```

## 🚨 If You See Nothing

1. **Pointly might not be running** - Check menu bar
2. **Logs might be going to a different location** - Try Terminal method
3. **App might have crashed** - Check Activity Monitor

## 💡 Quick Test

Run this in Terminal to see Pointly logs:
```bash
cd /Users/lyubomirstavrev/Desktop/pointly
log stream --predicate 'process == "Pointly"' --level debug
```

Then press ⌘⌃P and watch for messages!


