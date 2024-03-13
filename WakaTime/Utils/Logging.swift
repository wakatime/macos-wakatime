import Foundation
import os.log

class Logging {
    static let `default` = Logging()
    private var filePath: String?

    private init() {}

    // Configures logging to also write to a file at the given path.
    func configure(filePath: String) {
        self.filePath = filePath
    }

    func activateLoggingToFile() {
        let userHome = FileManager.default.homeDirectoryForCurrentUser.pathComponents
        let logFilePath = NSString.path(withComponents: userHome + [".wakatime", "macos-wakatime.log"])
        configure(filePath: logFilePath)
    }

    func deactivateLoggingToFile() {
        filePath = nil
    }

    func log(_ message: String, type: OSLogType = .default) {
        os_log("%{public}@", log: .default, type: type, message)

        if let filePath {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let timestamp = dateFormatter.string(from: Date())
            let logMessage = "\(timestamp): \(message)\n"

            // Attempt to append the log message to the log file
            if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                fileHandle.seekToEndOfFile()
                if let data = logMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                // If the file does not exist, create it
                try? logMessage.write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        }
    }
}
