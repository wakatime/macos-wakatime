import Cocoa

class FilterManager {
    static func filterBrowsedSites(app: NSRunningApplication, monitoredApp: MonitoredApp, activeWindow: AXUIElement) -> (Bool, String?) {
        // Non-browser apps are not filtered
        guard MonitoringManager.isAppBrowser(app) else { return (true, nil) }

        var project: String?

        if let address = activeWindow.address(for: monitoredApp) {
            let (urls, projects) = Self.parseList(PropertiesManager.currentFilterList)
            if urls.isEmpty { return (true, nil) }
            switch PropertiesManager.filterType {
                case .denylist:
                    for url in urls where address.contains(url) {
                        // URL appears on denylist. Filter the site out.
                        return (false, nil)
                    }
                case .allowlist:
                    var addressMatchesAllowlist = false
                    // swiftlint:disable for_where
                    for (index, url) in urls.enumerated() {
                        if address.contains(url) {
                            // URL appears on allowlist
                            addressMatchesAllowlist = true
                            project = projects[index]
                            break
                        }
                    }
                    // swiftlint:enable for_where
                    // If none of the URLs on the allowlist match the given address, filter the site out
                    if !addressMatchesAllowlist {
                        return (false, nil)
                    }
            }
        }

        // The given address passed all filters and will be included
        return (true, project)
    }

    private static func parseList(_ listString: String) -> ([String], [String?]) {
        let list = Self.sanitizeList(listString.components(separatedBy: "\n"))
        let urls = Self.removeUrlSchemes(list.map { $0.components(separatedBy: "@@")[0] })
        let projects: [String?] = list.map {
            let components = $0.components(separatedBy: "@@")
            if components.count > 1 { return components[1] }
            return nil
        }
        return (urls, projects)
    }

    private static func sanitizeList(_ urls: [String]) -> [String] {
        urls.map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
    }

    private static func removeUrlSchemes(_ urls: [String]) -> [String] {
        urls.map { urlString -> String in
            if let url = URL(string: urlString), let scheme = url.scheme {
                let schemeSpecificPart = urlString.dropFirst(scheme.count + 3) // +3 for "://"
                return String(schemeSpecificPart)
            }
            return urlString
        }
    }
}
