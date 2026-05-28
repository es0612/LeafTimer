import Quick
import Nimble

@testable import LeafTimer

class ReviewIntegrationSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("TimerViewModel review request integration") {
            it("does not request review when totalPomodoroCount stays under the first threshold") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 3
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    sessionStatsRepository: SpySessionStatsRepository(),
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (3 → 4)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 0
            }

            it("requests review when totalPomodoroCount crosses the first threshold (4 -> 5)") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 4
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 0
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    sessionStatsRepository: SpySessionStatsRepository(),
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (4 → 5)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 1
            }

            it("does not request review again on subsequent pomodoros within the same threshold range (5 -> 6)") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 5
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 5
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    sessionStatsRepository: SpySessionStatsRepository(),
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (5 → 6)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then
                expect(mockReviewRequester.requestReviewCallCount) == 0
            }

            it("updates lastReviewRequestedCount after requesting a review") {
                let spyTimerManager = SpyTimerManager()
                let spyAudioManager = SpyAudioManager()
                let mockUserDefaultWrapper = MockUserDefaultWrapper()
                let mockReviewRequester = MockReviewRequester()
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.totalPomodoroCount.rawValue, value: 4
                )
                mockUserDefaultWrapper.setValue(
                    for: UserDefaultItem.lastReviewRequestedCount.rawValue, value: 0
                )
                let timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: mockUserDefaultWrapper,
                    sessionStatsRepository: SpySessionStatsRepository(),
                    reviewPolicy: ThresholdReviewRequestPolicy(),
                    reviewRequester: mockReviewRequester
                )

                // When: ワーク完了 (4 → 5)
                timerViewModel.breakState = false
                timerViewModel.switchBreakState()

                // Then: lastReviewRequestedCount が 5 に更新されている
                let saved: Int = mockUserDefaultWrapper.loadData(
                    key: UserDefaultItem.lastReviewRequestedCount.rawValue
                )
                expect(saved) == 5
            }
        }
    }
}
