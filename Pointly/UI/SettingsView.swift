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
    @State private var recordingTool: DrawingTool? = nil

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                content
            }

            if let tool = recordingTool {
                ShortcutRecorderOverlay(tool: tool, onDismiss: { recordingTool = nil })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: 700, height: 540)
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
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: recordingTool == nil)
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
            ZStack {
                SettingsDragHandle()
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brandGradient)
                    Text("Pointly")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(brandGradient)
                }
            }
            .frame(height: 46)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            Spacer()

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.22))
                .padding(.bottom, 14)
        }
        .frame(width: 158)
        .background(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func sidebarItem(_ tab: SettingsTab) -> some View {
        SidebarItemButton(tab: tab, isActive: selectedTab == tab) { selectedTab = tab }
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
                case .shortcuts:  ShortcutsContent(onRecord: { recordingTool = $0 })
                case .export:     ExportContent(settings: settings)
                case .advanced:   AdvancedContent(settings: settings, showReset: $showResetAlert)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedTab.label)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

// MARK: - Sidebar item with hover

private struct SidebarItemButton: View {
    let tab: SettingsTab
    let isActive: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive
                                     ? AnyShapeStyle(brandGradient)
                                     : AnyShapeStyle(Color.white.opacity(hover ? 0.65 : 0.40)))
                    .frame(width: 18)
                Text(tab.label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(hover ? 0.80 : 0.55))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive
                          ? Color.white.opacity(0.09)
                          : hover ? Color.white.opacity(0.06) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isActive ? Color.white.opacity(0.10) : Color.clear, lineWidth: 0.5))
            )
            .animation(.easeInOut(duration: 0.10), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
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

// MARK: - Compact segment button with hover

private struct SegmentButton: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                }
                Text(label)
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .white.opacity(hover ? 0.72 : 0.46))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7).fill(brandGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(hover ? Color.white.opacity(0.07) : Color.clear)
                    }
                }
            )
            .animation(.easeInOut(duration: 0.10), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Hover-aware tappable row

private struct HoverRow: View {
    let action: () -> Void
    @ViewBuilder let content: () -> AnyView
    @State private var hover = false

    var body: some View {
        content()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7).fill(hover ? Color.white.opacity(0.05) : Color.clear))
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .onHover { hover = $0 }
            .animation(.easeInOut(duration: 0.10), value: hover)
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
                        HoverRow(action: { settings.startupBehavior = tag }) {
                            AnyView(HStack {
                                Image(systemName: settings.startupBehavior == tag
                                      ? "circle.inset.filled" : "circle")
                                    .foregroundStyle(settings.startupBehavior == tag
                                                     ? AnyShapeStyle(brandGradient)
                                                     : AnyShapeStyle(Color.white.opacity(0.35)))
                                Text(title).font(.system(size: 13))
                                Spacer()
                            })
                        }
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
                        SegmentButton(label: label, isSelected: settings.toolbarTheme == tag) {
                            settings.toolbarTheme = tag
                        }
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.07)))
            }

            SettingsCard(title: "Toolbar Size") {
                ToolbarSizeControl(settings: settings)
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

// MARK: - Toolbar size control

private struct ToolbarSizeControl: View {
    @ObservedObject var settings: SettingsStore
    @State private var isSliding = false

    private static let presets: [(label: String, scale: Double)] = [
        ("Compact", 0.9), ("Default", 1.12), ("Large", 1.3)
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Live mini preview — solid neutral background avoids glass bleed-through
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(brandGradient)
                        .frame(width: 20, height: 8)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 3) {
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
                        }
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                )
                .scaleEffect(settings.toolbarScale)
                .frame(width: 60, height: 78)
                .animation(isSliding ? nil : .spring(response: 0.3, dampingFraction: 0.75),
                           value: settings.toolbarScale)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.10)))

            // Preset chips
            HStack(spacing: 0) {
                ForEach(Self.presets, id: \.label) { preset in
                    let isSelected = settings.toolbarScale == preset.scale
                    SegmentButton(label: preset.label, isSelected: isSelected) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            settings.toolbarScale = preset.scale
                        }
                    }
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.07)))

            // Fine-tune slider between small/large toolbar glyphs
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Slider(value: $settings.toolbarScale, in: 0.8...1.4,
                       onEditingChanged: { isSliding = $0 })
                    .tint(Color(hex: "#F4644D") ?? .orange)
                Image(systemName: "rectangle.portrait")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
                Text("\(Int((settings.toolbarScale * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }
}

