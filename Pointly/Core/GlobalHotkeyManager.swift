import AppKit
import Carbon

protocol GlobalHotkeyManagerDelegate: AnyObject {
    func hotkeyPressed()
}

/// Manages system-wide hotkey registration using Carbon APIs
class GlobalHotkeyManager {
    weak var delegate: GlobalHotkeyManagerDelegate?
    
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    deinit {
        unregisterHotkey()
    }
    
    /// Register a global hotkey with the system
    /// - Parameters:
    ///   - keyCode: Virtual key code (e.g., 35 for 'P')
    ///   - modifiers: Modifier keys (command, shift, etc.)
    func registerHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        // Unregister existing hotkey first
        unregisterHotkey()
        
        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        
        // Create hotkey ID
        let hotkeyID = EventHotKeyID(signature: OSType(fourCharCode: "PTLY"), id: 1)
        
        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr {
            // Install event handler
            let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            var eventSpecs = [eventSpec]
            
            InstallApplicationEventHandler(
                { (nextHandler, theEvent, userData) -> OSStatus in
                    // Extract the GlobalHotkeyManager instance from userData
                    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                    manager.delegate?.hotkeyPressed()
                    return noErr
                },
                1,
                &eventSpecs,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandler
            )
            
            print("✅ Global hotkey registered successfully")
        } else {
            print("❌ Failed to register global hotkey: \(status)")
        }
    }
    
    /// Unregister the current hotkey
    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

// MARK: - Helper Functions
extension GlobalHotkeyManager {
    /// Convert a four-character string to OSType
    private func fourCharCode(_ string: String) -> FourCharCode {
        let utf8 = string.utf8
        var result: FourCharCode = 0
        for (i, byte) in utf8.enumerated() {
            if i >= 4 { break }
            result = result << 8 + FourCharCode(byte)
        }
        return result
    }
    
    /// Get key code for common keys
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
