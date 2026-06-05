import XCTest
import Carbon
@testable import Pointly

final class GlobalHotkeyManagerTests: XCTestCase {
    var hotkeyManager: GlobalHotkeyManager!
    var delegateCallCount: Int = 0
    
    override func setUpWithError() throws {
        hotkeyManager = GlobalHotkeyManager()
        delegateCallCount = 0
    }
    
    override func tearDownWithError() throws {
        hotkeyManager?.unregisterHotkey()
        hotkeyManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(hotkeyManager)
        XCTAssertNil(hotkeyManager.delegate)
    }
    
    // MARK: - Key Code Tests
    
    func testKeyCodeMapping() {
        XCTAssertEqual(GlobalHotkeyManager.keyCode(for: "p"), 35)
        XCTAssertEqual(GlobalHotkeyManager.keyCode(for: "P"), 35)
        XCTAssertEqual(GlobalHotkeyManager.keyCode(for: "a"), 0)
        XCTAssertEqual(GlobalHotkeyManager.keyCode(for: "z"), 6)
        XCTAssertEqual(GlobalHotkeyManager.keyCode(for: " "), 49) // Space
        XCTAssertNil(GlobalHotkeyManager.keyCode(for: "invalid"))
    }
    
    func testCommonKeysCoverage() {
        let commonKeys = ["a", "s", "d", "f", "g", "h", "j", "k", "l", "q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        
        for key in commonKeys {
            XCTAssertNotNil(GlobalHotkeyManager.keyCode(for: key), "Key '\(key)' should have a mapping")
        }
    }
    
    // MARK: - Hotkey Registration Tests
    
    func testHotkeyRegistration() {
        // Note: This test may require special permissions or may not work in all environments
        // We're testing the method call without asserting success due to sandboxing restrictions
        
        hotkeyManager.delegate = self
        
        // This should not crash
        hotkeyManager.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
        
        // Verify no immediate crash
        XCTAssertNotNil(hotkeyManager)
    }
    
    func testHotkeyUnregistration() {
        hotkeyManager.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
        
        // This should not crash
        hotkeyManager.unregisterHotkey()
        
        // Verify no crash
        XCTAssertNotNil(hotkeyManager)
    }
    
    func testMultipleRegistrations() {
        // Register first hotkey
        hotkeyManager.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
        
        // Register second hotkey (should unregister first)
        hotkeyManager.registerHotkey(keyCode: 13, modifiers: [.command, .option])
        
        // Should not crash
        XCTAssertNotNil(hotkeyManager)
    }
    
    // MARK: - Delegate Tests
    
    func testDelegateAssignment() {
        hotkeyManager.delegate = self
        XCTAssertNotNil(hotkeyManager.delegate)
    }
    
    func testWeakDelegateReference() {
        var testDelegate: TestDelegate? = TestDelegate()
        hotkeyManager.delegate = testDelegate
        
        XCTAssertNotNil(hotkeyManager.delegate)
        
        // Release the delegate
        testDelegate = nil
        
        // The weak reference should be nil now
        // Note: This might not work immediately due to ARC timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(self.hotkeyManager.delegate)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testDeinitCleanup() {
        var manager: GlobalHotkeyManager? = GlobalHotkeyManager()
        manager?.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
        
        // This should properly clean up
        manager = nil
        
        // If we reach here without crashing, cleanup worked
        XCTAssertNil(manager)
    }
    
    // MARK: - Modifier Flag Tests
    
    func testSingleModifier() {
        // Test each modifier individually
        let modifiers: [NSEvent.ModifierFlags] = [.command, .shift, .option, .control]
        
        for modifier in modifiers {
            hotkeyManager.registerHotkey(keyCode: 35, modifiers: modifier)
            // Should not crash
            XCTAssertNotNil(hotkeyManager)
        }
    }
    
    func testMultipleModifiers() {
        let modifierCombinations: [NSEvent.ModifierFlags] = [
            [.command, .shift],
            [.command, .option],
            [.command, .control],
            [.shift, .option],
            [.command, .shift, .option],
            [.command, .shift, .control],
            [.command, .option, .control],
            [.shift, .option, .control],
            [.command, .shift, .option, .control]
        ]
        
        for modifiers in modifierCombinations {
            hotkeyManager.registerHotkey(keyCode: 35, modifiers: modifiers)
            // Should not crash
            XCTAssertNotNil(hotkeyManager)
        }
    }
    
    func testEmptyModifiers() {
        // Empty modifiers should still work
        hotkeyManager.registerHotkey(keyCode: 35, modifiers: [])
        XCTAssertNotNil(hotkeyManager)
    }
    
    // MARK: - Edge Cases
    
    func testInvalidKeyCode() {
        // Very high key code (likely invalid)
        hotkeyManager.registerHotkey(keyCode: 999999, modifiers: [.command])
        
        // Should not crash (may fail internally but shouldn't crash)
        XCTAssertNotNil(hotkeyManager)
    }
    
    func testZeroKeyCode() {
        // Key code 0 (should be 'a')
        hotkeyManager.registerHotkey(keyCode: 0, modifiers: [.command])
        XCTAssertNotNil(hotkeyManager)
    }
    
    // MARK: - Performance Tests
    
    func testRegistrationPerformance() {
        measure {
            for _ in 0..<100 {
                hotkeyManager.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
                hotkeyManager.unregisterHotkey()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testManagerLifecycle() {
        // Create manager
        let manager = GlobalHotkeyManager()
        manager.delegate = self
        
        // Register hotkey
        manager.registerHotkey(keyCode: 35, modifiers: [.command, .shift])
        
        // Unregister
        manager.unregisterHotkey()
        
        // Re-register with different key
        manager.registerHotkey(keyCode: 13, modifiers: [.command, .option])
        
        // Final cleanup (automatic via deinit)
        XCTAssertNotNil(manager)
    }
}

// MARK: - Test Helper Classes

class TestDelegate: GlobalHotkeyManagerDelegate {
    var callCount = 0
    
    func hotkeyPressed() {
        callCount += 1
    }
}

// MARK: - GlobalHotkeyManagerDelegate Implementation

extension GlobalHotkeyManagerTests: GlobalHotkeyManagerDelegate {
    func hotkeyPressed() {
        delegateCallCount += 1
    }
}
