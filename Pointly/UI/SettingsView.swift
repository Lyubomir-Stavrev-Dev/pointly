import SwiftUI
import AppKit

// MARK: - Brand

private let brandGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange,
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? .pink
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let settingsTint = Color(red: 0.06, green: 0.06, blue: 0.14)

// MARK: - NSVisualEffectView wrapper

private struct GlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - SettingsView

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var selectedTab: SettingsTab = .general
    @State private var showResetAlert = false

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            // Thin gradient divider
            LinearGradient(
                colors: [.white.opacity(0.12), .white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 1)
            content
        }
        .frame(width: 640, height: 500)
        .background(
            ZStack {
                GlassBackground()
                settingsTint.opacity(0.45)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        )
        .preferredColorScheme(.dark)
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
        } message: {
            Text("Reset all settings to defaults? This cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToShortcuts)) { _ in
            selectedTab = .shortcuts
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Window drag zone (replaces hidden title bar)
            SettingsDragHandle()
                .frame(height: 28)

            // Logo / header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(brandGradient)
                        .frame(width: 46, height: 46)
                        .shadow(color: (Color(hex: "#F4644D") ?? .orange).opacity(0.5), radius: 12, x: 0, y: 4)
                    Image(systemName: "pencil.tip.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Pointly")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(brandGradient)
            }
            .padding(.top, 28)
            .padding(.bottom, 22)

            // Nav items
            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 16)
        }
        .frame(width: 168)
        .background(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isActive = selectedTab == tab
        Button { selectedTab = tab } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 28, height: 28)
                        .shadow(color: isActive ? (Color(hex: "#F4644D") ?? .orange).opacity(0.4) : .clear,
                                radius: 6, x: 0, y: 2)
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isActive ? .white : .white.opacity(0.55))
                }
                Text(tab.label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                contentHeader
                switch selectedTab {
                case .general:    GeneralContent(settings: settings)
                case .appearance: AppearanceContent(settings: settings)
                case .drawing:    DrawingContent(settings: settings)
                case .shortcuts:  ShortcutsContent()
                case .export:     ExportContent(settings: settings)
                case .advanced:   AdvancedContent(settings: settings, showReset: $showResetAlert)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedTab.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(brandGradient)
            Rectangle()
                .fill(brandGradient.opacity(0.6))
                .frame(height: 1.5)
                .cornerRadius(1)
        }
    }
}

// MARK: - Tab model

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, drawing, shortcuts, export, advanced
    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .drawing:    return "Drawing"
        case .shortcuts:  return "Shortcuts"
        case .export:     return "Export"
        case .advanced:   return "Advanced"
        }
    }
    var icon: String {
        switch self {
        case .general:    return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .drawing:    return "pencil.and.scribble"
        case .shortcuts:  return "keyboard"
        case .export:     return "square.and.arrow.up"
        case .advanced:   return "gearshape.2"
        }
    }
}

// MARK: - Shared card component

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1.2)
                Spacer()
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                )
        )
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let trailing: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            trailing
        }
    }
}

// MARK: - General

private struct GeneralContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Global Hotkey") {
                SettingsRow(label: "Toggle Overlay") {
                    HotkeyRecorderView(hotkey: $settings.globalHotkey)
                }
                Toggle("Show Toolbar on Startup", isOn: $settings.showToolbarOnStartup)
                    .toggleStyle(.switch)
                    .tint(Color(hex: "#F4644D") ?? .orange)
            }

            SettingsCard(title: "Startup") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([("Show in Menu Bar", "menubar"),
                             ("Start Hidden", "hidden")], id: \.1) { title, tag in
                        HStack {
                            Image(systemName: settings.startupBehavior == tag
                                  ? "circle.inset.filled" : "circle")
                                .foregroundStyle(settings.startupBehavior == tag
                                                 ? AnyShapeStyle(brandGradient)
                                                 : AnyShapeStyle(Color.white.opacity(0.35)))
                            Text(title).font(.system(size: 13))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { settings.startupBehavior = tag }
                    }
                }
                Toggle("Auto-save Annotations", isOn: $settings.autoSaveAnnotations)
                    .toggleStyle(.switch)
                    .tint(Color(hex: "#F4644D") ?? .orange)
            }

            SettingsCard(title: "Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pointly needs Screen Recording permission to draw over other apps.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    }
                    .buttonStyle(BrandButtonStyle())
                }
            }
        }
    }
}

// MARK: - Appearance

