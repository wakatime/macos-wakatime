import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var apiKey: String

    var body: some View {
        GeometryReader { _ in
            VStack {
                Text("WakaTime API Key:")
                TextField("apikey", text: $apiKey)
                HStack {
                    Button("Save") {
                        ConfigFile.setSetting(section: "settings", key: "api_key", val: $apiKey.wrappedValue)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding()
        }
        .task {
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                window.styleMask.insert(.closable)
                window.styleMask.remove(.miniaturizable)
                window.styleMask.remove(.resizable)
                window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 400, height: 140), display: true)
            }
        }
    }
}

class SettingsModel: ObservableObject {
    @Published var apiKey = ""
}
