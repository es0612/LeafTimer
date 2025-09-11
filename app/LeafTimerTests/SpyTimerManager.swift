import Foundation

@testable import LeafTimer

class SpyTimerManager: TimerManager {
    private(set) var start_wasCalled = false
    func start(target: TimerViewModel) {
        start_wasCalled = true
    }

    private(set) var stop_wasCalled = false
    func stop() {
        stop_wasCalled = true
    }

    private(set) var reset_wasCalled = false
    func reset() {
        reset_wasCalled = true
    }
}