private struct AppearanceContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Toolbar Theme") {
                HStack(spacing: 0) {
                    ForEach([("System", "system"), ("Light", "light"), ("Dark", "dark")], id: \.1) { label, tag in
                        let isSelected = settings.toolbarTheme == tag
                        Button(label) { settings.toolbarTheme = tag }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 8).fill(brandGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                                    }
                                }
                            )
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.08)))
            }

            SettingsCard(title: "Default Drawing") {
                SettingsRow(label: "Pen Color") {
                    ColorPicker("", selection: $settings.penColor)
                        .labelsHidden()
                        .frame(width: 36, height: 26)
                }

                SettingsRow(label: "Stroke Thickness") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.defaultThickness, in: 1...30, step: 1)
                            .tint(Color(hex: "#F4644D") ?? .orange)
                            .frame(width: 130)
                        Text("\(Int(settings.defaultThickness))px")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }

            SettingsCard(title: "Preview") {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.penColor, lineWidth: CGFloat(settings.defaultThickness))
                        .frame(width: 120, height: 56)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Drawing

private struct DrawingContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Drawing Assistance") {
                Toggle("Snap to Grid", isOn: $settings.snapToGrid)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
                Toggle("Straight Line Assist", isOn: $settings.straightLineAssist)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
            }

            SettingsCard(title: "Grid Size") {
                SettingsRow(label: "Grid Size") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.gridSize, in: 10...50, step: 5)
                            .tint(Color(hex: "#F4644D") ?? .orange)
                            .frame(width: 130)
                        Text("\(Int(settings.gridSize))px")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .disabled(!settings.snapToGrid)
                .opacity(settings.snapToGrid ? 1 : 0.4)
            }

            SettingsCard(title: "Performance") {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(brandGradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Metal-accelerated rendering")
                            .font(.system(size: 12, weight: .medium))
                        Text("Optimised for Retina & 4K displays · < 10ms latency")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
        }
    }
}

// MARK: - Export

private struct ExportContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Default Format") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([("PNG Image", "png"), ("PDF Document", "pdf"), ("JPEG Image", "jpeg")],
                            id: \.1) { label, tag in
                        HStack {
                            Image(systemName: settings.exportFormat == tag
                                  ? "circle.inset.filled" : "circle")
                                .foregroundStyle(settings.exportFormat == tag
                                                 ? AnyShapeStyle(brandGradient)
                                                 : AnyShapeStyle(Color.white.opacity(0.35)))
                            Text(label).font(.system(size: 13))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { settings.exportFormat = tag }
                    }
                }
            }

            SettingsCard(title: "Quality") {
                SettingsRow(label: "Export Quality") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.exportQuality, in: 0.1...1.0, step: 0.1)
                            .tint(Color(hex: "#F4644D") ?? .orange)
                            .frame(width: 130)
                        Text("\(Int(settings.exportQuality * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                Text("Higher quality = larger file size")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }

            SettingsCard(title: "Options") {
                Toggle("Include Timestamp in Filename", isOn: $settings.includeTimestampInFilename)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
                Toggle("Open Exported File Automatically", isOn: $settings.autoOpenExport)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
                Toggle("Show Export Success Notification", isOn: $settings.showExportNotification)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
            }
        }
    }
}

// MARK: - Advanced

