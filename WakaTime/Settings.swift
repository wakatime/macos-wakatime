import Foundation
import SwiftUI

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
