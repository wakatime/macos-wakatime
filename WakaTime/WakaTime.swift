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

    // MARK: Constants

    enum Constants {
        static let settingsDeepLink: String = "wakatime://settings"
    }

    // MARK: Initialization and Setup

    init(_ delegate: StatusBarDelegate) {
        self.delegate = delegate

        Dependencies.installDependencies()
        if SettingsManager.shouldRegisterAsLoginItem() { SettingsManager.registerAsLoginItem() }
        if !Accessibility.requestA11yPermission() {
            delegate.a11yStatusChanged(false)
        }

        configureFirebase()
        checkForApiKey()
        watcher.heartbeatEventHandler = self
        watcher.statusBarDelegate = delegate

        // In local dev builds, print bundle-ids of all running apps to Xcode console
        if Bundle.main.version == "local-build" {
            print("********* Start Running Applications *********")
            for runningApp in NSWorkspace.shared.runningApplications where runningApp.activationPolicy == .regular {
                if let name = runningApp.localizedName, let id = runningApp.bundleIdentifier {
                    print("\(name): \(id)")
                }
            }
            print("********* End Running Applications *********")
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
        if let url = URL(string: Constants.settingsDeepLink) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Watcher Event Handling

    private func shouldSendHeartbeat(entity: String, time: Int, isWrite: Bool, category: Category) -> Bool {
        guard
            !isWrite,
            category == lastCategory,
            entity == lastEntity,
            lastTime + 120 > time
        else { return true }

        return false
    }

    public func handleHeartbeatEvent(
        app: NSRunningApplication,
        entity: String,
        entityType: EntityType,
        language: String?,
        category: Category?,
        isWrite: Bool) {
        let time = Int(NSDate().timeIntervalSince1970)
        let category = category ?? Category.coding
        guard shouldSendHeartbeat(entity: entity, time: time, isWrite: isWrite, category: category) else { return }

        lastEntity = entity
        lastTime = time
        lastCategory = category

        // make sure we should be tracking this app to avoid race condition bugs
        // do this after shouldSendHeartbeat for better performance because handleEvent may
        // be called frequently
        guard MonitoringManager.isAppMonitored(app) else { return }

        guard
            let appName = AppInfo.getAppName(app),
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
            category.rawValue,
            "--plugin",
            "\(appName)/\(appVersion) macos-wakatime/" + Bundle.main.version,
        ]
        if isWrite {
            args.append("--write")
        }
        if let language = language {
            args.append("--language")
            args.append(language)
        }

        NSLog("Sending heartbeat with: \(args)")

        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            // Use WakaTime's custom execute() method to run the process. This will call Process.launch()
            // with ObjC exception bridging on macOS 12 or earlier and Process.run() on macOS 13 or newer.
            try process.execute()
        } catch {
            NSLog("Failed to run wakatime-cli: \(error)")
        }
    }
}

enum EntityType: String {
    case file
    case app
}

enum Category: String {
    case browsing
    case building
    case coding
    case communicating
    case debugging
    case designing
    case meeting
}

protocol StatusBarDelegate: AnyObject {
    func a11yStatusChanged(_ hasPermission: Bool)
}

protocol HeartbeatEventHandler {
    func handleHeartbeatEvent(
        app: NSRunningApplication,
        entity: String,
        entityType: EntityType,
        language: String?,
        category: Category?,
        isWrite: Bool)
}