private struct AdvancedContent: View {
    @ObservedObject var settings: SettingsStore
    @Binding var showReset: Bool

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Settings Backup") {
                HStack(spacing: 10) {
                    Button("Export Settings") { exportSettings() }
                        .buttonStyle(BrandButtonStyle(outline: true))
                    Button("Import Settings") { importSettings() }
                        .buttonStyle(BrandButtonStyle(outline: true))
                }
            }

            SettingsCard(title: "Reset") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Restore all preferences to their default values.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Button("Reset to Defaults") { showReset = true }
                        .buttonStyle(BrandButtonStyle(destructive: true))
                }
            }

            SettingsCard(title: "About") {
                VStack(alignment: .leading, spacing: 4) {
                    infoRow("Version",
                            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    infoRow("Build",
                            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
                    infoRow("Bundle ID", Bundle.main.bundleIdentifier ?? "—")
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Settings"
        savePanel.nameFieldStringValue = "Pointly Settings.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: settings.exportSettings(),
                                                     options: .prettyPrinted)
                try data.write(to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Settings"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    settings.importSettings(dict)
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}

// MARK: - Brand Button Style

private struct BrandButtonStyle: ButtonStyle {
    var outline = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(destructive ? .white : outline ? (Color(hex: "#FF8C42") ?? .orange) : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Group {
                    if destructive {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.7))
                    } else if outline {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(hex: "#FF8C42") ?? .orange, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(brandGradient)
                    }
                }
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Window Drag Handle

private struct SettingsDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ v: DragView, context: Context) {}

    class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}

// MARK: - Shortcuts

private struct ShortcutsContent: View {
    @ObservedObject private var store = ToolBindingsStore.shared

    private let sections: [(title: String, tools: [DrawingTool])] = [
        ("Draw Tools", [.select, .cursor, .pen, .highlighter, .marker,
                        .blurBrush, .eraser, .text, .laserPointer, .spotlight, .dotPen, .cutMove]),
        ("Lines",  [.arrow, .line]),
        ("Shapes", [.rectangle, .ellipse, .triangle, .diamond]),
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.4))
                Text("Shortcuts work globally while Pointly is running. Combine a modifier key (⌃ ⌥ ⇧ ⌘) with any key — e.g. ⌃1.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))

            ForEach(sections, id: \.title) { section in
                SettingsCard(title: section.title) {
                    VStack(spacing: 0) {
                        ForEach(Array(section.tools.enumerated()), id: \.element) { idx, tool in
                            ShortcutRow(tool: tool, store: store)
                            if idx < section.tools.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.7)
                                    .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }

            SettingsCard(title: "Built-in Shortcuts") {
                VStack(spacing: 0) {
                    ForEach(Array(builtInShortcuts.enumerated()), id: \.offset) { idx, row in
                        HStack {
                            Text(row.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text(row.keys)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(RoundedRectangle(cornerRadius: 5)
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7))
                                )
                        }
                        .padding(.vertical, 6)
                        if idx < builtInShortcuts.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 0.7)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Reset to Defaults") { store.resetToDefaults() }
                    .buttonStyle(BrandButtonStyle(outline: true))
            }
        }
    }

    private let builtInShortcuts: [(label: String, keys: String)] = [
        ("Clear all drawings",   "⌘⌫"),
        ("Undo",                 "⌘Z"),
        ("Redo",                 "⌘⇧Z"),
        ("Delete selected",      "⌫"),
        ("Toggle draw / interact", "Esc"),
    ]
}

private struct ShortcutRow: View {
    let tool: DrawingTool
    @ObservedObject var store: ToolBindingsStore
    @ObservedObject private var pro = ProManager.shared

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 26, height: 26)
                Image(systemName: tool.systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(tool.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    if pro.isLocked(tool) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(brandGradient)
                    }
                }
                Text(tool.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            ToolHotkeyRecorder(tool: tool, store: store)
        }
        .padding(.vertical, 5)
    }
}

private struct ToolHotkeyRecorder: View {
    let tool: DrawingTool
    @ObservedObject var store: ToolBindingsStore
    @State private var isRecording = false
    @State private var monitor: Any?

    private var current: String { store.bindings[tool] ?? "" }

    var body: some View {
        HStack(spacing: 5) {
            if !current.isEmpty {
                Text(current)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7))
                    )
            }

            Button(isRecording ? "Cancel" : (current.isEmpty ? "Set" : "Change")) {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(BrandButtonStyle(outline: true))

            if !current.isEmpty && !isRecording {
                Button { store.clearBinding(for: tool) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                self.stopRecording()
            } else {
                let shortcut = self.formatShortcut(from: event)
                if !shortcut.isEmpty {
                    self.store.setBinding(shortcut, for: self.tool)
                    self.stopRecording()
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func formatShortcut(from event: NSEvent) -> String {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return "" }
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option)  { parts.append("⌥") }
        if mods.contains(.shift)   { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        guard let c = event.charactersIgnoringModifiers?.uppercased(),
              !c.isEmpty, c != "\u{1b}" else { return "" }
        parts.append(c)
        return parts.joined()
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: View {
    @Binding var hotkey: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? "Press shortcut…" : hotkey)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? (Color(hex: "#F4644D") ?? .orange).opacity(0.15)
                              : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color(hex: "#F4644D") ?? .orange : Color.white.opacity(0.12),
                                        lineWidth: 1)
                        )
                )

            Button(isRecording ? "Cancel" : "Change") {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(BrandButtonStyle(outline: true))
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode != 53 else { self.stopRecording(); return nil }
            self.hotkey = self.formatHotkey(from: event)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func formatHotkey(from event: NSEvent) -> String {
        var parts: [String] = []
        let f = event.modifierFlags
        if f.contains(.command) { parts.append("⌘") }
        if f.contains(.shift)   { parts.append("⇧") }
        if f.contains(.option)  { parts.append("⌥") }
        if f.contains(.control) { parts.append("⌃") }
        if let c = event.charactersIgnoringModifiers?.uppercased(), !c.isEmpty { parts.append(c) }
        return parts.joined()
    }
}
