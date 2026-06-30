# 🔍 How to See Pointly Hotkey Logs in Console.app

## The Problem
The OSLog messages use a **subsystem** (`com.pointly.macos`), so they won't show up with a simple "Pointly" filter.

## ✅ Solution: Filter by Subsystem

### In Console.app:

1. **Clear the current filter** (remove "Q ANY Pointly")
2. **In the search box, type:**
   ```
   subsystem:com.pointly.macos
   ```
3. **Press Enter**

You should now see the hotkey logs!

## ✅ Alternative: Use Terminal (Easier)

Open Terminal and run:
```bash
log stream --predicate 'subsystem == "com.pointly.macos"' --level debug
```

This will show **only** the hotkey debug messages in real-time.

## 🎯 What You Should See

When Pointly starts:
```
🚀 Pointly Phase 2.1 - Professional Edition!
🔑 Setting up global hotkeys...
✅ Accessibility permissions granted
✅ Global hotkey monitor registered successfully
```

When you press ⌘⌃P:
```
🔍 Key detected: keyCode=35, modifiers=...
🔍 Relevant: Cmd=true, Ctrl=true, Shift=false, Opt=false
✅ ⌘⌃P detected - toggling overlay
```

## 🚨 If Still No Logs

If you still don't see logs after filtering by subsystem, the `setupGlobalHotkeys()` function might not be running. Let me know and I'll add a test to verify.


