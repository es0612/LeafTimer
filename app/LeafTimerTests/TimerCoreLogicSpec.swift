import Quick
import Nimble
import ViewInspector
import SwiftUI

@testable import LeafTimer

// Issue #56: 壁時計補正テスト用の可変クロック。
// テストから now() を注入し、advance() で実時間経過をシミュレートする。
final class FakeClock {
    private(set) var current: Date

    init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        current = start
    }

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

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

            // MARK: - Wall-clock correction (Issue #56)

            context("Wall-clock correction") {
                // clock 注入付きの VM を作る。既存 makeViewModel() は
                // tuple 形状を変えたくないので別 helper にする。
                func makeClockedViewModel(clock: FakeClock) -> TimerViewModel {
                    TimerViewModel(
                        timerManager: SpyTimerManager(),
                        audioManager: SpyAudioManager(),
                        userDefaultWrapper: MockUserDefaultWrapper(),
                        sessionStatsRepository: SpySessionStatsRepository(),
                        reviewRequester: MockReviewRequester(),
                        now: clock.now
                    )
                }

                it("通常の 1 秒 tick では 1 ずつ減る") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start: endDate = now + 300

                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 299

                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 298
                }

                it("tick 抜けで実時間が 5 秒進んでいたら 5 秒分補正される") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton()

                    // 5 秒経過したのに tick は 1 回しか来なかった (発火抜け)
                    clock.advance(by: 5)
                    vm.updateTime()

                    expect(vm.currentTimeSecond) == 295
                }

                it("残り時間を超えて経過したら 0 にクランプされ、次の tick で phase が切り替わる") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = false
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton()

                    // 残り 300 秒を大幅に超えて 400 秒経過 (長時間ブロック)
                    clock.advance(by: 400)
                    vm.updateTime()

                    // まず 0 にクランプ (この tick では phase は切り替わらない)
                    expect(vm.currentTimeSecond) == 0
                    expect(vm.breakState) == false

                    // 次の tick で従来どおり完了処理が走る
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.breakState) == true
                    expect(vm.currentTimeSecond) == 60
                }

                it("pause 中は時間が経過しても減らず、resume 後は残りから再開する") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start

                    clock.advance(by: 2)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 298

                    vm.onPressedTimerButton() // pause
                    clock.advance(by: 60)     // pause 中に 60 秒経過

                    vm.onPressedTimerButton() // resume: endDate = now + 298
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 297
                }

                it("phase 切替後は新しい endDate 基準でカウントダウンする") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullBreakTimeSecond = 60
                    vm.breakState = false
                    vm.currentTimeSecond = 2
                    vm.onPressedTimerButton() // start: endDate = now + 2 (これが stale になる)

                    clock.advance(by: 1)
                    vm.updateTime() // → 1
                    clock.advance(by: 1)
                    vm.updateTime() // → 0 (クランプ)
                    clock.advance(by: 1)
                    vm.updateTime() // 完了処理: switchBreakState + reset

                    expect(vm.breakState) == true
                    expect(vm.currentTimeSecond) == 60

                    // reset() が endDate を張り直していなければ、次の tick は
                    // 開始時の古い endDate (now + 2) との差分で 0 に潰れる
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 59
                }

                it("稼働中の手動リセットは full 値に戻して endDate を張り直す") {
                    let clock = FakeClock()
                    let vm = makeClockedViewModel(clock: clock)
                    vm.fullTimeSecond = 300
                    vm.breakState = false
                    vm.currentTimeSecond = 300
                    vm.onPressedTimerButton() // start

                    clock.advance(by: 10)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 290

                    vm.reset() // TimerView の reset ボタン相当

                    expect(vm.currentTimeSecond) == 300
                    clock.advance(by: 1)
                    vm.updateTime()
                    expect(vm.currentTimeSecond) == 299
                }
            }
        }
    }
}
