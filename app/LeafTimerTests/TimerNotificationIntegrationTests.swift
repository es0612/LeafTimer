import XCTest

@testable import LeafTimer

// Issue #54: TimerViewModel と NotificationScheduler / PhaseReconciler の結線検証。
final class TimerNotificationIntegrationTests: XCTestCase {
    // swiftlint:disable:next large_tuple
    private func makeViewModel(clock: FakeClock) -> (
        vm: TimerViewModel,
        spyNotification: SpyNotificationScheduler,
        spyStats: SpySessionStatsRepository,
        spyAudio: SpyAudioManager
    ) {
        let spyNotification = SpyNotificationScheduler()
        let spyStats = SpySessionStatsRepository()
        let spyAudio = SpyAudioManager()
        let vm = TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: spyAudio,
            userDefaultWrapper: MockUserDefaultWrapper(),
            sessionStatsRepository: spyStats,
            reviewRequester: MockReviewRequester(),
            notificationScheduler: spyNotification,
            now: { clock.now() }
        )
        return (vm, spyNotification, spyStats, spyAudio)
    }

    // 開始 → 許可リクエスト 1 回 + 6 件チェーン予約
    func testStartRequestsAuthorizationAndSchedulesChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()

        XCTAssertEqual(spy.requestAuthorizationCallCount, 1)
        XCTAssertEqual(spy.scheduledChains.count, 1)
        XCTAssertEqual(spy.scheduledChains[0].count, 6)
        XCTAssertEqual(spy.scheduledChains[0][0].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            spy.scheduledChains[0][0].fireDate,
            clock.now().addingTimeInterval(TimeInterval(vm.fullTimeSecond))
        )
    }

    // 停止 → cancelAll
    func testStopCancelsChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        vm.onPressedTimerButton()

        XCTAssertEqual(spy.cancelAllCallCount, 1)
    }

    // 跨ぎゼロの foreground 復帰 → 統計は増えない (冪等)
    func testForegroundWithoutCrossingDoesNotRecordSession() {
        let clock = FakeClock()
        let (vm, _, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        clock.advance(by: 60)
        vm.handleWillEnterForeground()

        XCTAssertEqual(spyStats.recordSessionCallCount, 0)
        XCTAssertEqual(vm.currentTimeSecond, vm.fullTimeSecond - 60)
    }

    // work 終了を跨いで復帰 → break へ進み、work 1 回分の統計を記録し、チェーン再予約
    func testForegroundAfterWorkEndAdvancesToBreakAndRecords() {
        let clock = FakeClock()
        let (vm, spy, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        clock.advance(by: TimeInterval(vm.fullTimeSecond + 10))
        vm.handleWillEnterForeground()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spyStats.recordSessionCallCount, 1)
        XCTAssertEqual(vm.currentTimeSecond, vm.fullBreakTimeSecond - 10)
        XCTAssertEqual(spy.scheduledChains.count, 2)
    }

    // 複数往復を跨いで復帰 → work 2 回分の統計
    func testForegroundAfterMultipleCyclesRecordsEachWork() {
        let clock = FakeClock()
        let (vm, _, spyStats, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        let crossed = vm.fullTimeSecond + vm.fullBreakTimeSecond + vm.fullTimeSecond + 30
        clock.advance(by: TimeInterval(crossed))
        vm.handleWillEnterForeground()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spyStats.recordSessionCallCount, 2)
    }

    // 停止中の foreground 復帰は no-op
    func testForegroundWhileStoppedIsNoOp() {
        let clock = FakeClock()
        let (vm, spy, spyStats, _) = makeViewModel(clock: clock)

        clock.advance(by: 3600)
        vm.handleWillEnterForeground()

        XCTAssertEqual(spyStats.recordSessionCallCount, 0)
        XCTAssertTrue(spy.scheduledChains.isEmpty)
    }

    // 稼働中に設定画面から戻る (readData) → チェーン再予約され、2 件目は新 duration を反映
    func testReadDataWhileRunningReschedulesChainWithNewDuration() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        XCTAssertEqual(spy.scheduledChains.count, 1)
        let originalWorkEndFireDate = spy.scheduledChains[0][0].fireDate

        // 休憩時間を index 9 (10分) に変更して設定画面から戻ったことを模倣
        vm.userDefaultWrapper.saveData(key: UserDefaultItem.breakTime.rawValue, value: 9)
        vm.readData()

        XCTAssertEqual(spy.scheduledChains.count, 2)
        XCTAssertEqual(vm.fullBreakTimeSecond, ItemValue.breakTimeList[9])

        let newChain = spy.scheduledChains[1]
        // 1 件目 (workEnd) は endDate 据え置きのまま変わらない
        XCTAssertEqual(newChain[0].fireDate, originalWorkEndFireDate)
        // 2 件目 (breakEnd) は新 breakDuration で引き直される
        XCTAssertEqual(
            newChain[1].fireDate,
            newChain[0].fireDate.addingTimeInterval(TimeInterval(ItemValue.breakTimeList[9]))
        )
    }

    // フォアグラウンド稼働中の自然なフェーズ切替 (updateTime が 0 到達) でも再予約
    func testNaturalPhaseSwitchReschedulesChain() {
        let clock = FakeClock()
        let (vm, spy, _, _) = makeViewModel(clock: clock)

        vm.onPressedTimerButton()
        vm.currentTimeSecond = 0
        vm.updateTime()

        XCTAssertEqual(vm.breakState, true)
        XCTAssertEqual(spy.scheduledChains.count, 2)
    }
}
