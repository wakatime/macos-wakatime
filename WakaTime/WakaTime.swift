import ServiceManagement
import SwiftUI

@main
// swiftlint:disable force_unwrapping
// swiftlint:disable force_try
struct WakaTime: App {
    @Environment(\.openWindow) private var openWindow

    @StateObject private var settings = SettingsModel()
    var state = State()

    let watcher = Watcher()

    enum Constants {
        static let settingsDeepLink: String = "wakatime://settings"
    }

    init() {
#if !DEBUG
        registerAsLoginItem()
#endif
        Task {
            if !(await Self.isCLILatest()) {
                Self.downloadCLI()
            }
        }
        requestA11yPermission()
        watcher.eventHandler = handleEvent
        checkForApiKey()
    }

    var body: some Scene {
        MenuBarExtra("WakaTime", image: "WakaTime") {
            Button("Dashboard") { self.dashboard() }
            Button("Settings") {
                promptForApiKey()
            }
            Button("Monitored Apps") {
                openWindow(id: "monitored_apps_container_view")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit") { self.quit() }
        }
        WindowGroup("WakaTime Settings", id: "settings") {
            SettingsView(apiKey: $settings.apiKey)
        }.handlesExternalEvents(matching: ["settings"])
        WindowGroup("Monitored Apps", id: "monitored_apps_container_view") {
            MonitoredAppsContainerView()
        }.handlesExternalEvents(matching: ["monitored_apps_container_view"])
    }

    private func checkForApiKey() {
        let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key")
        if apiKey.isEmpty {
            openSettingsDeeplink()
        }
    }

    private func promptForApiKey() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        settings.apiKey = ConfigFile.getSetting(section: "settings", key: "api_key") ?? ""
    }

