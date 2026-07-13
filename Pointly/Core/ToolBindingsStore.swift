import Foundation
import Combine

final class ToolBindingsStore: ObservableObject {
    static let shared = ToolBindingsStore()

    @Published private(set) var bindings: [DrawingTool: String]

    private let udKey = "toolBindings_v1"

    static let defaults: [DrawingTool: String] = [
        .pen:         "⌃1",
        .highlighter: "⌃2",
        .marker:      "⌃3",
        .eraser:      "⌃4",
        .text:        "⌃5",
        .arrow:       "⌃6",
        .line:        "⌃7",
        .select:      "⌃8",
        .cursor:      "⌃9",
    ]

    private init() {
        if let data = UserDefaults.standard.data(forKey: "toolBindings_v1"),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            var loaded: [DrawingTool: String] = [:]
            for (k, v) in dict {
                if let tool = DrawingTool(rawValue: k) { loaded[tool] = v }
            }
            bindings = loaded
        } else {
            bindings = Self.defaults
        }
    }

    func setBinding(_ shortcut: String, for tool: DrawingTool) {
        // The main overlay toggle owns its combo — a duplicate Carbon
        // registration fails silently and one of the two goes dead. Compare as
        // character sets (recorders emit modifiers in different orders).
        let mainHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧P"
        guard Set(shortcut) != Set(mainHotkey) else { return }
        var updated = bindings
        for (t, s) in updated where s == shortcut && t != tool {
            updated.removeValue(forKey: t)
        }
        updated[tool] = shortcut
        bindings = updated
        persist()
        NotificationCenter.default.post(name: .toolBindingsChanged, object: nil)
    }

    func clearBinding(for tool: DrawingTool) {
        var updated = bindings
        updated.removeValue(forKey: tool)
        bindings = updated
        persist()
        NotificationCenter.default.post(name: .toolBindingsChanged, object: nil)
    }

    func resetToDefaults() {
        bindings = Self.defaults
        persist()
        NotificationCenter.default.post(name: .toolBindingsChanged, object: nil)
    }

    private func persist() {
        var dict: [String: String] = [:]
        for (tool, shortcut) in bindings { dict[tool.rawValue] = shortcut }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }
}

extension Notification.Name {
    static let toolBindingsChanged = Notification.Name("ToolBindingsChanged")
    static let navigateToShortcuts = Notification.Name("NavigateToShortcuts")
}
