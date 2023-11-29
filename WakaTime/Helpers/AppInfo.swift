import Foundation
import Cocoa

class AppInfo {
    static func getAppName(bundleId: String) -> String? {
        let workspace = NSWorkspace.shared

        guard
            let appUrl = workspace.urlForApplication(withBundleIdentifier: bundleId),
            let appBundle = Bundle(url: appUrl)
        else { return nil }

        return appBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? appBundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }

    static func getAppName(_ app: NSRunningApplication) -> String? {
        guard let bundleId = app.bundleIdentifier else { return nil }

        return getAppName(bundleId: bundleId)
    }

    static func getAppNameForHeartbeat(_ app: NSRunningApplication) -> String? {
        guard let appName = getAppName(app) else { return nil }
        return appName.filter { !$0.isWhitespace }
    }

    static func getIcon(file path: String) -> NSImage? {
        guard
            FileManager.default.fileExists(atPath: path)
        else { return nil }

        return NSWorkspace.shared.icon(forFile: path)
    }

    static func getIcon(bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }

        return getIcon(file: url.absoluteURL.path)
    }
}
