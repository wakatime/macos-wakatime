import ServiceManagement
import SwiftUI

@main
struct WakaTime: App {
    @Environment(\.openWindow) private var openWindow
    
    @StateObject private var settings = SettingsModel()
    @State private var lastFile: String = ""
    @State private var lastTime: TimeInterval = 0
    
    let watcher = Watcher()
    let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String

    enum Constants {
        static let settingsDeepLink: String = "wakatime://settings"
    }

    init() {
        registerAsLoginItem()
        self.isCLILatest { [self] isLatest in
            if !isLatest { self.downloadCLI() }
        }
        requestA11yPermission()
        watcher.changeHandler = documentChanged
        checkForApiKey()
    }

    var body: some Scene {
        MenuBarExtra("WakaTime", image:"WakaTime") {
            Button("Dashboard") { self.dashboard() }
            Button("Settings") {
                promptForApiKey()
            }
            Divider()
            Button("Quit") { self.quit() }
        }
        WindowGroup("WakaTime Settings", id: "settings") {
            SettingsView(apiKey: $settings.apiKey)
        }.handlesExternalEvents(matching: ["settings"])
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
    
    private func getLatestVersion(completion: @escaping ((String?, Error?) -> Void)) {
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
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data, let httpResponse = response as? HTTPURLResponse else {
                completion(nil, error)
                return
            }
            if httpResponse.statusCode == 304 {
                DispatchQueue.main.async {
                    // Current version is still the latest version available
                    completion(currentVersion, nil)
                }
            } else if let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified"),
                      let release = try? JSONDecoder().decode(Release.self, from: data) {
                // Remote version successfully decoded
                ConfigFile.setSetting(section: "internal", key: "cli_version_last_modified", val: lastModified, internalConfig: true)
                ConfigFile.setSetting(section: "internal", key: "cli_version", val: release.tagName, internalConfig: true)
                DispatchQueue.main.async {
                    completion(release.tagName, nil)
                }
            } else {
                DispatchQueue.main.async {
                    // Unexpected response
                    completion(nil, nil)
                }
            }
        }.resume()
    }
    
    private func isCLILatest(completion: @escaping (Bool) -> Void) {
        let cli = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"])
        guard FileManager.default.fileExists(atPath: cli) else {
            completion(false)
            return
        }
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
            completion(false)
            return
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let version = output.firstMatch(of: /([0-9]+\.[0-9]+\.[0-9]+)/)
        getLatestVersion { remoteVersion, error in
            guard let remoteVersion, error == nil else {
                // Could not retrieve remote version
                completion(true)
                return
            }
            if let version, "v" + version.0 == remoteVersion {
                // Local version up to date
                completion(true)
            } else {
                // Newer version available
                completion(false)
            }
        }
    }
    
    private func downloadCLI() {
        let dir = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime"])
        if !FileManager.default.fileExists(atPath: dir) {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    
        let url = "https://github.com/wakatime/wakatime-cli/releases/latest/download/wakatime-cli-darwin-\(architecture()).zip"
        let zipFile = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli.zip"])
        let cli = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"])
        let cliReal = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli-darwin-\(architecture())"])
        if FileManager.default.fileExists(atPath: zipFile) {
            do {
                try FileManager.default.removeItem(atPath: zipFile)
            } catch {
                print(error.localizedDescription)
                return
            }
        }
        
        URLSession.shared.downloadTask(with: URLRequest(url: URL(string: url)!)) { u, r, e in
            guard let fileURL = u else { return }
            do {
                // download wakatime-cli.zip
                try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: zipFile))
                
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
    
    private func architecture() -> String {
        var systeminfo = utsname()
        uname(&systeminfo)
        let machine = withUnsafeBytes(of: &systeminfo.machine) {bufPtr->String in
            let data = Data(bufPtr)
            if let lastIndex = data.lastIndex(where: {$0 != 0}) {
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
        NSWorkspace.shared.open(URL(string:"https://wakatime.com/")!)
    }

    private func quit() {
        NSApp.terminate(self)
    }
    
    private func shouldSendHeartbeat(file: String, time: TimeInterval, isWrite: Bool) -> Bool {
        return isWrite || file != lastFile || lastTime + 120 < time
    }

    public func documentChanged(file: String, isWrite: Bool = false) {
        let time = NSDate().timeIntervalSince1970
        guard shouldSendHeartbeat(file: file, time: time, isWrite: isWrite) else { return }
        guard let xcodeVersion = watcher.xcodeVersion else {
            NSLog("Skipping \(file) because Xcode version unset.")
            return
        }
        
        lastFile = file
        lastTime = time
        
        let cli = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"])
        let process = Process()
        process.launchPath = cli
        var args = ["--entity", file, "--plugin", "xcode/\(xcodeVersion) xcode-wakatime/" + version]
        if isWrite {
            args.append("--write")
        }
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.launch()
    }
}

extension Optional where Wrapped: Collection {

    var isEmpty: Bool {
        return self?.isEmpty ?? true
    }

}
