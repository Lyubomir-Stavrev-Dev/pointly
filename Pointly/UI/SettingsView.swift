import SwiftUI

/// Settings window for configuring Pointly preferences
struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var showResetAlert = false
    @State private var showImportExport = false
    
    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AppearanceSettingsView(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            DrawingSettingsView(settings: settings)
                .tabItem {
                    Label("Drawing", systemImage: "pencil")
                }
            
            ExportSettingsView(settings: settings)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            
            AdvancedSettingsView(settings: settings, showResetAlert: $showResetAlert)
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 600, height: 500)
        .alert("Reset Settings", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This action cannot be undone.")
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Toggle Overlay:")
                    Spacer()
                    Text(settings.globalHotkey)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    Button("Change") {
                        // TODO: Implement hotkey recorder
                    }
                    .buttonStyle(.bordered)
                }
                
                Toggle("Show Toolbar on Startup", isOn: $settings.showToolbarOnStartup)
            }
            
            Section("Startup") {
                Picker("Behavior:", selection: $settings.startupBehavior) {
                    Text("Show in Menu Bar").tag("menubar")
                    Text("Show in System Tray").tag("tray")
                    Text("Start Hidden").tag("hidden")
                }
                .pickerStyle(RadioGroupPickerStyle())
                
                Toggle("Auto-save Annotations", isOn: $settings.autoSaveAnnotations)
            }
            
            Section("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pointly requires screen recording permission to function properly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open System Preferences") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    }
                }
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Toolbar Theme:", selection: $settings.toolbarTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("Default Drawing Settings") {
                HStack {
                    Text("Pen Color:")
                    Spacer()
                    ColorPicker("", selection: $settings.penColor)
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Stroke Thickness:")
                    Spacer()
                    Slider(value: $settings.defaultThickness, in: 1...10, step: 1)
                        .frame(width: 150)
                    Text("\(Int(settings.defaultThickness))px")
                        .frame(width: 30)
                }
            }
            
            Section("Preview") {
                HStack {
                    Text("Preview:")
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.penColor, lineWidth: CGFloat(settings.defaultThickness))
                        .frame(width: 100, height: 50)
                }
            }
        }
        .padding()
    }
}

struct DrawingSettingsView: View {
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Drawing Assistance") {
                Toggle("Snap to Grid", isOn: $settings.snapToGrid)
                Toggle("Straight Line Assist", isOn: $settings.straightLineAssist)
            }
            
            Section("Grid Settings") {
                HStack {
                    Text("Grid Size:")
                    Spacer()
                    Slider(value: .constant(20), in: 10...50, step: 5)
                        .frame(width: 150)
                    Text("20px")
                        .frame(width: 40)
                }
                .disabled(!settings.snapToGrid)
                
                ColorPicker("Grid Color:", selection: .constant(Color.gray.opacity(0.3)))
                    .disabled(!settings.snapToGrid)
            }
            
            Section("Performance") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drawing Latency Target: < 10ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Optimized for Retina/4K displays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct ExportSettingsView: View {
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Default Export Format") {
                Picker("Format:", selection: $settings.exportFormat) {
                    Text("PNG Image").tag("png")
                    Text("PDF Document").tag("pdf")
                    Text("JPEG Image").tag("jpeg")
                }
                .pickerStyle(RadioGroupPickerStyle())
            }
            
            Section("Export Quality") {
                HStack {
                    Text("Quality:")
                    Spacer()
                    Slider(value: $settings.exportQuality, in: 0.1...1.0, step: 0.1)
                        .frame(width: 150)
                    Text("\(Int(settings.exportQuality * 100))%")
                        .frame(width: 40)
                }
                
                Text("Higher quality results in larger file sizes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Export Options") {
                Toggle("Include Timestamp in Filename", isOn: .constant(true))
                Toggle("Open Exported File Automatically", isOn: .constant(true))
                Toggle("Show Export Success Notification", isOn: .constant(true))
            }
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Binding var showResetAlert: Bool
    @State private var showingImportExport = false
    
    var body: some View {
        Form {
            Section("Reset") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reset all settings to their default values")
                        .font(.headline)
                    
                    Text("This will restore all preferences to their original state. This action cannot be undone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Reset to Defaults") {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            
            Section("Import/Export Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backup and restore your settings")
                        .font(.headline)
                    
                    HStack {
                        Button("Export Settings") {
                            exportSettings()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Import Settings") {
                            importSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section("Debug Information") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version: 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Settings"
        savePanel.nameFieldStringValue = "Pointly Settings.json"
        savePanel.allowedContentTypes = [.json]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                let settingsData = settings.exportSettings()
                let jsonData = try JSONSerialization.data(withJSONObject: settingsData, options: .prettyPrinted)
                try jsonData.write(to: url)
                
                // Show success notification
                let notification = NSUserNotification()
                notification.title = "Settings Exported"
                notification.informativeText = "Settings have been exported successfully"
                NSUserNotificationCenter.default.deliver(notification)
                
            } catch {
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = "Could not export settings: \(error.localizedDescription)"
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
                let jsonData = try Data(contentsOf: url)
                let settingsData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                
                if let settingsData = settingsData {
                    settings.importSettings(settingsData)
                    
                    // Show success notification
                    let notification = NSUserNotification()
                    notification.title = "Settings Imported"
                    notification.informativeText = "Settings have been imported successfully"
                    NSUserNotificationCenter.default.deliver(notification)
                }
                
            } catch {
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = "Could not import settings: \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }
}

#Preview {
    SettingsView()
}
