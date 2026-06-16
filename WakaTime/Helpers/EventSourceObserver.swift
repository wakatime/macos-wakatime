import CoreGraphics

class EventSourceObserver {
    let pollIntervalInSeconds: CFTimeInterval
    var timer: Timer = Timer(timeInterval: 1, repeats: false) { _ in }

    init(pollIntervalInSeconds: CFTimeInterval) {
        self.pollIntervalInSeconds = pollIntervalInSeconds
        timer.invalidate()
    }

    func start(activityDetected: @escaping (_ hasInputActivity: Bool, _ secondsSinceLastMouseActivity: CFTimeInterval) -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollIntervalInSeconds, repeats: true) { [self] _ in
            let secondsSinceLastKeyPress = Self.checkForKeyPresses()
            let secondsSinceLastMouseActivity = Self.checkForMouseActivity()
            let hasInputActivity = secondsSinceLastKeyPress < pollIntervalInSeconds ||
                secondsSinceLastMouseActivity < pollIntervalInSeconds

            activityDetected(hasInputActivity, secondsSinceLastMouseActivity)
        }
    }

    func stop() {
        timer.invalidate()
    }

    static private func checkForKeyPresses() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    static private func checkForMouseActivity() -> CFTimeInterval {
        let mouseEventTypes: [CGEventType] = [
            CGEventType.leftMouseDown,
            CGEventType.rightMouseDown,
            CGEventType.otherMouseDown,
            CGEventType.mouseMoved,
            CGEventType.leftMouseDragged,
            CGEventType.rightMouseDragged,
            CGEventType.otherMouseDragged,
            CGEventType.scrollWheel,
        ]

        return mouseEventTypes.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? CFTimeInterval.greatestFiniteMagnitude
    }
}