    private func openSettingsDeeplink() {
        if let url = URL(string: Constants.settingsDeepLink) {
            NSWorkspace.shared.open(url)
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

    private func requestA11yPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        let appHasPermission = AXIsProcessTrustedWithOptions(options)
        if appHasPermission {
            // print("has a11y permission")
        }
    }

    private static func getLatestVersion() async throws -> String? {
        struct Release: Decodable {
            let tagName: String
            private enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
            }
        }

        let apiUrl = "https://api.github.com/repos/wakatime/wakatime-cli/releases/latest"
        var request = URLRequest(url: URL(string: apiUrl)!, cachePolicy: .reloadIgnoringCacheData)
        let lastModified = ConfigFile.getSetting(section: "internal", key: "cli_version_last_modified", internalConfig: true)
        let currentVersion = ConfigFile.getSetting(section: "internal", key: "cli_version", internalConfig: true)
        if let lastModified, currentVersion != nil {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        if httpResponse.statusCode == 304 {
            // Current version is still the latest version available
            return currentVersion
        } else if let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
                  let release = try? JSONDecoder().decode(Release.self, from: data) {
            // Remote version successfully decoded
            ConfigFile.setSetting(section: "internal", key: "cli_version_last_modified", val: lastModified, internalConfig: true)
            ConfigFile.setSetting(section: "internal", key: "cli_version", val: release.tagName, internalConfig: true)
            return release.tagName
        } else {
            // Unexpected response
            return nil
        }
    }

    private static func isCLILatest() async -> Bool {
        let cli = NSString.path(
            withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"]
        )
        guard FileManager.default.fileExists(atPath: cli) else { return false }

        let outputPipe = Pipe()
        let process = Process()
        process.launchPath = cli
        process.arguments = ["--version"]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            // Error running CLI process
            return false
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let version = output.firstMatch(of: /([0 - 9] + \.[0 - 9] + \.[0 - 9]+)/)
        let remoteVersion = try? await getLatestVersion()
        guard let remoteVersion else {
            // Could not retrieve remote version
            return true
        }
        if let version, "v" + version.0 == remoteVersion {
            // Local version up to date
            return true
        } else {
            // Newer version available
            return false
        }
    }

    private static func downloadCLI() {
        let dir = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime"])
        if !FileManager.default.fileExists(atPath: dir) {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }

        let url = "https://github.com/wakatime/wakatime-cli/releases/latest/download/wakatime-cli-darwin-\(architecture()).zip"
        let zipFile = NSString.path(
            withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli.zip"]
        )
        let cli = NSString.path(
            withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"]
        )
        let cliReal = NSString.path(
            withComponents:
                FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli-darwin-\(architecture())"]
        )

        if FileManager.default.fileExists(atPath: zipFile) {
            do {
                try FileManager.default.removeItem(atPath: zipFile)
            } catch {
                print(error.localizedDescription)
                return
            }
        }

        URLSession.shared.downloadTask(with: URLRequest(url: URL(string: url)!)) { fileUrl, _, _ in
            guard let fileUrl else { return }

            do {
                // download wakatime-cli.zip
                try FileManager.default.moveItem(at: fileUrl, to: URL(fileURLWithPath: zipFile))

                if FileManager.default.fileExists(atPath: cliReal) {
                    do {
                        try FileManager.default.removeItem(atPath: cliReal)
                    } catch {
                        print(error.localizedDescription)
                        return
                    }
                }

                // unzip wakatime-cli.zip
                let process = Process()
                process.launchPath = "/usr/bin/unzip"
                process.arguments = [zipFile, "-d", dir]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.launch()
                process.waitUntilExit()

                // cleanup wakatime-cli.zip
                try! FileManager.default.removeItem(atPath: zipFile)

                // create ~/.wakatime/wakatime-cli symlink
                do {
                    try FileManager.default.removeItem(atPath: cli)
                } catch { }
                try! FileManager.default.createSymbolicLink(atPath: cli, withDestinationPath: cliReal)

            } catch {
                print(error.localizedDescription)
            }
        }.resume()
    }

    private static func architecture() -> String {
        var systeminfo = utsname()
        uname(&systeminfo)
        let machine = withUnsafeBytes(of: &systeminfo.machine) {bufPtr -> String in
            let data = Data(bufPtr)
            if let lastIndex = data.lastIndex(where: { $0 != 0 }) {
                return String(data: data[0...lastIndex], encoding: .isoLatin1)!
            } else {
                return String(data: data, encoding: .isoLatin1)!
            }
        }
        if machine == "x86_64" {
            return "amd64"
        }
        return "arm64"
    }

    private func dashboard() {
        NSWorkspace.shared.open(URL(string: "https://wakatime.com/")!)
    }

    private func quit() {
        NSApp.terminate(self)
    }

    private func shouldSendHeartbeat(file: URL, time: Int, isWrite: Bool) -> Bool {
        guard
            !isWrite,
            file.formatted() == state.lastFile,
            state.lastTime + 120 > time
        else { return true }

        return false
    }

    public func handleEvent(file: URL, isWrite: Bool, isBuilding: Bool) {
        guard let xcodeVersion = watcher.xcodeVersion else { return }

        let time = Int(NSDate().timeIntervalSince1970)
        guard shouldSendHeartbeat(file: file, time: time, isWrite: isWrite) else { return }

        state.lastFile = file.formatted()
        state.lastTime = time

        let cli = NSString.path(
            withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"]
        )
        let process = Process()
        process.launchPath = cli
        var args = ["--entity", file.formatted(), "--plugin", "xcode/\(xcodeVersion) xcode-wakatime/" + Bundle.main.version]
        if isWrite {
            args.append("--write")
        }
        if isBuilding {
            args.append("--category")
            args.append("building")
        }
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.launch()
    }
}

extension Optional where Wrapped: Collection {
    var isEmpty: Bool {
        self?.isEmpty ?? true
    }
}
// swiftlint:enable force_unwrapping
// swiftlint:enable force_try

class State: ObservableObject {
    @Published var lastFile = ""
    @Published var lastTime = 0
}

struct MonitoredAppsContainerView: View {
    var body: some View {
        VStack {
            MonitoredAppsViewRepresentable()
        }
    }
}
