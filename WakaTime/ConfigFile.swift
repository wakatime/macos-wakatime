import Foundation

struct ConfigFile {
    private static var filePath: String {
        NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime.cfg"])
    }

    private static var filePathInternal: String {
        NSString.path(withComponents: FileManager.default.homeDirectoryForCurrentUser.pathComponents + [".wakatime-internal.cfg"])
    }

    static func getSetting(section: String, key: String, internalConfig: Bool = false) -> String? {
        let file = internalConfig ? filePathInternal : filePath
        let contents: String
        do {
            contents = try String(contentsOfFile: file)
        } catch {
            print("Failed reading \(file): " + error.localizedDescription)
            return nil
        }
        let lines = contents.split(separator: "\n")

        var currentSection = ""
        for line in lines {
            if line.hasPrefix("[") && line.hasSuffix("]") {
                currentSection = String(line.dropFirst().dropLast())
            } else if currentSection == section {
                let parts = line.split(separator: "=", maxSplits: 2)
                if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    return String(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        return nil
    }

    static func setSetting(section: String, key: String, val: String, internalConfig: Bool = false) {
        let file = internalConfig ? filePathInternal : filePath
        let contents: String
        do {
            contents = try String(contentsOfFile: file)
        } catch {
            contents = "[" + section + "]\n" + key + " = " + val
            do {
                try contents.write(to: URL(fileURLWithPath: file), atomically: true, encoding: .utf8)
            } catch {
                assertionFailure("Failed writing to URL: \(file), Error: " + error.localizedDescription)
            }
        }

        let lines = contents.split(separator: "\n")
        var output: [String] = []
        var currentSection = ""
        var found = false
        for line in lines {
            if line.hasPrefix("[") && line.hasSuffix("]") {
                if currentSection == section && !found {
                    output.append(key + " = " + val)
                    found = true
                }
                output.append(String(line))
                currentSection = String(line.dropFirst().dropLast())
            } else if currentSection == section {
                let parts = line.split(separator: "=", maxSplits: 2)
                if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == key {
                    if !found {
                        output.append(key + " = " + val)
                        found = true
                    }
                } else {
                    output.append(String(line))
                }
            } else {
                output.append(String(line))
            }
        }

        if !found {
            if currentSection != section {
                output.append("[" + section + "]")
            }
            output.append(key + " = " + val)
        }

        do {
            try output.joined(separator: "\n").write(to: URL(fileURLWithPath: file), atomically: true, encoding: .utf8)
        } catch {
            assertionFailure("Failed writing to URL: \(file), Error: " + error.localizedDescription)
        }
    }
}
