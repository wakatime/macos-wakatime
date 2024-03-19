import CoreGraphics

class EventSourceObserver {
    let pollIntervalInSeconds: CFTimeInterval
    var timer: Timer = Timer(timeInterval: 1, repeats: false) { _ in }

    init(pollIntervalInSeconds: CFTimeInterval) {
        self.pollIntervalInSeconds = pollIntervalInSeconds
        timer.invalidate()
    }

    func start(activityDetected: @escaping () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollIntervalInSeconds, repeats: true) { [self] _ in
            let secondsSinceLastKeyPress = Self.checkForKeyPresses()
            let secondsSinceLastMouseMoved = Self.checkForMouseActivity()
            if secondsSinceLastKeyPress < pollIntervalInSeconds || secondsSinceLastMouseMoved < pollIntervalInSeconds {
                activityDetected()
            }
        }
    }

    func stop() {
        timer.invalidate()
    }

    static private func checkForKeyPresses() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    static private func checkForMouseActivity() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }
}
