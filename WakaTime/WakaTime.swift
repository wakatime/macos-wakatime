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

    init() {
        checkApiKey()
        registerAsLoginItem()
        downloadCLI()
        requestA11yPermission()
        watcher.changeHandler = documentChanged
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
    
    private func checkApiKey() {
        /*
        settings.apiKey = ConfigFile.getSetting(section: "settings", key: "api_key")
        if settings.apiKey == "" {
            openWindow(id: "settings")
            NSApp?.activate(ignoringOtherApps: true)
        }
        */
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
    
    private func shouldSendHeartbeat(file: String?, time: TimeInterval, isWrite: Bool) -> Bool {
        guard let file = file else { return false }
        return isWrite || file != lastFile || lastTime + 120 < time
    }

    public func documentChanged(file: String?, isWrite: Bool = false) {
        let time = NSDate().timeIntervalSince1970
        guard shouldSendHeartbeat(file: file, time: time, isWrite: isWrite) else { return }
        
        lastFile = file!
        lastTime = time
        
        let cli = NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime", "wakatime-cli"])
        let process = Process()
        process.launchPath = cli
        var args = ["--entity", file!, "--plugin", "xcode/unknown xcode-wakatime/" + version]
        if isWrite {
            args.append("--write")
        }
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.launch()
    }
}
