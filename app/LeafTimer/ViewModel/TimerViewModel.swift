import Foundation

class TimerViewModel: ObservableObject {

    // MARK: - Dependency Injection
    var timerManager: TimerManager

    // MARK: - Observed Parameter
    @Published var fullTimeSecond: Int
    @Published var currentTimeSecond: Int
    @Published var executeState: Bool

    init(timerManager: TimerManager) {
        self.timerManager = timerManager
        self.fullTimeSecond = 25*60
        self.currentTimeSecond = 25*60
        self.executeState = false
    }

    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            timerManager.start(target: self)

        case true:
            executeState = false
            timerManager.stop()
        }
    }

    @objc func updateTime() {
        currentTimeSecond -= 1
    }

    func getDisplayedTime() -> String {
        let minString
            = String(format: "%02d", Int(currentTimeSecond/60))
        let secondString
            = String(format: "%02d", Int(currentTimeSecond%60))

        return minString + ":" + secondString
    }

    func getButtonState() -> String {
        switch executeState {
        case true:
            return "STOP"

        case false:
            return "START"
        }
    }
}
