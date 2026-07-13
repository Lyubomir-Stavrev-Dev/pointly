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
            NotificationCenter.default.post(name: .toolbarThemeChanged, object: nil)
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

    @Published var arrowTipAtStart: Bool {
        didSet {
            UserDefaults.standard.set(arrowTipAtStart, forKey: "arrowTipAtStart")
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
        didSet { UserDefaults.standard.set(exportQuality, forKey: "exportQuality") }
    }

    @Published var gridSize: Double {
        didSet { UserDefaults.standard.set(gridSize, forKey: "gridSize") }
    }

    @Published var includeTimestampInFilename: Bool {
        didSet { UserDefaults.standard.set(includeTimestampInFilename, forKey: "includeTimestampInFilename") }
    }

    @Published var autoOpenExport: Bool {
        didSet { UserDefaults.standard.set(autoOpenExport, forKey: "autoOpenExport") }
    }

    @Published var showExportNotification: Bool {
        didSet { UserDefaults.standard.set(showExportNotification, forKey: "showExportNotification") }
    }
    
    // MARK: - Computed Properties
    
    var penColor: Color {
        get {
            Color(hex: defaultPenColor) ?? Color(red: 0.957, green: 0.392, blue: 0.302)
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
        // Register defaults BEFORE reading — otherwise bool/double reads return
        // 0/false for unset keys and the intended defaults never apply.
        Self.registerDefaults()

        // Load values from UserDefaults or use defaults
        self.globalHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧P"
        self.toolbarTheme = UserDefaults.standard.string(forKey: "toolbarTheme") ?? "system"
        self.startupBehavior = UserDefaults.standard.string(forKey: "startupBehavior") ?? "menubar"
        self.snapToGrid = UserDefaults.standard.bool(forKey: "snapToGrid")
        self.straightLineAssist = UserDefaults.standard.bool(forKey: "straightLineAssist")
        self.arrowTipAtStart = UserDefaults.standard.bool(forKey: "arrowTipAtStart")
        self.defaultPenColor = UserDefaults.standard.string(forKey: "defaultPenColor") ?? "#FF3B30"
        self.defaultThickness = UserDefaults.standard.double(forKey: "defaultThickness") != 0 ? 
            UserDefaults.standard.double(forKey: "defaultThickness") : 3.0
        self.showToolbarOnStartup = UserDefaults.standard.bool(forKey: "showToolbarOnStartup")
        self.autoSaveAnnotations = UserDefaults.standard.bool(forKey: "autoSaveAnnotations")
        self.exportFormat = UserDefaults.standard.string(forKey: "exportFormat") ?? "png"
        self.exportQuality = UserDefaults.standard.double(forKey: "exportQuality") != 0 ?
            UserDefaults.standard.double(forKey: "exportQuality") : 0.9
        self.gridSize = UserDefaults.standard.double(forKey: "gridSize") != 0 ?
            UserDefaults.standard.double(forKey: "gridSize") : 20.0
        self.includeTimestampInFilename = UserDefaults.standard.object(forKey: "includeTimestampInFilename") as? Bool ?? true
        self.autoOpenExport = UserDefaults.standard.object(forKey: "autoOpenExport") as? Bool ?? true
        self.showExportNotification = UserDefaults.standard.object(forKey: "showExportNotification") as? Bool ?? true
    }

    // MARK: - Methods

    /// Static + also called from AppDelegate at launch: DrawingState and
    /// AppDelegate read these keys with raw UserDefaults, so registration must
    /// happen before ANY reader runs — not just when the Settings window opens.
    static func registerDefaults() {
        let defaults: [String: Any] = [
            "globalHotkey": "⌘⇧P",
            "toolbarTheme": "system",
            "startupBehavior": "menubar",
            "snapToGrid": false,
            "straightLineAssist": true,
            "arrowTipAtStart": true,
            "defaultPenColor": "#F4644D",
            "defaultThickness": 3.0,
            "showToolbarOnStartup": true,
            "autoSaveAnnotations": false,
            "exportFormat": "png",
            "exportQuality": 0.9,
            "gridSize": 20.0,
            "includeTimestampInFilename": true,
            "autoOpenExport": true,
            "showExportNotification": true,
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
        arrowTipAtStart = true
        defaultPenColor = "#F4644D"
        defaultThickness = 3.0
        showToolbarOnStartup = true
        autoSaveAnnotations = false
        exportFormat = "png"
        exportQuality = 0.9
        gridSize = 20.0
        includeTimestampInFilename = true
        autoOpenExport = true
        showExportNotification = true
    }
    
    /// Export settings to a dictionary
    func exportSettings() -> [String: Any] {
        return [
            "globalHotkey": globalHotkey,
            "toolbarTheme": toolbarTheme,
            "startupBehavior": startupBehavior,
            "snapToGrid": snapToGrid,
            "straightLineAssist": straightLineAssist,
            "arrowTipAtStart": arrowTipAtStart,
            "defaultPenColor": defaultPenColor,
            "defaultThickness": defaultThickness,
            "showToolbarOnStartup": showToolbarOnStartup,
            "autoSaveAnnotations": autoSaveAnnotations,
            "exportFormat": exportFormat,
            "exportQuality": exportQuality,
            "gridSize": gridSize,
            "includeTimestampInFilename": includeTimestampInFilename,
            "autoOpenExport": autoOpenExport,
            "showExportNotification": showExportNotification
        ]
    }

    /// Import settings from a dictionary
    func importSettings(_ settings: [String: Any]) {
        if let value = settings["globalHotkey"] as? String { globalHotkey = value }
        if let value = settings["toolbarTheme"] as? String { toolbarTheme = value }
        if let value = settings["startupBehavior"] as? String { startupBehavior = value }
        if let value = settings["snapToGrid"] as? Bool { snapToGrid = value }
        if let value = settings["straightLineAssist"] as? Bool { straightLineAssist = value }
        if let value = settings["arrowTipAtStart"] as? Bool { arrowTipAtStart = value }
        if let value = settings["defaultPenColor"] as? String { defaultPenColor = value }
        if let value = settings["defaultThickness"] as? Double { defaultThickness = value }
        if let value = settings["showToolbarOnStartup"] as? Bool { showToolbarOnStartup = value }
        if let value = settings["autoSaveAnnotations"] as? Bool { autoSaveAnnotations = value }
        if let value = settings["exportFormat"] as? String { exportFormat = value }
        if let value = settings["exportQuality"] as? Double { exportQuality = value }
        if let value = settings["gridSize"] as? Double { gridSize = value }
        if let value = settings["includeTimestampInFilename"] as? Bool { includeTimestampInFilename = value }
        if let value = settings["autoOpenExport"] as? Bool { autoOpenExport = value }
        if let value = settings["showExportNotification"] as? Bool { showExportNotification = value }
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
    
    /// Convert Color to hex string (#RRGGBB, or #AARRGGBB when translucent —
    /// Color(hex:) round-trips the 8-digit ARGB form)
    func toHex() -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "#F4644D" // Brand default
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components.count >= 4 ? components[3] : 1.0)

        if a < 0.999 {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(a * 255),
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
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
    static let toolbarThemeChanged = Notification.Name("ToolbarThemeChanged")
}
