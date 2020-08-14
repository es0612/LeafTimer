import Foundation

class TimerViewModel: ObservableObject {
    
    // MARK: - Dependency Injection
    var timerManager: TimerManager
    var audioManager: AudioManager
    
    // MARK: - Observed Parameter
    @Published var fullTimeSecond: Int
    @Published var fullBreakTimeSecond: Int
    
    @Published var currentTimeSecond: Int
    @Published var executeState: Bool
    
    @Published var breakState: Bool
    
    
    // MARK: - Initialization
    init(timerManager: TimerManager, audioManager: AudioManager) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        
        self.fullTimeSecond = 1*60
        self.currentTimeSecond = 1*10
        self.executeState = false
        
        self.fullBreakTimeSecond = 30
        self.breakState = false
        
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
        if breakState {
            currentTimeSecond = fullBreakTimeSecond
        } else {
            currentTimeSecond = fullTimeSecond
        }
    }
    
    @objc func updateTime() {
        if currentTimeSecond == 0 {
            audioManager.finish()
            audioManager.vibration()

            switchBreakState()
            reset()

            return
        }
        currentTimeSecond -= 1
    }

    func switchBreakState() {
        if breakState {
            breakState = false
        } else {
            breakState = true
        }
    }
}

