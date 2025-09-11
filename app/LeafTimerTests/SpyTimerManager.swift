import Foundation

@testable import LeafTimer

class SpyTimerManager: TimerManager {
    private(set) var startWasCalled = false
    func start(target: TimerViewModel) {
        startWasCalled = true
    }

    private(set) var stopWasCalled = false
    func stop() {
        stopWasCalled = true
    }

    private(set) var resetWasCalled = false
    func reset() {
        resetWasCalled = true
    }
}
