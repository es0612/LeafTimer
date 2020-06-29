import Foundation

@testable import LeafTimer

class StubTimerManager: TimerManager {
    private(set) var getButtonState_wasCalled = false
    func getButtonState() -> String {
        getButtonState_wasCalled = true
        return ""
    }


    private(set) var getDisplayedTime_wasCalled = false
    func getDisplayedTime() -> String {
        getDisplayedTime_wasCalled = true
        return ""
    }

    private(set) var startTimer_wasCalled = false
    func startTimer() {
        startTimer_wasCalled = true
    }
}
