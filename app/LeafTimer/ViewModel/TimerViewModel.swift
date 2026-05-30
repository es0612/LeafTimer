import Foundation
import UIKit

class TimerViewModel: ObservableObject {
    // MARK: - Dependency Injection

    var timerManager: TimerManager
    var audioManager: AudioManager
    var userDefaultWrapper: UserDefaultsWrapper
    private var sessionStatsRepository: SessionStatsRepository
    var reviewPolicy: ReviewRequestPolicy
    var reviewRequester: ReviewRequesting

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
    @Published
    var currentStreak: Int
    @Published
    var longestStreak: Int

    private var isFirstOpen = true

    // MARK: - Initialization

    init(
        timerManager: TimerManager,
        audioManager: AudioManager,
        userDefaultWrapper: UserDefaultsWrapper,
        sessionStatsRepository: SessionStatsRepository,
        reviewPolicy: ReviewRequestPolicy = ThresholdReviewRequestPolicy(),
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    ) {
        self.timerManager = timerManager
        self.audioManager = audioManager
        self.userDefaultWrapper = userDefaultWrapper
        self.sessionStatsRepository = sessionStatsRepository
        self.reviewPolicy = reviewPolicy
        self.reviewRequester = reviewRequester

        fullTimeSecond = 25 * 60
        currentTimeSecond = 25 * 60
        executeState = false

        fullBreakTimeSecond = 5 * 60
        breakState = false

        vibration = true

        todaysCount = 0
        currentStreak = 0
        longestStreak = 0

        loadCount()

        // Set default sound settings on first launch only
        if userDefaultWrapper.loadData(key: "hasLaunchedBefore") == 0 {
            userDefaultWrapper.saveData(key: UserDefaultItem.workingSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: UserDefaultItem.breakSound.rawValue, value: 0)
            userDefaultWrapper.saveData(key: "hasLaunchedBefore", value: 1)
        }
    }

    // MARK: - Methods

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
        let today = DateManager.getToday()
        let stats = sessionStatsRepository.recordSession(today: today)

        todaysCount = stats.dailyCount[today] ?? 0
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak

        // Legacy: requestReviewIfNeeded が `totalPomodoroCount` 単独 key に依存しているため
        // dual write を維持。Migration で初期同期済み、ここでも +1 を反映。
        let totalCount = userDefaultWrapper.loadData(
            key: UserDefaultItem.totalPomodoroCount.rawValue
        ) + 1
        userDefaultWrapper.saveData(
            key: UserDefaultItem.totalPomodoroCount.rawValue,
            value: totalCount
        )

        requestReviewIfNeeded(totalCount: totalCount)
    }

    private func requestReviewIfNeeded(totalCount: Int) {
        let lastRequested: Int = userDefaultWrapper.loadData(
            key: UserDefaultItem.lastReviewRequestedCount.rawValue
        )
        guard reviewPolicy.shouldRequest(
            totalCount: totalCount, lastRequestedCount: lastRequested
        ) else { return }

        reviewRequester.requestReview()
        userDefaultWrapper.saveData(
            key: UserDefaultItem.lastReviewRequestedCount.rawValue,
            value: totalCount
        )
    }

    func loadCount() {
        let stats = sessionStatsRepository.load()
        let today = DateManager.getToday()
        todaysCount = stats.dailyCount[today] ?? 0
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
    }

    // MARK: - Navigation

    // HistoryView の ViewModel は単一インスタンスを保持する。
    // タイマー稼働中は currentTimeSecond の @Published 更新で TimerView.body が毎秒
    // 再評価され、eager NavigationLink の destination が作り直される。その都度
    // HistoryViewModel を新規生成すると load() 済みの内容が空 VM に差し替わり、
    // 履歴が 0 表示に戻る (Issue #40)。lazy var で同一インスタンスを渡し続けることで
    // 再描画に耐え、再ナビゲーション時は HistoryView.onAppear の load() が最新化する。
    lazy var historyViewModel = HistoryViewModel(repository: sessionStatsRepository)
}
