import AppKit

extension AXObserver {
    static func create(appID: pid_t, callback: AXObserverCallback) throws -> AXObserver {
        var observer: AXObserver?
        let error = AXObserverCreate(appID, callback, &observer)

        guard error == .success else { throw AXObserverError.createFailed(error) }
        guard let observer else { throw AXObserverError.createFailed(error) }

        return observer
    }

    func add(notification: String, element: AXUIElement, refcon: UnsafeMutableRawPointer?) throws {
        let error = AXObserverAddNotification(self, element, notification as CFString, refcon)
        guard error == .success else {
            Logging.default.log("Add notification \(notification) failed: \(error.rawValue)")
            throw AXObserverError.addNotificationFailed(error)
        }

        // Logging.default.log("Added notification \(notification) to observer \(self)")
    }

    func remove(notification: String, element: AXUIElement) throws {
        let error = AXObserverRemoveNotification(self, element, notification as CFString)
        guard error == .success else {
            Logging.default.log("Remove notification \(notification) failed: \(error.rawValue)")
            throw AXObserverError.removeNotificationFailed(error)
        }

        // Logging.default.log("Removed notification \(notification) from observer \(self)")
    }

    func addToRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopAddSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        // Logging.default.log("Added observer \(self) to run loop")
    }

    func removeFromRunLoop(mode: CFRunLoopMode = .defaultMode) {
        CFRunLoopRemoveSource(RunLoop.current.getCFRunLoop(), AXObserverGetRunLoopSource(self), mode)
        // Logging.default.log("Removed observer \(self) from run loop")
    }
}

private enum AXObserverError: Error {
    case createFailed(AXError)
    case addNotificationFailed(AXError)
    case removeNotificationFailed(AXError)
}
