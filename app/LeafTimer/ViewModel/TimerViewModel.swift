import Foundation

class TimerViewModel: ObservableObject {
    
    // MARK: - Dependency Injection
    var timerManager: TimerManager
    var audioManager: AudioManager

    var userDefaultWrapper: UserDefaultsWrapper
    
    // MARK: - Observed Parameter
    @Published var fullTimeSecond: Int
    @Published var fullBreakTimeSecond: Int
    
    @Published var currentTimeSecond: Int
    @Published var executeState: Bool
    
    @Published var breakState: Bool
    @Published var vibration: Bool

    private var isFirstOpen = true
    
    
    // MARK: - Initialization
    init(timerManager: TimerManager,
         audioManager: AudioManager,
         userDefaultWrapper: UserDefaultsWrapper) {

        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper
        
        self.fullTimeSecond = 15*60
        self.currentTimeSecond = 15*10
        self.executeState = false
        
        self.fullBreakTimeSecond = 5*60
        self.breakState = false

        self.vibration = true
        
    }
    
    
    // MARK: - methods
    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            timerManager.start(target: self)

            if !breakState {
                audioManager.start()
            }

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

    func openScreen() {
        if isFirstOpen {
            if breakState {
                currentTimeSecond = fullBreakTimeSecond
            } else {
                currentTimeSecond = fullTimeSecond
            }

            isFirstOpen = false
        }
    }
    
    @objc func updateTime() {
        if currentTimeSecond == 0 {

            if vibration {
                audioManager.vibration()
            }

            switchBreakState()
            reset()

            return
        }
        
        currentTimeSecond -= 1
    }

    func switchBreakState() {
        if breakState {
            breakState = false
            audioManager.start()
        } else {
            breakState = true
            audioManager.finish()
        }
    }

    func read(item: String) -> Int {
        return userDefaultWrapper.loadData(key: item)
    }

    func readData() {
        fullTimeSecond = ItemValue
            .workingTimeList[read(item: UserDefaultItem.workingTime.rawValue)]
        fullBreakTimeSecond = ItemValue
            .breakTimeList[read(item: UserDefaultItem.breakTime.rawValue)]

        vibration = userDefaultWrapper.loadData(key: UserDefaultItem.vibration.rawValue)

        let selectedSound = read(item: UserDefaultItem.workingSound.rawValue)
        audioManager.setUp(workingSound: ItemValue.soundListFileName[selectedSound])

        if executeState {
            if !breakState {
                audioManager.start()
            }
        }
    }
}

