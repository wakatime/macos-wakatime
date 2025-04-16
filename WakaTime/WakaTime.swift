import AppKit
import Firebase
import Foundation

class WakaTime: HeartbeatEventHandler {
    // MARK: Watcher

    let watcher = Watcher()
    let delegate: StatusBarDelegate

    // MARK: Watcher State

    // Note: The lastEntity and lastTime member vars are read and written on a worker thread.
    // To ensure that they can be accessed concurrently from other threads without issues,
    // they are declared atomic here
    @Atomic var lastEntity = ""
    @Atomic var lastTime = 0
    @Atomic var lastCategory = Category.coding

    // MARK: Initialization and Setup

    init(_ delegate: StatusBarDelegate) {
        self.delegate = delegate

        Dependencies.installDependencies()
        if SettingsManager.shouldRegisterAsLoginItem() { SettingsManager.registerAsLoginItem() }
        if PropertiesManager.shouldRequestA11yPermission && !Accessibility.requestA11yPermission() {
            delegate.a11yStatusChanged(false)
        }

        configureFirebase()
        checkForApiKey()
        watcher.heartbeatEventHandler = self
        watcher.statusBarDelegate = delegate

        if !PropertiesManager.hasLaunchedBefore {
            for bundleId in MonitoredApp.defaultEnabledApps {
                MonitoringManager.enableByDefault(bundleId)
            }
            PropertiesManager.hasLaunchedBefore = true
        }
    }

    private func configureFirebase() {
        // Needed for uncaught exception reporting
        UserDefaults.standard.register(
          defaults: ["NSApplicationCrashOnExceptions": true]
        )
        FirebaseApp.configure()
    }

    private func checkForApiKey() {
        let apiKey = ConfigFile.getSetting(section: "settings", key: "api_key")
        if apiKey.isEmpty {
            openSettingsDeeplink()
        }
    }

    private func openSettingsDeeplink() {
        guard let url = DeepLink.settings.url else { return }

        NSWorkspace.shared.open(url)
    }

    private func openMonitoredAppsDeeplink() {
        guard let url = DeepLink.monitoredApps.url else { return }

        NSWorkspace.shared.open(url)
    }

    // MARK: Watcher Event Handling

    private func shouldSendHeartbeat(entity: String, time: Int, isWrite: Bool, category: Category) -> Bool {
        if isWrite { return true }
        if category != lastCategory { return true }
        if !entity.isEmpty && entity != lastEntity { return true }
        if lastTime + 120 < time { return true }

        return false
    }

    public func handleHeartbeatEvent(
        app: NSRunningApplication,
        entity: String,
        entityType: EntityType,
        project: String?,
        language: String?,
        category: Category?,
        isWrite: Bool) {
        let time = Int(NSDate().timeIntervalSince1970)
        let category = category ?? Category.coding
        guard shouldSendHeartbeat(entity: entity, time: time, isWrite: isWrite, category: category) else { return }

        // make sure we should be tracking this app to avoid race condition bugs
        // do this after shouldSendHeartbeat for better performance because handleEvent may
        // be called frequently
        guard MonitoringManager.isAppMonitored(app) else { return }

        guard
            let appName = AppInfo.getAppNameForHeartbeat(app),
            let appVersion = watcher.getAppVersion(app)
        else { return }

        let cli = NSString.path(
            withComponents: ConfigFile.resourcesFolder + ["wakatime-cli"]
        )
        let process = Process()
        process.launchPath = cli
        var args = [
            "--entity",
            entity,
            "--entity-type",
            entityType.rawValue,
            "--category",
            category.rawValue.replacingOccurrences(of: "_", with: " "),
            "--plugin",
            "\(appName)/\(appVersion) macos-wakatime/" + Bundle.main.version,
            "--alternate-branch",
            "<<LAST_BRANCH>>",
        ]
        if let project = project {
            args.append("--project")
            args.append(project)
        } else {
            args.append("--alternate-project")
            args.append("<<LAST_PROJECT>>")
        }
        if let language = language {
            args.append("--language")
            args.append(language)
        }
        if isWrite {
            args.append("--write")
        }

        Logging.default.log("Sending heartbeat with: \(args)")

        lastEntity = entity
        lastTime = time
        lastCategory = category

        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            // Use WakaTime's custom execute() method to run the process. This will call Process.launch()
            // with ObjC exception bridging on macOS 12 or earlier and Process.run() on macOS 13 or newer.
            try process.execute()
        } catch {
            Logging.default.log("Failed to run wakatime-cli: \(error)")
        }

        delegate.fetchToday()
    }
}

enum DeepLink: String {
    case settings
    case monitoredApps

    var url: URL? { URL(string: "wakatime://\(self)") }
}

enum EntityType: String {
    case file
    case app
    case domain
    case url
}

enum Category: String {
    case browsing
    case building
    case codereviewing = "code reviewing"
    case coding
    case communicating
    case debugging
    case designing
    case indexing
    case learning
    case manualtesting = "manual testing"
    case meeting
    case planning
    case researching
    case runningtests = "running tests"
    case translating
    case writingdocs = "writing docs"
    case writingtests = "writing tests"
}

protocol StatusBarDelegate: AnyObject {
    func a11yStatusChanged(_ hasPermission: Bool)
    func toastNotification(_ title: String)
    func fetchToday()
}

protocol HeartbeatEventHandler {
    func handleHeartbeatEvent(
        app: NSRunningApplication,
        entity: String,
        entityType: EntityType,
        project: String?,
        language: String?,
        category: Category?,
        isWrite: Bool)
}
