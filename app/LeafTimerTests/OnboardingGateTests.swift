import XCTest
@testable import LeafTimer

final class OnboardingGateTests: XCTestCase {
    private var mock: MockUserDefaultWrapper!
    private var viewModel: SettingViewModel!

    override func setUp() {
        super.setUp()
        mock = MockUserDefaultWrapper()
        viewModel = SettingViewModel(userDefaultWrapper: mock)
    }

    func testNewUserSeesOnboarding() {
        // フラグ未設定(=false) かつ totalPomodoroCount=0 の真の新規ユーザー
        XCTAssertTrue(viewModel.shouldShowOnboarding())
    }

    func testExistingUserDoesNotSeeOnboardingAndFlagIsSeeded() {
        // 既存ユーザー: ポモドーロ完了経験あり
        mock.setValue(for: UserDefaultItem.totalPomodoroCount.rawValue, value: 1)

        XCTAssertFalse(viewModel.shouldShowOnboarding())

        // 二度と出さないようフラグが true にシードされている
        let seeded: Bool = mock.loadData(key: UserDefaultItem.hasSeenOnboarding.rawValue)
        XCTAssertTrue(seeded)
    }

    func testAfterMarkingSeenOnboardingIsNotShown() {
        viewModel.markOnboardingSeen()
        XCTAssertFalse(viewModel.shouldShowOnboarding())
    }

    // MARK: - Issue #70: 初回起動キーの enum 化

    /// `hasLaunchedBefore` の永続化キーは既存ユーザーの設定を保つため
    /// 文字列 "hasLaunchedBefore" から変えてはならない。
    func testHasLaunchedBeforeRawValueIsUnchanged() {
        XCTAssertEqual(UserDefaultItem.hasLaunchedBefore.rawValue, "hasLaunchedBefore")
    }

    /// 初回起動時 (キー未設定) にサウンド既定値と初回フラグが
    /// すべて UserDefaultItem 経由のキーで書かれることを検証する。
    func testFirstLaunchWritesDefaultsUsingEnumKeys() {
        let wrapper = MockUserDefaultWrapper()
        wrapper.setValue(for: UserDefaultItem.hasLaunchedBefore.rawValue, value: 0)

        // notificationScheduler を Spy にするのは、既定の DefaultNotificationScheduler だと
        // init 内の cancelAll() が実 UNUserNotificationCenter に触れてしまうため。
        _ = TimerViewModel(
            timerManager: SpyTimerManager(),
            audioManager: SpyAudioManager(),
            userDefaultWrapper: wrapper,
            sessionStatsRepository: SpySessionStatsRepository(),
            notificationScheduler: SpyNotificationScheduler()
        )

        // UserDefaultsWrapper.loadData は戻り値型でオーバーロードされているため、
        // 型注釈付きの let で Int 版を明示的に選ぶ。
        let workingSound: Int = wrapper.loadData(key: UserDefaultItem.workingSound.rawValue)
        let breakSound: Int = wrapper.loadData(key: UserDefaultItem.breakSound.rawValue)
        let launchedFlag: Int = wrapper.loadData(key: UserDefaultItem.hasLaunchedBefore.rawValue)

        XCTAssertEqual(workingSound, 0)
        XCTAssertEqual(breakSound, 0)
        XCTAssertEqual(launchedFlag, 1)
    }
}