// MARK: - Drawing

private struct DrawingContent: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var pro = ProManager.shared

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "Drawing Assistance") {
                Toggle("Snap to Grid", isOn: $settings.snapToGrid)
                    .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Straight Line Assist")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                    HStack(spacing: 0) {
                        ForEach([("Off", "off"), ("Low", "low"), ("High", "high")], id: \.1) { label, tag in
                            let locked = tag == "high" && !pro.isPro
                            SegmentButton(
                                label: label,
                                icon: locked ? "lock.fill" : nil,
                                isSelected: settings.straightLineAssistLevel == tag
                            ) {
                                if locked {
                                    NotificationCenter.default.post(name: .showPaywallForPlan,
                                                                    object: ProPlan.annual)
                                } else {
                                    settings.straightLineAssistLevel = tag
                                }
                            }
                        }
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.07)))
                    Text("Low keeps lines and shapes clean. High (Pro) adds magnetic 0°/45°/90° angle snapping and straightens nearly-straight pen strokes.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Arrow Tip at First Click", isOn: $settings.arrowTipAtStart)
                        .toggleStyle(.switch).tint(Color(hex: "#F4644D") ?? .orange)
                    Text("On: the tip sits where you press, tail follows the drag. Off: the tip lands where you release.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                        Text("Native rendering engine")
                            .font(.system(size: 12, weight: .medium))
                        Text("Optimised for Retina & 4K displays")
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
                        HoverRow(action: { settings.exportFormat = tag }) {
                            AnyView(HStack {
                                Image(systemName: settings.exportFormat == tag
                                      ? "circle.inset.filled" : "circle")
                                    .foregroundStyle(settings.exportFormat == tag
                                                     ? AnyShapeStyle(brandGradient)
                                                     : AnyShapeStyle(Color.white.opacity(0.35)))
                                Text(label).font(.system(size: 13))
                                Spacer()
                            })
                        }
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
                HStack(spacing: 8) {
                    Button("Export Settings") { exportSettings() }
                        .buttonStyle(SubtleButtonStyle())
                    Button("Import Settings") { importSettings() }
                        .buttonStyle(SubtleButtonStyle())
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

// MARK: - Subtle Button Style (inline secondary actions)

private struct SubtleButtonStyle: ButtonStyle {
    var recording = false
    func makeBody(configuration: Configuration) -> some View {
        SubtleBody(configuration: configuration, recording: recording)
    }
    struct SubtleBody: View {
        let configuration: ButtonStyleConfiguration
        let recording: Bool
        @State private var hover = false
        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(recording
                                 ? (Color(hex: "#F4644D") ?? .orange)
                                 : hover ? .white : .white.opacity(0.65))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(configuration.isPressed ? Color.white.opacity(0.16)
                              : hover ? Color.white.opacity(0.12) : Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(hover ? 0.14 : 0.10), lineWidth: 0.5))
                )
                .animation(.easeInOut(duration: 0.10), value: hover)
                .onHover { hover = $0 }
        }
    }
}

// MARK: - Brand Button Style

private struct BrandButtonStyle: ButtonStyle {
    var outline = false
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        BrandBody(configuration: configuration, outline: outline, destructive: destructive)
    }
    struct BrandBody: View {
        let configuration: ButtonStyleConfiguration
        let outline: Bool
        let destructive: Bool
        @State private var hover = false
        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(destructive ? .white : outline ? (Color(hex: "#FF8C42") ?? .orange) : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if destructive {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(hover ? Color.red.opacity(0.85) : Color.red.opacity(0.7))
                        } else if outline {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(hover ? (Color(hex: "#FF8C42") ?? .orange).opacity(0.12) : Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "#FF8C42") ?? .orange, lineWidth: 1.5))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(brandGradient)
                                .brightness(hover ? 0.06 : 0)
                        }
                    }
                )
                .scaleEffect(hover && !outline && !destructive ? 1.015 : 1.0)
                .opacity(configuration.isPressed ? 0.72 : 1)
                .animation(.easeInOut(duration: 0.11), value: hover)
                .onHover { hover = $0 }
        }
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
    let onRecord: (DrawingTool) -> Void

    private let sections: [(title: String, tools: [DrawingTool])] = [
        ("Draw Tools", [.select, .cursor, .pen, .highlighter, .marker,
                        .blurBrush, .eraser, .text, .laserPointer, .spotlight, .dotPen, .cutMove,
                        .textCallout, .stepBadge]),
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
                            ShortcutRow(tool: tool, store: store, onRecord: { onRecord(tool) })
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
                    .buttonStyle(SubtleButtonStyle())
            }
        }
    }

    private let builtInShortcuts: [(label: String, keys: String)] = [
        ("Clear all drawings",     "⌘⌫"),
        ("Undo",                   "⌘Z"),
        ("Redo",                   "⌘⇧Z"),
        ("Delete selected",        "⌫"),
        ("Toggle draw / interact", "⌘Esc"),
        ("Increase size",          "⌘="),
        ("Decrease size",          "⌘−"),
    ]
}

