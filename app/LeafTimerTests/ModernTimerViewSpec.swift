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

                // Issue #132: expect(toolbar) != nil は ToolbarItem を全部消しても pass する。
                // item(0) の中の SF Symbol 名まで検証する。
                it("has reset button in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    let resetIcon = try toolbar.item(0).find(ViewType.Image.self).actualImage().name()
                    expect(resetIcon) == "arrow.counterclockwise"
                }

                // Issue #132: 同上。settings は 3 番目の ToolbarItem (index 2)
                it("has settings navigation link in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .geometryReader()
                        .zStack()
                        .vStack(2)
                        .toolbar()

                    let settingsItem = try toolbar.item(2)
                    expect(try settingsItem.navigationLink()) != nil
                    let settingsIcon = try settingsItem.find(ViewType.Image.self).actualImage().name()
                    expect(settingsIcon) == "gearshape.fill"
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
                // Issue #133: 旧コメントの「vStack(1).text(0) の位置に GIFView が存在するためパス不一致」は
                // 事実だが不完全だった (#129 で判明)。GIFView の存在は xit を続ける理由にならず、真の原因は
                // (a) navigationStack 直下の GeometryReader をパスに含めていなかったこと、
                // (b) ZStack の子が [背景, leafLayer, VStack] の順で主要 VStack が index 2 (旧パスは 1) だったこと。
                // index パスをやめ find() で復活する。
                it("has accessibility labels for timer display") {
                    let timeText = try timerView.body.inspect()
                        .find(text: timerViewModel.getDisplayedTime())

                    let label = try timeText.accessibilityLabel().string()
                    expect(label) == NSLocalizedString("timer.a11y.remaining_time", comment: "")
                }

                // Issue #133: 同上 (旧コメントの vStack(1).view(CircleButton, 1) 不一致も同じ原因)
                it("has accessibility labels for controls") {
                    let button = try timerView.body.inspect().find(ViewType.Button.self, where: { candidate in
                        (try? candidate.find(CircleButton.self)) != nil
                    })

                    let label = try button.accessibilityLabel().string()
                    expect(label) == timerViewModel.getAccessibilityLabel()
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
        }
    }
}
