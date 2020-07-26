import Foundation

class TimerViewModel: ObservableObject {

    // MARK: - Dependency Injection
    var timerManager: TimerManager
    var audioManager: AudioManager

    // MARK: - Observed Parameter
    @Published var fullTimeSecond: Int
    @Published var currentTimeSecond: Int
    @Published var executeState: Bool


    // MARK: - Initialization
    init(timerManager: TimerManager, audioManager: AudioManager) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        
        self.fullTimeSecond = 1*60
        self.currentTimeSecond = 1*60
        self.executeState = false

        audioManager.setUp()
    }

    // MARK: - methods
    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            timerManager.start(target: self)

            audioManager.start()


        case true:
            executeState = false
            timerManager.stop()

            audioManager.stop()
        }
    }

    func reset() {
        switch executeState {
        case false:
            currentTimeSecond = fullTimeSecond

        case true:
            print("can not reset. please stop")
        }
    }

    @objc func updateTime() {
        if currentTimeSecond == 0 {
            timerManager.stop()
            audioManager.finish()

            audioManager.vibration()

            return
        }

        currentTimeSecond -= 1
    }
}



extension TimerViewModel {
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
