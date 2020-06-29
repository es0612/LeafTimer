import Foundation


protocol TimerManager: ObservableObject {
    func startTimer()
    func getDisplayedTime() -> String
    func getButtonState() -> String
}

class DefaultTimerManager: TimerManager {
    var timer: Timer?
    var fullTimeSecond: Int = 25*60
    var currentTimeSecond: Int = 25*60
    var executeState = false

    func startTimer() {
        currentTimeSecond = fullTimeSecond
        executeState = true

        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTime),
            userInfo: nil,
            repeats: true)
    }

    @objc func updateTime() {
        currentTimeSecond -= 1
    }

    func getDisplayedTime() -> String {
        let minString = String(Int(currentTimeSecond/60))
        let secondString = String(Int(currentTimeSecond % 60))
        return minString + ":" + secondString
    }

    func getButtonState() -> String {
        return "START"
    }

}