private struct ShortcutRow: View {
    let tool: DrawingTool
    @ObservedObject var store: ToolBindingsStore
    @ObservedObject private var pro = ProManager.shared
    let onRecord: () -> Void
    @State private var hover    = false
    @State private var xHover   = false

    private var current: String { store.bindings[tool] ?? "" }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(hover ? 0.12 : 0.08))
                    .frame(width: 26, height: 26)
                ToolIconView(tool: tool, size: 12)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(hover ? 0.95 : 0.75))
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(tool.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(hover ? 1 : 0.9))
                    if pro.isLocked(tool) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(brandGradient)
                    }
                }
                Text(tool.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(hover ? 0.50 : 0.35))
                    .lineLimit(1)
            }

            Spacer()

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
                Button(current.isEmpty ? "Set" : "Change") { onRecord() }
                    .buttonStyle(SubtleButtonStyle())
                if !current.isEmpty {
                    Button { store.clearBinding(for: tool) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(xHover ? .white.opacity(0.80) : .white.opacity(0.35))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(xHover ? Color.white.opacity(0.12) : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .onHover { xHover = $0 }
                    .help("Clear shortcut")
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hover ? Color.white.opacity(0.04) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.10), value: hover)
        .onHover { hover = $0 }
    }
}

// MARK: - Shortcut Recorder Overlay

private struct ShortcutRecorderOverlay: View {
    let tool: DrawingTool
    let onDismiss: () -> Void

    @ObservedObject private var store = ToolBindingsStore.shared
    @ObservedObject private var pro   = ProManager.shared

    @State private var liveKeys      = ""
    @State private var pendingShortcut = ""
    @State private var conflictTool: DrawingTool? = nil
    @State private var phase: RecordPhase = .waiting
    @State private var flagMonitor: Any?
    @State private var keyMonitor: Any?

    private static let reservedShortcuts: Set<String> = [
        "⌘⌫", "⌘Z", "⌘⇧Z", "⌘=", "⌘−", "⌘W"
    ]

