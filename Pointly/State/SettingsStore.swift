import SwiftUI
import Combine

/// Settings store using UserDefaults for persistence
class SettingsStore: ObservableObject {
    // MARK: - Published Properties
    
    @Published var globalHotkey: String {
        didSet {
            UserDefaults.standard.set(globalHotkey, forKey: "globalHotkey")
            NotificationCenter.default.post(name: .globalHotkeyChanged, object: globalHotkey)
        }
    }
    
    @Published var toolbarTheme: String {
        didSet {
            UserDefaults.standard.set(toolbarTheme, forKey: "toolbarTheme")
        }
    }
    
    @Published var startupBehavior: String {
        didSet {
            UserDefaults.standard.set(startupBehavior, forKey: "startupBehavior")
        }
    }
    
    @Published var snapToGrid: Bool {
        didSet {
            UserDefaults.standard.set(snapToGrid, forKey: "snapToGrid")
        }
    }
    
    @Published var straightLineAssist: Bool {
        didSet {
            UserDefaults.standard.set(straightLineAssist, forKey: "straightLineAssist")
        }
    }
    
    @Published var defaultPenColor: String {
        didSet {
            UserDefaults.standard.set(defaultPenColor, forKey: "defaultPenColor")
        }
    }
    
    @Published var defaultThickness: Double {
        didSet {
            UserDefaults.standard.set(defaultThickness, forKey: "defaultThickness")
        }
    }
    
    @Published var showToolbarOnStartup: Bool {
        didSet {
            UserDefaults.standard.set(showToolbarOnStartup, forKey: "showToolbarOnStartup")
        }
    }
    
    @Published var autoSaveAnnotations: Bool {
        didSet {
            UserDefaults.standard.set(autoSaveAnnotations, forKey: "autoSaveAnnotations")
        }
    }
    
    @Published var exportFormat: String {
        didSet {
            UserDefaults.standard.set(exportFormat, forKey: "exportFormat")
        }
    }
    
    @Published var exportQuality: Double {
        didSet {
            UserDefaults.standard.set(exportQuality, forKey: "exportQuality")
        }
    }
    
    // MARK: - Computed Properties
    
    var penColor: Color {
        get {
            Color(hex: defaultPenColor) ?? Color(red: 1.0, green: 0.231, blue: 0.188)
        }
        set {
            defaultPenColor = newValue.toHex()
        }
    }
    
    var themeMode: ColorScheme? {
        switch toolbarTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Load values from UserDefaults or use defaults
        self.globalHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧P"
        self.toolbarTheme = UserDefaults.standard.string(forKey: "toolbarTheme") ?? "system"
        self.startupBehavior = UserDefaults.standard.string(forKey: "startupBehavior") ?? "menubar"
        self.snapToGrid = UserDefaults.standard.bool(forKey: "snapToGrid")
        self.straightLineAssist = UserDefaults.standard.bool(forKey: "straightLineAssist")
        self.defaultPenColor = UserDefaults.standard.string(forKey: "defaultPenColor") ?? "#FF3B30"
        self.defaultThickness = UserDefaults.standard.double(forKey: "defaultThickness") != 0 ? 
            UserDefaults.standard.double(forKey: "defaultThickness") : 3.0
        self.showToolbarOnStartup = UserDefaults.standard.bool(forKey: "showToolbarOnStartup")
        self.autoSaveAnnotations = UserDefaults.standard.bool(forKey: "autoSaveAnnotations")
        self.exportFormat = UserDefaults.standard.string(forKey: "exportFormat") ?? "png"
        self.exportQuality = UserDefaults.standard.double(forKey: "exportQuality") != 0 ?
            UserDefaults.standard.double(forKey: "exportQuality") : 0.9
        
        // Set default values if first launch
        registerDefaults()
    }
    
    // MARK: - Methods
    
    private func registerDefaults() {
        let defaults: [String: Any] = [
            "globalHotkey": "⌘⇧P",
            "toolbarTheme": "system",
            "startupBehavior": "menubar",
            "snapToGrid": false,
            "straightLineAssist": true,
            "defaultPenColor": "#FF3B30",
            "defaultThickness": 3.0,
            "showToolbarOnStartup": true,
            "autoSaveAnnotations": false,
            "exportFormat": "png",
            "exportQuality": 0.9
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        globalHotkey = "⌘⇧P"
        toolbarTheme = "system"
        startupBehavior = "menubar"
        snapToGrid = false
        straightLineAssist = true
        defaultPenColor = "#FF3B30"
        defaultThickness = 3.0
        showToolbarOnStartup = true
        autoSaveAnnotations = false
        exportFormat = "png"
        exportQuality = 0.9
    }
    
    /// Export settings to a dictionary
    func exportSettings() -> [String: Any] {
        return [
            "globalHotkey": globalHotkey,
            "toolbarTheme": toolbarTheme,
            "startupBehavior": startupBehavior,
            "snapToGrid": snapToGrid,
            "straightLineAssist": straightLineAssist,
            "defaultPenColor": defaultPenColor,
            "defaultThickness": defaultThickness,
            "showToolbarOnStartup": showToolbarOnStartup,
            "autoSaveAnnotations": autoSaveAnnotations,
            "exportFormat": exportFormat,
            "exportQuality": exportQuality
        ]
    }
    
    /// Import settings from a dictionary
    func importSettings(_ settings: [String: Any]) {
        if let value = settings["globalHotkey"] as? String { globalHotkey = value }
        if let value = settings["toolbarTheme"] as? String { toolbarTheme = value }
        if let value = settings["startupBehavior"] as? String { startupBehavior = value }
        if let value = settings["snapToGrid"] as? Bool { snapToGrid = value }
        if let value = settings["straightLineAssist"] as? Bool { straightLineAssist = value }
        if let value = settings["defaultPenColor"] as? String { defaultPenColor = value }
        if let value = settings["defaultThickness"] as? Double { defaultThickness = value }
        if let value = settings["showToolbarOnStartup"] as? Bool { showToolbarOnStartup = value }
        if let value = settings["autoSaveAnnotations"] as? Bool { autoSaveAnnotations = value }
        if let value = settings["exportFormat"] as? String { exportFormat = value }
        if let value = settings["exportQuality"] as? Double { exportQuality = value }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    func toHex() -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "#FF3B30" // Default red
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX", 
                     lroundf(r * 255), 
                     lroundf(g * 255), 
                     lroundf(b * 255))
    }
}

// MARK: - Settings Keys

extension SettingsStore {
    enum Keys {
        static let globalHotkey = "globalHotkey"
        static let toolbarTheme = "toolbarTheme"
        static let startupBehavior = "startupBehavior"
        static let snapToGrid = "snapToGrid"
        static let straightLineAssist = "straightLineAssist"
        static let defaultPenColor = "defaultPenColor"
        static let defaultThickness = "defaultThickness"
        static let showToolbarOnStartup = "showToolbarOnStartup"
        static let autoSaveAnnotations = "autoSaveAnnotations"
        static let exportFormat = "exportFormat"
        static let exportQuality = "exportQuality"
    }
}

extension Notification.Name {
    static let globalHotkeyChanged = Notification.Name("GlobalHotkeyChanged")
}
