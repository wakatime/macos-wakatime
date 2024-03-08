//
//  EventSourceObserver.swift
//  WakaTime
//
//  Created by Tobias Lensing on 04.03.24.
//

import Foundation
import CoreGraphics

class EventSourceObserver {
    let pollIntervalInSeconds: CFTimeInterval

    init(pollIntervalInSeconds: CFTimeInterval, activityDetected: @escaping () -> Void) {
        self.pollIntervalInSeconds = pollIntervalInSeconds
        Timer.scheduledTimer(withTimeInterval: pollIntervalInSeconds, repeats: true) { _ in
            let secondsSinceLastKeyPress = Self.checkForKeyPresses()
            let secondsSinceLastMouseMoved = Self.checkForMouseActivity()
            if secondsSinceLastKeyPress < pollIntervalInSeconds || secondsSinceLastMouseMoved < pollIntervalInSeconds {
                activityDetected()
            }
        }
    }

    static private func checkForKeyPresses() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    static private func checkForMouseActivity() -> CFTimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }
}
