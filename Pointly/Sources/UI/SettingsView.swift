import SwiftUI

/// Settings window for configuring Pointly preferences
struct SettingsView: View {
    @AppStorage("globalHotkey") private var globalHotkey = "⌘⇧P"
    @AppStorage("toolbarTheme") private var toolbarTheme = "system"
    @AppStorage("startupBehavior") private var startupBehavior = "menubar"
    @AppStorage("snapToGrid") private var snapToGrid = false
    @AppStorage("straightLineAssist") private var straightLineAssist = true
    @AppStorage("defaultPenColor") private var defaultPenColor = "#FF3B30"
    @AppStorage("defaultThickness") private var defaultThickness = 3.0
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                globalHotkey: $globalHotkey,
                startupBehavior: $startupBehavior
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppearanceSettingsView(
                toolbarTheme: $toolbarTheme,
                defaultPenColor: $defaultPenColor,
                defaultThickness: $defaultThickness
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            DrawingSettingsView(
                snapToGrid: $snapToGrid,
                straightLineAssist: $straightLineAssist
            )
            .tabItem {
                Label("Drawing", systemImage: "pencil")
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @Binding var globalHotkey: String
    @Binding var startupBehavior: String
    
    var body: some View {
        Form {
            Section("Global Hotkey") {
                HStack {
                    Text("Toggle Overlay:")
                    Spacer()
                    // TODO: Implement hotkey recorder
                    Text(globalHotkey)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Section("Startup") {
                Picker("Behavior:", selection: $startupBehavior) {
                    Text("Show in Menu Bar").tag("menubar")
                    Text("Show in System Tray").tag("tray")
                    Text("Start Hidden").tag("hidden")
                }
                .pickerStyle(RadioGroupPickerStyle())
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
    @Binding var toolbarTheme: String
    @Binding var defaultPenColor: String
    @Binding var defaultThickness: Double
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Toolbar Theme:", selection: $toolbarTheme) {
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
                    // TODO: Implement color picker that saves hex values
                    ColorPicker("", selection: .constant(Color.red))
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Stroke Thickness:")
                    Spacer()
                    Slider(value: $defaultThickness, in: 1...10, step: 1)
                        .frame(width: 150)
                    Text("\(Int(defaultThickness))px")
                        .frame(width: 30)
                }
            }
            
            Section("Preview") {
                HStack {
                    Text("Preview:")
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: CGFloat(defaultThickness))
                        .frame(width: 100, height: 50)
                }
            }
        }
        .padding()
    }
}

struct DrawingSettingsView: View {
    @Binding var snapToGrid: Bool
    @Binding var straightLineAssist: Bool
    
    var body: some View {
        Form {
            Section("Drawing Assistance") {
                Toggle("Snap to Grid", isOn: $snapToGrid)
                Toggle("Straight Line Assist", isOn: $straightLineAssist)
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

#Preview {
    SettingsView()
}
