import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @SwiftUI.State private var isToggleOn = PropertiesManager.shouldLaunchOnLogin

    var body: some View {
        GeometryReader { geometry in
            HStack {
                VStack(alignment: .leading) {
                    Toggle("Launch on login", isOn: $isToggleOn)
                        .onChange(of: isToggleOn) { newValue in
                            if newValue {
                                SettingsManager.registerAsLoginItem()
                            } else {
                                SettingsManager.unregisterAsLoginItem()
                            }
                        }
                    Spacer()
                    Divider()
                    Spacer()
                    Text("WakaTime API Key:")
                    TextField("apikey", text: $apiKey).frame(width: 200)
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
                    Spacer()
                    Text("Version: \(Bundle.main.version) (\(Bundle.main.build))")
                        .padding(.top)
                }
                .padding()
                .frame(maxWidth: geometry.size.width)
            }
        }
        .task {
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                window.styleMask.insert(.closable)
                window.styleMask.remove(.miniaturizable)
                window.styleMask.remove(.resizable)
                window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: 400, height: 180), display: true)
            }
        }
    }
}

class SettingsModel: ObservableObject {
    @Published var apiKey = ""
}
