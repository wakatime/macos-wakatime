import Foundation

extension Bundle {
    var displayName: String {
        readFromInfoDict(key: "CFBundleDisplayName") ?? "unknown"
    }

    var version: String {
        readFromInfoDict(key: "CFBundleShortVersionString") ?? "unknown"
    }

    var build: String {
        readFromInfoDict(key: "CFBundleVersion") ?? "unknown"
    }

    private func readFromInfoDict(key: String) -> String? {
        infoDictionary?[key] as? String
    }
}
