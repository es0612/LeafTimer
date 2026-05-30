import Quick
import Nimble
import ViewInspector
import SwiftUI

@testable import LeafTimer

// TimerViewModel の中核ロジックを Spy/Mock を使って検証する spec。
// PR #14 (Issue #3) 時点で pbxproj 未登録のまま放置されていたものを、
// Issue #15 で現 API (fullTimeSecond / switchBreakState / finishCallCount)
// に書き直して復活させた。
class TimerCoreLogicSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("Timer Core Logic") {

            // MARK: - Helper

            // init() で hasLaunchedBefore 分岐により saveData が 3 回呼ばれるため、
            // 「saveData 呼び出し回数」を検査するテストは生成直後に reset する。
            // また reviewRequester は MockReviewRequester を明示的に渡し、
            // テスト中に StoreKit のシステム API が呼ばれないようにする。
            // 6 deps を一括返しにすることで各 it 内の setup boilerplate を排除している
            // swiftlint:disable:next large_tuple
            func makeViewModel() -> (
                vm: TimerViewModel,
                spyTimer: SpyTimerManager,
                spyAudio: SpyAudioManager,
                mockDefaults: MockUserDefaultWrapper,
                mockReviewer: MockReviewRequester,
                spyStats: SpySessionStatsRepository
            ) {
                let spyTimer = SpyTimerManager()
                let spyAudio = SpyAudioManager()
                let mockDefaults = MockUserDefaultWrapper()
                let mockReviewer = MockReviewRequester()
                let spyStats = SpySessionStatsRepository()
                let vm = TimerViewModel(
                    timerManager: spyTimer,
                    audioManager: spyAudio,
                    userDefaultWrapper: mockDefaults,
                    sessionStatsRepository: spyStats,
                    reviewRequester: mockReviewer
                )
                return (vm, spyTimer, spyAudio, mockDefaults, mockReviewer, spyStats)
            }

            // MARK: - TimerManager basic functionality

            context("TimerManager basic functionality") {
                it("stopped 状態から timer button を押すと start が呼ばれる") {
                    let (vm, spyTimer, _, _, _, _) = makeViewModel()

                    expect(vm.executeState) == false
                    expect(spyTimer.startWasCalled) == false

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == true
                    expect(spyTimer.startWasCalled) == true
                }

                it("running 状態から timer button を押すと stop が呼ばれる") {
                    let (vm, spyTimer, _, _, _, _) = makeViewModel()
                    vm.executeState = true

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == false
                    expect(spyTimer.stopWasCalled) == true
                }

                it("reset() は work mode で currentTimeSecond を fullTimeSecond に戻す") {
                    let (vm, _, _, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 100
                    vm.fullTimeSecond = 300
                    vm.breakState = false

                    vm.reset()

                    expect(vm.currentTimeSecond) == 300
                }

                it("reset() は break mode で currentTimeSecond を fullBreakTimeSecond に戻す") {
                    let (vm, _, _, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 10
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = true

                    vm.reset()

                    expect(vm.currentTimeSecond) == 60
                }
            }

            // MARK: - Countdown functionality

            context("Countdown functionality") {
                it("updateTime() は currentTimeSecond を 1 減らす") {
                    let (vm, _, _, _, _, _) = makeViewModel()
                    vm.currentTimeSecond = 300

                    vm.updateTime()

                    expect(vm.currentTimeSecond) == 299
                }

                it("currentTimeSecond が 0 のとき updateTime() で switchBreakState + reset が走る") {
                    let (vm, _, _, _, _, _) = makeViewModel()
                    vm.fullBreakTimeSecond = 60
                    vm.currentTimeSecond = 0
                    vm.breakState = false

                    vm.updateTime()

                    // work → break に切り替わる
                    expect(vm.breakState) == true
                    // reset() で currentTimeSecond は fullBreakTimeSecond に戻る
                    expect(vm.currentTimeSecond) == 60
                }
            }

            // MARK: - Work/Break mode switching

            context("Work/Break mode switching") {
                it("work から break への switch で audio.finish() と countWork() が走る") {
                    let (vm, _, spyAudio, mockDefaults, _, spyStats) = makeViewModel()
                    vm.breakState = false
                    mockDefaults.reset()

                    vm.switchBreakState()

                    expect(vm.breakState) == true
                    expect(spyAudio.finishCallCount) == 1
                    // 新 architecture では todaysCount は SessionStatsRepository が真実源。
                    // countWork() が呼ばれたことを spy の call count で verify する。
                    expect(spyStats.recordSessionCallCount) == 1
                    expect(spyStats.lastRecordedToday) == DateManager.getToday()
                }

                it("break から work への switch で audio.finishBreak() と audio.start() が走る") {
                    let (vm, _, spyAudio, _, _, _) = makeViewModel()
                    vm.breakState = true

                    vm.switchBreakState()

                    expect(vm.breakState) == false
                    expect(spyAudio.finishBreakCallCount) == 1
                    expect(spyAudio.startCallCount) == 1
                }
            }

            // MARK: - Data persistence

            context("Data persistence") {
                it("countWork() で todaysCount が永続化される") {
                    let (vm, _, _, mockDefaults, _, _) = makeViewModel()
                    // init で発生する saveData をクリアしてから本番アクションを評価
                    mockDefaults.reset()

                    vm.countWork()

                    expect(mockDefaults.saveDataIntCallCount) >= 1
                }
            }

            // MARK: - Audio integration

            context("Audio integration") {
                it("work → break に切り替わると audioManager.finish() が呼ばれる") {
                    let (vm, _, spyAudio, _, _, _) = makeViewModel()
                    vm.breakState = false

                    vm.switchBreakState()

                    expect(spyAudio.finishCallCount) == 1
                }
            }

            // MARK: - State management

            context("State management") {
                it("onPressedTimerButton() の前後で fullTimeSecond は変化しない") {
                    let (vm, _, _, _, _, _) = makeViewModel()
                    let initialFullTimeSecond = vm.fullTimeSecond
                    vm.executeState = false

                    vm.onPressedTimerButton()

                    expect(vm.executeState) == true
                    expect(vm.fullTimeSecond) == initialFullTimeSecond
                }
            }

            // MARK: - History navigation (Issue #40 regression)

            context("History navigation") {
                // Issue #40: タイマー稼働中は TimerView.body が毎秒再評価され、eager
                // NavigationLink の destination が作り直される。HistoryView の VM をその都度
                // 新規生成すると、load() 済みの内容が空 VM に差し替わり履歴が 0 表示に戻る。
                // 同一インスタンスを返すことで再描画に耐える。
                it("HistoryViewModel は同一インスタンスを返す") {
                    let (vm, _, _, _, _, _) = makeViewModel()

                    let first = vm.historyViewModel
                    let second = vm.historyViewModel

                    expect(first).to(beIdenticalTo(second))
                }
            }

            // MARK: - Memory management

            context("Memory management") {
                it("TimerViewModel は deallocate される") {
                    weak var weakVM: TimerViewModel?

                    autoreleasepool {
                        let spyTimer = SpyTimerManager()
                        let spyAudio = SpyAudioManager()
                        let mockDefaults = MockUserDefaultWrapper()
                        let mockReviewer = MockReviewRequester()
                        let localVM = TimerViewModel(
                            timerManager: spyTimer,
                            audioManager: spyAudio,
                            userDefaultWrapper: mockDefaults,
                            sessionStatsRepository: SpySessionStatsRepository(),
                            reviewRequester: mockReviewer
                        )
                        weakVM = localVM
                        localVM.onPressedTimerButton()
                    }

                    expect(weakVM).to(beNil())
                }
            }
        }
    }
}
