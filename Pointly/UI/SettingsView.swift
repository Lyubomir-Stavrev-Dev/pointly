import SwiftUI

// MARK: - Brand

private let brandGradient = LinearGradient(
    colors: [
        Color(hex: "#F4644D") ?? .orange ?? Color(red: 0.957, green: 0.392, blue: 0.302),
        Color(hex: "#FF8C42") ?? .orange,
        Color(hex: "#E9458C") ?? Color(red: 0.914, green: 0.271, blue: 0.549)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - SettingsView

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var selectedTab: SettingsTab = .general
    @State private var showResetAlert = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(width: 620, height: 480)
        .background(.regularMaterial)
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
        } message: {
            Text("Reset all settings to defaults? This cannot be undone.")
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo / header
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(brandGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "pencil.tip.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("Pointly")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(brandGradient)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Nav items
            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
        .frame(width: 148)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isActive = selectedTab == tab
        Button { selectedTab = tab } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color.secondary.opacity(0.12)))
                        .frame(width: 28, height: 28)
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isActive ? .white : .primary)
                }
                Text(tab.label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? Color.primary.opacity(0.06) : Color.clear)
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
                case .export:     ExportContent(settings: settings)
                case .advanced:   AdvancedContent(settings: settings, showReset: $showResetAlert)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedTab.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(brandGradient)
            Rectangle()
                .fill(brandGradient)
                .frame(height: 2)
                .cornerRadius(1)
        }
    }
}

// MARK: - Tab model

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, drawing, export, advanced
    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .drawing:    return "Drawing"
        case .export:     return "Export"
        case .advanced:   return "Advanced"
        }
    }
    var icon: String {
        switch self {
        case .general:    return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .drawing:    return "pencil.and.scribble"
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
                    .foregroundColor(.secondary)
                    .tracking(1.2)
                Spacer()
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
                                                 : AnyShapeStyle(Color.secondary))
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
                        .foregroundColor(.secondary)
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
                            .foregroundColor(isSelected ? .white : .primary)
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
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.secondary.opacity(0.1)))
            }

            SettingsCard(title: "Default Drawing") {
                SettingsRow(label: "Pen Color") {
                    ColorPicker("", selection: $settings.penColor)
                        .labelsHidden()
                        .frame(width: 36, height: 26)
                }

                SettingsRow(label: "Stroke Thickness") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.defaultThickness, in: 1...10, step: 1)
                            .tint(Color(hex: "#F4644D") ?? .orange)
                            .frame(width: 130)
                        Text("\(Int(settings.defaultThickness))px")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
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
                                                 : AnyShapeStyle(Color.secondary))
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
                            .foregroundColor(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                Text("Higher quality = larger file size")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
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
            .foregroundColor(destructive ? .white : outline ? Color(hex: "#F4644D") ?? .orange : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Group {
                    if destructive {
                        RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.8))
                    } else if outline {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#F4644D") ?? .orange, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(brandGradient)
                    }
                }
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color(hex: "#F4644D") ?? .orange.opacity(0.12)
                              : Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color(hex: "#F4644D") ?? .orange : Color.clear, lineWidth: 1)
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
