import ServiceManagement
import SwiftUI

@main
struct WakaTime: App {
    @Environment(\.openWindow) private var openWindow
    
    @StateObject private var settings = SettingsModel()

    init() {
        registerAsLoginItem()
    }

    var body: some Scene {
        MenuBarExtra("WakaTime", image:"WakaTime") {

            Button("Dashboard") { self.dashboard() }
            
            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
                settings.apiKey = ConfigFile.getSetting(section: "settings", key: "api_key")
            }

            Divider()

            Button("Quit") { self.quit() }
        }
        Window("Settings", id:"settings") {
            SettingsView(apiKey: $settings.apiKey)
        }
    }

    private func registerAsLoginItem() {
        guard SMAppService.mainApp.status == .notFound else { return }
        
        do {
            try SMAppService.mainApp.register()
        } catch let error {
            print(error)
        }
    }
    
    private func dashboard() {
        NSWorkspace.shared.open(URL(string:"https://wakatime.com/")!)
    }

    private func quit() {
        NSApp.terminate(self)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var apiKey: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("WakaTime API Key:")
                TextField("apikey", text: $apiKey)
                List {
                    HStack {
                        Button("Save") {
                            ConfigFile.setSetting(section: "settings", key: "api_key", val: $apiKey.wrappedValue)
                            dismiss()
                        }
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            for window in NSApplication.shared.windows {
                guard window.identifier?.rawValue == "settings" else { continue }
                window.standardWindowButton(.zoomButton)?.isEnabled = false
                window.standardWindowButton(.closeButton)?.isEnabled = false
                window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 400, height: 140), display: true)
            }
        }
    }
}

class SettingsModel : ObservableObject {
    @Published var apiKey = ""
}
