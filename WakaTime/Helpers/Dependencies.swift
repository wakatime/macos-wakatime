import Foundation

// swiftlint:disable force_unwrapping
// swiftlint:disable force_try
class Dependencies {
    public static func installDependencies() {
        Task {
            if !(await isCLILatest()) {
                downloadCLI()
            }
        }
    }

    public static var isLocalDevBuild: Bool {
        Bundle.main.version == "local-build"
    }

    public static func recentBrowserExtension() async -> String? {
        guard
            let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key"),
            !apiKey.isEmpty
        else { return nil }
        let url = "https://api.wakatime.com/api/v1/users/current/user_agents?api_key=\(apiKey)"
        let request = URLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringCacheData)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else { return nil }

            struct Resp: Decodable {
                let data: [UserAgent]
            }
            struct UserAgent: Decodable {
                let isBrowserExtension: Bool
                let editor: String?
                let lastSeenAt: String?
                enum CodingKeys: String, CodingKey {
                    case isBrowserExtension = "is_browser_extension"
                    case editor
                    case lastSeenAt = "last_seen_at"
                }
            }

            let release = try JSONDecoder().decode(Resp.self, from: data)
            let now = Date()
            for agent in release.data {
                guard
                    agent.isBrowserExtension,
                    let editor = agent.editor,
                    !editor.isEmpty,
                    let lastSeenAt = agent.lastSeenAt
                else { continue }

                let isoDateFormatter = ISO8601DateFormatter()
                isoDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                isoDateFormatter.formatOptions = [.withInternetDateTime]
                if let lastSeen = isoDateFormatter.date(from: lastSeenAt) {
                    if now.timeIntervalSince(lastSeen) > 600 {
                        break
                    }
                }

                return agent.editor
            }
        } catch {
            Logging.default.log("Request error checking for conflicting browser extension: \(error)")
            return nil
        }
        return nil
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

        let now = Int(NSDate().timeIntervalSince1970)
        ConfigFile.setSetting(section: "internal", key: "cli_version_last_accessed", val: String(now), internalConfig: true)

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
            withComponents: ConfigFile.resourcesFolder + ["wakatime-cli"]
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

        // disable updating wakatime-cli when it was built from source
        if output.trim() == "<local-build>" {
            return true
        }

        let version: String?
        if let regex = try? NSRegularExpression(pattern: "([0-9]+\\.[0-9]+\\.[0-9]+)"),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range, in: output) {
            version = String(output[range])
        } else {
            version = nil
        }

        let accessed = ConfigFile.getSetting(section: "internal", key: "cli_version_last_accessed", internalConfig: true)
        if let accessed, let accessed = Int(accessed) {
            let now = Int(NSDate().timeIntervalSince1970)
            let fourHours = 4 * 3600
            if accessed + fourHours > now {
                Logging.default.log("Skip checking for wakatime-cli updates because recently checked \(now - accessed) seconds ago")
                return true
            }
        }

        let remoteVersion = try? await getLatestVersion()
        guard let remoteVersion else {
            // Could not retrieve remote version
            return true
        }
        if let version, "v" + version == remoteVersion {
            // Local version up to date
            return true
        } else {
            // Newer version available
            return false
        }
    }

    private static func downloadCLI() {
        let dir = NSString.path(withComponents: ConfigFile.resourcesFolder)
        if !FileManager.default.fileExists(atPath: dir) {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Logging.default.log(error.localizedDescription)
            }
        }

        let url = "https://github.com/wakatime/wakatime-cli/releases/latest/download/wakatime-cli-darwin-\(architecture()).zip"
        let zipFile = NSString.path(withComponents: ConfigFile.resourcesFolder + ["wakatime-cli.zip"])
        let cli = NSString.path(withComponents: ConfigFile.resourcesFolder + ["wakatime-cli"])
        let cliReal = NSString.path(withComponents: ConfigFile.resourcesFolder + ["wakatime-cli-darwin-\(architecture())"])

        if FileManager.default.fileExists(atPath: zipFile) {
            do {
                try FileManager.default.removeItem(atPath: zipFile)
            } catch {
                Logging.default.log(error.localizedDescription)
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
                        Logging.default.log(error.localizedDescription)
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
                Logging.default.log(error.localizedDescription)
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
}
// swiftlint:enable force_unwrapping
// swiftlint:enable force_try
