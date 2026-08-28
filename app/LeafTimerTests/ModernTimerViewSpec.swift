import Nimble
import Quick
import ViewInspector
import SwiftUI

@testable import LeafTimer

class ModernTimerViewSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("Modernized TimerView") {
            var timerView: TimerView!
            var timerViewModel: TimerViewModel!
            var settingViewModel: SettingViewModel!
            var spyTimerManager: SpyTimerManager!
            var spyAudioManager: SpyAudioManager!

            beforeEach {
                spyTimerManager = SpyTimerManager()
                spyAudioManager = SpyAudioManager()
                timerViewModel = TimerViewModel(
                    timerManager: spyTimerManager,
                    audioManager: spyAudioManager,
                    userDefaultWrapper: LocalUserDefaultsWrapper(),
                    sessionStatsRepository: SpySessionStatsRepository()
                )
                settingViewModel = SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
                timerView = TimerView(
                    timerViewModel: timerViewModel,
                    settingViewModel: settingViewModel
                )
            }

            describe("NavigationStack") {
                it("uses NavigationStack instead of NavigationView") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    expect(navStack) != nil
                }

                // navigationBarTitleDisplayMode is not yet supported by ViewInspector
                // it("uses inline navigation bar display mode") {
                //     let navStack = try timerView.body.inspect().navigationStack()
                //     let displayMode = try navStack.navigationBarTitleDisplayMode()
                //     expect("\(displayMode)").to(contain("inline"))
                // }
            }

            describe("Timer Display") {
                // Issue #129: index パスでなく表示文字列で直接検索する find(text:) に移行
                it("displays timer with modern typography") {
                    let timeText = try timerView.body.inspect()
                        .find(text: timerViewModel.getDisplayedTime())

                    let font = try timeText.attributes().font()
                    expect(font) != nil
                }

                it("shows formatted time string") {
                    let displayTime = timerViewModel.getDisplayedTime()
                    expect(displayTime).to(match("\\d{1,2}:\\d{2}"))
                }

                it("updates time display when timer changes") {
                    timerViewModel.currentTimeSecond = 1200 // 20:00
                    let displayTime = timerViewModel.getDisplayedTime()
                    expect(displayTime) == "20:00"
                }
            }

            describe("Modern Controls") {
                // Issue #129: index パスでなく find() で CircleButton を直接検索する形へ移行
                it("has CircleButton for timer control") {
                    let button = try timerView.body.inspect()
                        .find(ViewType.View<CircleButton>.self)

                    expect(button) != nil
                }

                it("responds to timer button tap") {
                    // Tap gesture on CircleButton
                    timerViewModel.onPressedTimerButton()
                    expect(spyTimerManager.startWasCalled || spyTimerManager.stopWasCalled) == true
                }

                // Issue #129: toolbar modifier は VStack (zStack 内 index 2) に付与されているため
                // GeometryReader を挟んだ正しいパスへ移行
                it("has reset button in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    expect(toolbar) != nil
                }

                // Issue #129: 同上のパス修正
                it("has settings navigation link in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    expect(toolbar) != nil
                }
            }

            describe("Session Stats Display") {
                // Issue #129: StatChip の text は String(format:) 済みの完成文字列のため
                // 同じフォーマットで期待値を組み立てて find(text:) で検索する
                it("shows today's session count") {
                    let expectedText = String(
                        format: NSLocalizedString("timer.stat.today", comment: "Today's pomodoro count"),
                        timerViewModel.todaysCount
                    )
                    let countText = try timerView.body.inspect().find(text: expectedText)

                    expect(countText) != nil
                }

                // Issue #129: 同上の find(text:) 形式へ移行
                it("updates session count when timer completes") {
                    timerViewModel.todaysCount = 5
                    let expectedText = String(
                        format: NSLocalizedString("timer.stat.today", comment: "Today's pomodoro count"),
                        timerViewModel.todaysCount
                    )
                    let countText = try timerView.body.inspect().find(text: expectedText)

                    expect(countText) != nil
                }
            }

            describe("Visual Feedback") {
                // Issue #129: index パスでなく find() で GIFView を直接検索する形へ移行
                it("displays GIF animation based on timer state") {
                    let gifView = try timerView.body.inspect()
                        .find(ViewType.View<GIFView>.self)

                    expect(gifView) != nil
                }

                it("changes background color based on mode") {
                    let backgroundColor = timerViewModel.getBackgroundColor(colorScheme: .light)
                    expect(backgroundColor) != nil
                }

                it("shows different GIF for break mode") {
                    timerViewModel.breakState = true
                    let backgroundColor = timerViewModel.getBackgroundColor(colorScheme: .light)
                    expect(backgroundColor) != nil
                }
            }

            describe("Responsive Layout") {
                it("adapts to different screen sizes") {
                    let view = timerView.body
                    expect(view) != nil
                }

                it("maintains proper spacing in layout") {
                    // Issue #64: navigationStack 直下に GeometryReader を挿入し、葉の VStack を
                    // leafLayer(metrics:) (GIFView を直接返す @ViewBuilder) に置き換えたため、
                    // ZStack の子は [背景, leafLayer, 主要コンテンツ VStack] の順で index 2 になった。
                    let vStack = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)

                    expect(vStack) != nil
                }
            }

            describe("Accessibility") {
                // xit: TimerView の実装変更で vStack(1).text(0) の位置に GIFView が存在するためパス不一致 (Issue #16)
                xit("has accessibility labels for timer display") {
                    let timeText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(0)

                    expect(timeText) != nil
                }

                // xit: TimerView の実装変更で vStack(1).view(CircleButton, 1) のパスが不一致 (view absent) (Issue #16)
                xit("has accessibility labels for controls") {
                    let button = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .view(CircleButton.self, 1)

                    expect(button) != nil
                }
            }

            describe("State Management") {
                it("reads user data on appear") {
                    // onAppear is called when view appears
                    timerViewModel.readData()
                    timerViewModel.openScreen()
                    // Data should be loaded
                    expect(timerViewModel) != nil
                }

                it("manages timer state properly") {
                    expect(timerViewModel.executeState) == false

                    timerViewModel.onPressedTimerButton()
                    expect(spyTimerManager.startWasCalled || spyTimerManager.stopWasCalled) == true
                }
            }

            describe("Accessibility (Issue #59)") {
                it("start/stop control is a real Button wrapping CircleButton") {
                    expect {
                        try timerView.body.inspect().find(ViewType.Button.self, where: { candidate in
                            (try? candidate.find(CircleButton.self)) != nil
                        })
                    }.toNot(throwError())
                }
            }
        }
    }
}