    enum RecordPhase: Equatable { case waiting, toolConflict, reserved, success }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 30, height: 30)
                        ToolIconView(tool: tool, size: 13)
                            .foregroundColor(.white.opacity(0.80))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Set Shortcut")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(tool.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.42))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

                Divider().overlay(Color.white.opacity(0.08))

                // Key cap display
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    if liveKeys.isEmpty && phase == .waiting {
                        Text("Press your shortcut…")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.28))
                    } else {
                        keyCapsView
                    }
                }
                .frame(height: 68)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)

                Divider().overlay(Color.white.opacity(0.08))

                // Status area
                statusArea
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.13))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 32, x: 0, y: 12)
        }
        .onAppear { installMonitors() }
        .onDisappear { removeMonitors() }
    }

    // Individual key caps for the shortcut
    @ViewBuilder
    private var keyCapsView: some View {
        HStack(spacing: 5) {
            ForEach(Array(liveKeys.unicodeScalars.map { String($0) }.enumerated()), id: \.offset) { _, char in
                keyCap(char, color: capColor)
            }
        }
    }

    private var capColor: Color {
        switch phase {
        case .toolConflict: return Color(hex: "#F4644D") ?? .orange
        case .reserved:     return Color(hex: "#F4644D") ?? .orange
        case .success:      return .green
        case .waiting:      return .white
        }
    }

    private func keyCap(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(color)
            .frame(minWidth: 34, minHeight: 34)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(color.opacity(0.30), lineWidth: 0.8)
                    )
            )
            .animation(.easeInOut(duration: 0.12), value: phase)
    }

    @ViewBuilder
    private var statusArea: some View {
        switch phase {
        case .waiting:
            Text("Needs at least one modifier  ⌃ ⌥ ⇧ ⌘")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.30))
                .frame(maxWidth: .infinity, alignment: .center)

        case .toolConflict:
            VStack(spacing: 10) {
                if let c = conflictTool {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#F4644D") ?? .orange)
                        Text("Already used by **\(c.displayName)**")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                HStack(spacing: 8) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(SubtleButtonStyle())
                    Button("Reassign to \(tool.displayName)") { reassign() }
                        .buttonStyle(SubtleButtonStyle(recording: true))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .reserved:
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#F4644D") ?? .orange)
                Text("This shortcut is reserved by Pointly")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .center)

        case .success:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
                Text("Shortcut saved!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.80))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func installMonitors() {
        NotificationCenter.default.post(name: .pauseToolHotkeys, object: nil)

        flagMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            guard self.phase == .waiting else { return event }
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            var parts: [String] = []
            if mods.contains(.control) { parts.append("⌃") }
            if mods.contains(.option)  { parts.append("⌥") }
            if mods.contains(.shift)   { parts.append("⇧") }
            if mods.contains(.command) { parts.append("⌘") }
            self.liveKeys = parts.joined()
            return event
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { self.dismiss(); return nil }
            guard self.phase == .waiting else { return nil }

            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty,
                  let char = event.charactersIgnoringModifiers?.uppercased(),
                  !char.isEmpty, char != "\u{1b}" else {
                // Bare key (no modifier) — flash a reminder
                return nil
            }

            var parts: [String] = []
            if mods.contains(.control) { parts.append("⌃") }
            if mods.contains(.option)  { parts.append("⌥") }
            if mods.contains(.shift)   { parts.append("⇧") }
            if mods.contains(.command) { parts.append("⌘") }
            parts.append(char)
            let shortcut = parts.joined()

            self.liveKeys = shortcut

            // Reserved check
            if Self.reservedShortcuts.contains(shortcut) {
                self.phase = .reserved
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    self.phase = .waiting
                    self.liveKeys = ""
                }
                return nil
            }

            // Tool conflict check (exclude self)
            if let conflicting = self.store.bindings.first(where: {
                $0.key != self.tool && Set($0.value) == Set(shortcut)
            })?.key {
                self.pendingShortcut = shortcut
                self.conflictTool    = conflicting
                self.phase           = .toolConflict
                return nil
            }

            // All clear — commit
            self.store.setBinding(shortcut, for: self.tool)
            self.phase = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.dismiss() }
            return nil
        }
    }

    private func removeMonitors() {
        if let m = flagMonitor { NSEvent.removeMonitor(m); flagMonitor = nil }
        if let m = keyMonitor  { NSEvent.removeMonitor(m); keyMonitor  = nil }
        NotificationCenter.default.post(name: .resumeToolHotkeys, object: nil)
    }

    private func reassign() {
        guard let c = conflictTool else { return }
        store.clearBinding(for: c)
        store.setBinding(pendingShortcut, for: tool)
        conflictTool = nil
        phase = .success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
    }

    private func dismiss() {
        removeMonitors()
        onDismiss()
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
            .buttonStyle(SubtleButtonStyle(recording: isRecording))
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode != 53 else { self.stopRecording(); return nil }
            // Invalid combos keep the current hotkey — accepting them would
            // either steal a bare key system-wide or persist a hotkey that
            // Carbon can't register (UI showing a shortcut that never fires).
            if let recorded = self.formatHotkey(from: event) {
                self.hotkey = recorded
            }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func formatHotkey(from event: NSEvent) -> String? {
        let f = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !f.isEmpty else { return nil }   // modifier-less = system-wide key theft
        var parts: [String] = []
        if f.contains(.command) { parts.append("⌘") }
        if f.contains(.shift)   { parts.append("⇧") }
        if f.contains(.option)  { parts.append("⌥") }
        if f.contains(.control) { parts.append("⌃") }
        guard let c = event.charactersIgnoringModifiers?.uppercased(), !c.isEmpty,
              GlobalHotkeyManager.keyCode(for: c) != nil else { return nil }   // must be registrable
        parts.append(c)
        let candidate = parts.joined()
        // Reject combos already owned by a tool binding (duplicate Carbon
        // registrations fail silently). Compare as character sets — the two
        // recorders emit modifiers in different orders.
        guard !ToolBindingsStore.shared.bindings.values.contains(where: { Set($0) == Set(candidate) })
        else { return nil }
        return candidate
    }
}
