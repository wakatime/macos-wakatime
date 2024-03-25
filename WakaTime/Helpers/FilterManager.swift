import Cocoa

class FilterManager {
    static func filterBrowsedSites(app: NSRunningApplication, monitoredApp: MonitoredApp, activeWindow: AXUIElement) -> Bool {
        guard MonitoringManager.isAppBrowser(app) else { return true }

        if let address = activeWindow.address(for: monitoredApp) {
            let patterns = Self.parseList(PropertiesManager.currentFilterList)
            if patterns.isEmpty { return true }

            // Create scheme-prefixed address versions to allow regular expressions
            // that incorporate a scheme to match
            let httpAddress = "http://" + address
            let httpsAddress = "https://" + address

            switch PropertiesManager.filterType {
                case .denylist:
                    for pattern in patterns {
                        if address.matchesRegex(pattern) || httpAddress.matchesRegex(pattern) || httpsAddress.matchesRegex(pattern) {
                            // Address matches a pattern on the denylist. Filter the site out.
                            return false
                        }
                    }
                case .allowlist:
                    let addressMatchesAllowlist = patterns.contains { pattern in
                        httpAddress.matchesRegex(pattern) || httpsAddress.matchesRegex(pattern)
                    }
                    // If none of the patterns on the allowlist match the given address, filter the site out
                    if !addressMatchesAllowlist {
                        return false
                    }
            }
        }

        // The given address passed all filters and will be included
        return true
    }

    private static func parseList(_ listString: String) -> [String] {
        Self.sanitizeList(listString.components(separatedBy: "\n"))
    }

    private static func sanitizeList(_ urls: [String]) -> [String] {
        urls.map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
    }
}
