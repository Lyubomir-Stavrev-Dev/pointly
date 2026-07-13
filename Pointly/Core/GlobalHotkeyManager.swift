import AppKit
import Carbon

protocol GlobalHotkeyManagerDelegate: AnyObject {
    func hotkeyPressed()
}

/// Manages system-wide hotkey registration using Carbon APIs
class GlobalHotkeyManager {
    weak var delegate: GlobalHotkeyManagerDelegate?

    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotkeyCallbacks: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    /// Process-wide hotkey ID source. Every GlobalHotkeyManager instance shares
    /// this so their EventHotKeyIDs never collide — two instances each starting
    /// at 1 would register duplicate IDs (same signature + id), and Carbon rejects
    /// the second with eventHotKeyExistsErr, silently dropping a hotkey.
    private static var globalNextID: UInt32 = 1

    deinit { unregisterAll() }

    /// Register a global hotkey with an optional per-hotkey callback.
    /// If no callback is provided, `delegate?.hotkeyPressed()` is called instead.
    /// Returns false when Carbon rejects the combo (e.g. owned by another app).
    @discardableResult
    func registerHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, callback: (() -> Void)? = nil) -> Bool {
        let id = Self.globalNextID
        Self.globalNextID += 1

        hotkeyCallbacks[id] = callback ?? { [weak self] in self?.delegate?.hotkeyPressed() }

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift)   { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option)  { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        // Signature: 'PTLY' = 0x50544C59
        let hotkeyID = EventHotKeyID(signature: 0x50544C59, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotkeyID, GetApplicationEventTarget(), 0, &ref)

        if status == noErr, let ref = ref {
            hotkeyRefs[id] = ref
            installEventHandlerIfNeeded()
            print("✅ Hotkey registered (id: \(id), keyCode: \(keyCode))")
            return true
        } else {
            hotkeyCallbacks.removeValue(forKey: id)   // don't keep a callback for a dead registration
            print("❌ Failed to register hotkey (keyCode: \(keyCode)): \(status)")
            return false
        }
    }

    func unregisterAll() {
        hotkeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotkeyRefs.removeAll()
        hotkeyCallbacks.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Private

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        // InstallApplicationEventHandler is a C macro; call its expansion directly.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                // Multiple GlobalHotkeyManager instances each install a handler on the
                // same application event target. Carbon calls the most recently installed
                // handler first, and returning noErr STOPS propagation — so a hotkey owned
                // by another instance must be declined with eventNotHandledErr, otherwise
                // this handler swallows it and the owning instance never sees the event.
                guard let callback = manager.hotkeyCallbacks[hotKeyID.id] else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async { callback() }
                return noErr
            },
            1, &eventSpec, selfPtr, &eventHandler
        )
    }
}

// MARK: - Key Code Lookup
extension GlobalHotkeyManager {
    static func keyCode(for character: String) -> UInt32? {
        let keyCodes: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, " ": 49
        ]
        return keyCodes[character.lowercased()]
    }
}
