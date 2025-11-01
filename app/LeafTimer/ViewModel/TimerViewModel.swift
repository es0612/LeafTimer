import Foundation
import UIKit

class TimerViewModel: ObservableObject {
    // MARK: - Dependency Injection

    var timerManager: TimerManager
    var audioManager: AudioManager
    var userDefaultWrapper: UserDefaultsWrapper

    // MARK: - Observed Parameter

    @Published
    var fullTimeSecond: Int
    @Published
    var fullBreakTimeSecond: Int

    @Published
    var currentTimeSecond: Int
    @Published
    var executeState: Bool

    @Published
    var breakState: Bool
    @Published
    var vibration: Bool
    @Published
    var todaysCount: Int

    private var isFirstOpen = true

    // MARK: - Initialization

    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper
    ) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper

        fullTimeSecond = 25 * 60
        currentTimeSecond = 25 * 60
        executeState = false

        fullBreakTimeSecond = 5 * 60
        breakState = false

        vibration = true

        todaysCount = 0

        loadCount()
    }

    // MARK: - methods

    func onPressedTimerButton() {
        switch executeState {
        case false:
            executeState = true
            timerManager.start(target: self)
            UIApplication.shared.isIdleTimerDisabled = true

            if !breakState {
                audioManager.start()
            }

        case true:
            executeState = false
            timerManager.stop()
            audioManager.stop()

            UIApplication.shared.isIdleTimerDisabled = false
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
            audioManager.finishBreak()
            audioManager.start()
        } else {
            breakState = true
            audioManager.finish()
            countWork()
        }
    }

    func read(item: String) -> Int {
        userDefaultWrapper.loadData(key: item)
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

    func countWork() {
        todaysCount += 1
        userDefaultWrapper.saveData(key: DateManager.getToday(), value: todaysCount)
    }

    func loadCount() {
        todaysCount = userDefaultWrapper.loadData(key: DateManager.getToday())
    }
}
