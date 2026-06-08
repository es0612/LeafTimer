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
}
