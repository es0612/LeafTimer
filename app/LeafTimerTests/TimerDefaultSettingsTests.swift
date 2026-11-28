import XCTest
@testable import LeafTimer

/// Issue #223: 新規インストールの初期値 (25 分・5 分・バイブ ON) と、
/// 止まっていて未開始のタイマーへの設定の反映を検証する。
final class TimerDefaultSettingsTests: XCTestCase {
    // MARK: - Helpers

    private func makeViewModel(wrapper: MockUserDefaultWrapper) -> TimerViewModel {
        // notificationScheduler を Spy にするのは、既定の DefaultNotificationScheduler だと
        // init 内の cancelAll() が実 UNUserNotificationCenter に触れてしまうため。
        TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: SpyAudioManager(),
            userDefaultWrapper: wrapper,
            sessionStatsRepository: SpySessionStatsRepository(),
            reviewRequester: MockReviewRequester(),
            notificationScheduler: SpyNotificationScheduler()
        )
    }

    /// TimerView.onAppear と同じ順で画面を開く
    private func open(_ vm: TimerViewModel) {
        vm.readData()
        vm.openScreen()
    }

    /// 既存ユーザー (作業 25 分・休憩 5 分を保存済み) の画面を開いた状態
    private func makeOpenedViewModel() -> (vm: TimerViewModel, wrapper: MockUserDefaultWrapper) {
        let wrapper = MockUserDefaultWrapper()
        wrapper.setValue(for: UserDefaultItem.hasLaunchedBefore.rawValue, value: 1)
        wrapper.setValue(for: UserDefaultItem.workingTime.rawValue, value: 4)
        wrapper.setValue(for: UserDefaultItem.breakTime.rawValue, value: 4)
        let vm = makeViewModel(wrapper: wrapper)
        open(vm)
        return (vm, wrapper)
    }

    // MARK: - 初回起動の既定値

    // 新規インストール: 何も保存されていない
    func testFirstLaunchStartsWithPomodoroDefaults() {
        let wrapper = MockUserDefaultWrapper()
        let vm = makeViewModel(wrapper: wrapper)
        open(vm)

        XCTAssertEqual(vm.fullTimeSecond, 25 * 60)
        XCTAssertEqual(vm.fullBreakTimeSecond, 5 * 60)
        XCTAssertEqual(vm.currentTimeSecond, 25 * 60)
        XCTAssertTrue(vm.vibration)

        // 設定画面も同じ値を出す
        let setting = SettingViewModel(userDefaultWrapper: wrapper, reviewRequester: MockReviewRequester())
        setting.readData()
        XCTAssertEqual(setting.workingTime, ItemValue.defaultWorkingTimeIndex)
        XCTAssertEqual(setting.breakTime, ItemValue.defaultBreakTimeIndex)
        XCTAssertTrue(setting.vibrationIsOn)
    }

    // v1.3 以前から直接上げた人: hasLaunchedBefore は未保存だが、選んだ値は保存済み
    func testFirstLaunchKeepsValuesSavedByOldVersion() {
        let wrapper = MockUserDefaultWrapper()
        wrapper.setValue(for: UserDefaultItem.workingTime.rawValue, value: 9)
        wrapper.setValue(for: UserDefaultItem.breakTime.rawValue, value: 0)
        wrapper.setValue(for: UserDefaultItem.vibration.rawValue, value: false)
        wrapper.setValue(for: UserDefaultItem.workingSound.rawValue, value: 2)
        let vm = makeViewModel(wrapper: wrapper)
        open(vm)

        XCTAssertEqual(vm.fullTimeSecond, 50 * 60)
        XCTAssertEqual(vm.fullBreakTimeSecond, 1 * 60)
        XCTAssertFalse(vm.vibration)
        XCTAssertEqual(wrapper.loadData(key: UserDefaultItem.workingSound.rawValue) as Int, 2)
    }

    // 設定を一度も触っていない既存ユーザー: 5 分・1 分・OFF のまま
    func testExistingUserWithoutSavedSettingsKeepsOldDefaults() {
        let wrapper = MockUserDefaultWrapper()
        wrapper.setValue(for: UserDefaultItem.hasLaunchedBefore.rawValue, value: 1)
        let vm = makeViewModel(wrapper: wrapper)
        open(vm)

        XCTAssertEqual(vm.fullTimeSecond, 5 * 60)
        XCTAssertEqual(vm.fullBreakTimeSecond, 1 * 60)
        XCTAssertFalse(vm.vibration)
    }

    // MARK: - 設定画面から戻ったときの反映

    func testStoppedUnstartedTimerTakesNewWorkingTime() {
        let (vm, wrapper) = makeOpenedViewModel()
        XCTAssertEqual(vm.currentTimeSecond, 25 * 60)

        wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
        vm.readData()

        XCTAssertEqual(vm.currentTimeSecond, 5 * 60)
    }

    func testStoppedUnstartedBreakTakesNewBreakTime() {
        let (vm, wrapper) = makeOpenedViewModel()
        vm.breakState = true
        vm.reset()
        XCTAssertEqual(vm.currentTimeSecond, 5 * 60)

        wrapper.saveData(key: UserDefaultItem.breakTime.rawValue, value: 9)
        vm.readData()

        XCTAssertEqual(vm.currentTimeSecond, 10 * 60)
    }

    func testPausedTimerKeepsRemainingTime() {
        let (vm, wrapper) = makeOpenedViewModel()
        vm.currentTimeSecond = 1000 // 途中で一時停止した状態 (executeState == false)

        wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
        vm.readData()

        XCTAssertEqual(vm.currentTimeSecond, 1000)
        XCTAssertEqual(vm.fullTimeSecond, 5 * 60)
    }

    func testRunningTimerKeepsRemainingTime() {
        let (vm, wrapper) = makeOpenedViewModel()
        vm.onPressedTimerButton() // 開始

        wrapper.saveData(key: UserDefaultItem.workingTime.rawValue, value: 0)
        vm.readData()

        XCTAssertEqual(vm.currentTimeSecond, 25 * 60)
    }
}
