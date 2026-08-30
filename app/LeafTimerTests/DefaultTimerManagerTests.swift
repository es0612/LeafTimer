// app/LeafTimerTests/DefaultTimerManagerTests.swift
import XCTest
@testable import LeafTimer

/// Issue #77: タイマー発火の心臓部 DefaultTimerManager の実体テスト。
/// Timer.scheduledTimer は現在の RunLoop に載るため、XCTest の wait(for:) で RunLoop を回して
/// 実際に 1 秒刻みで target.updateTime() が呼ばれることを検証する。
final class DefaultTimerManagerTests: XCTestCase {

    private var timerManager: DefaultTimerManager!
    private var viewModel: TimerViewModel!

    override func setUp() {
        super.setUp()
        timerManager = DefaultTimerManager()
        viewModel = TimerViewModel(
            timerManager: timerManager,
            audioManager: SpyAudioManager(),
            userDefaultWrapper: MockUserDefaultWrapper(),
            sessionStatsRepository: SpySessionStatsRepository()
        )
        // endDate を設定しないので updateTime() は currentTimeSecond -= 1 の経路を通る
        // (TimerViewModel.swift:154-176)。0 に到達すると reset/通知経路に入るので十分大きい値にする。
        viewModel.currentTimeSecond = 100
    }

    override func tearDown() {
        timerManager.stop()
        timerManager = nil
        viewModel = nil
        super.tearDown()
    }

    func testStartFiresUpdateTimeEverySecond() {
        timerManager.start(target: viewModel)

        // 2 回発火 (≒ 2 秒) で 98 以下になる。tolerance 0.1 を見込んで 3.5 秒待つ。
        let decremented = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.viewModel.currentTimeSecond <= 98 },
            object: nil
        )
        wait(for: [decremented], timeout: 3.5)
        XCTAssertLessThanOrEqual(viewModel.currentTimeSecond, 98)
    }

    func testStopHaltsFiring() {
        timerManager.start(target: viewModel)
        let firedOnce = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.viewModel.currentTimeSecond <= 99 },
            object: nil
        )
        wait(for: [firedOnce], timeout: 2.5)

        timerManager.stop()

        // XCTNSPredicateExpectation は timer fire がまだ main queue に積まれている途中で
        // 返ってくることがあるため、afterStop を確定させる前に一度 RunLoop を短時間ドレインする。
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        let afterStop = viewModel.currentTimeSecond

        // stop 後に RunLoop を 2.5 秒回しても値が動かない
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertEqual(viewModel.currentTimeSecond, afterStop)
    }

    func testStartTwiceDoesNotDoubleFire() {
        timerManager.start(target: viewModel)
        timerManager.start(target: viewModel) // 既存 timer を stop してから張り直す契約

        // 2.5 秒で発火は高々 2 回 (二重に張られていれば 4 回 = 96 まで落ちる)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.5))
        XCTAssertGreaterThanOrEqual(viewModel.currentTimeSecond, 97)
        XCTAssertLessThanOrEqual(viewModel.currentTimeSecond, 99)
    }
}
