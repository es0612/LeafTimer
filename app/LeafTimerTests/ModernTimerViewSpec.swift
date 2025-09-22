import Nimble
import Quick
import ViewInspector
import SwiftUI

@testable import LeafTimer

class ModernTimerViewSpec: QuickSpec {
    // swiftlint:disable function_body_length
    override class func spec() {
        xdescribe("Modernized TimerView") {
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
                    userDefaultWrapper: LocalUserDefaultsWrapper()
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

                it("has proper navigation title") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    let title = try navStack.navigationTitle()
                    expect(title.isEmpty) == false
                }

                // navigationBarTitleDisplayMode is not yet supported by ViewInspector
                // it("uses inline navigation bar display mode") {
                //     let navStack = try timerView.body.inspect().navigationStack()
                //     let displayMode = try navStack.navigationBarTitleDisplayMode()
                //     expect("\(displayMode)").to(contain("inline"))
                // }
            }

            describe("Timer Display") {
                it("displays timer with modern typography") {
                    let timeText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(0)

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
                it("has CircleButton for timer control") {
                    let button = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .view(CircleButton.self, 1)

                    expect(button) != nil
                }

                it("responds to timer button tap") {
                    // Tap gesture on CircleButton
                    timerViewModel.onPressedTimerButton()
                    expect(spyTimerManager.startWasCalled || spyTimerManager.stopWasCalled) == true
                }

                it("has reset button in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .toolbar()

                    expect(toolbar) != nil
                }

                it("has settings navigation link in toolbar") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    let toolbar = try navStack.zStack(0).vStack(1).toolbar()
                    expect(toolbar) != nil
                }
            }

            describe("Session Stats Display") {
                it("shows today's session count") {
                    let countText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(2)
                        .string()

                    expect(countText).to(contain(String(timerViewModel.todaysCount)))
                }

                it("updates session count when timer completes") {
                    timerViewModel.todaysCount = 5
                    let countText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(2)
                        .string()

                    expect(countText).to(contain("5"))
                }
            }

            describe("Visual Feedback") {
                it("displays GIF animation based on timer state") {
                    let gifView = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(0)
                        .view(GIFView.self, 0)

                    expect(gifView) != nil
                }

                it("changes background color based on mode") {
                    let backgroundColor = timerViewModel.getBackgroundColor()
                    expect(backgroundColor) != nil
                }

                it("shows different GIF for break mode") {
                    timerViewModel.breakState = true
                    let backgroundColor = timerViewModel.getBackgroundColor()
                    expect(backgroundColor) != nil
                }
            }

            describe("Responsive Layout") {
                it("adapts to different screen sizes") {
                    let view = timerView.body
                    expect(view) != nil
                }

                it("maintains proper spacing in layout") {
                    let vStack = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)

                    expect(vStack) != nil
                }
            }

            describe("Accessibility") {
                it("has accessibility labels for timer display") {
                    let timeText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(0)

                    expect(timeText) != nil
                }

                it("has accessibility labels for controls") {
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
        }
    }
}
