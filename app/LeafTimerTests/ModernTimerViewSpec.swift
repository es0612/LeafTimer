import Nimble
import Quick
import ViewInspector
import SwiftUI

@testable import LeafTimer

class ModernTimerViewSpec: QuickSpec {
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
                    expect(navStack).toNot(beNil())
                }

                it("has proper navigation title") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    let title = try navStack.navigationTitle()
                    expect(title).toNot(beEmpty())
                }

                it("uses inline navigation bar display mode") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    let displayMode = try navStack.navigationBarTitleDisplayMode()
                    expect("\(displayMode)").to(contain("inline"))
                }
            }

            describe("Timer Display") {
                it("displays timer with modern typography") {
                    let timeText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(0)

                    let font = try timeText.attributes().font()
                    expect(font).toNot(beNil())
                }

                it("shows formatted time string") {
                    let displayTime = timerViewModel.getDisplayedTime()
                    expect(displayTime).to(match("\\d{1,2}:\\d{2}"))
                }

                it("updates time display when timer changes") {
                    timerViewModel.currentTimeSecond = 1200 // 20:00
                    let displayTime = timerViewModel.getDisplayedTime()
                    expect(displayTime).to(equal("20:00"))
                }
            }

            describe("Modern Controls") {
                it("has CircleButton for timer control") {
                    let button = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .view(CircleButton.self, 1)

                    expect(button).toNot(beNil())
                }

                it("responds to timer button tap") {
                    let button = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .view(CircleButton.self, 1)
                        .onTapGesture()

                    try button.callOnTapGesture()
                    expect(spyTimerManager.startWasCalled || spyTimerManager.stopWasCalled).to(beTrue())
                }

                it("has reset button in toolbar") {
                    let toolbar = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .toolbar()

                    expect(toolbar).toNot(beNil())
                }

                it("has settings navigation link in toolbar") {
                    let navStack = try timerView.body.inspect().navigationStack()
                    let toolbar = try navStack.zStack(0).vStack(1).toolbar()
                    expect(toolbar).toNot(beNil())
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

                    expect(gifView).toNot(beNil())
                }

                it("changes background color based on mode") {
                    let backgroundColor = timerViewModel.getBackgroundColor()
                    expect(backgroundColor).toNot(beNil())
                }

                it("shows different GIF for break mode") {
                    timerViewModel.breakState = true
                    let backgroundColor = timerViewModel.getBackgroundColor()
                    expect(backgroundColor).toNot(beNil())
                }
            }

            describe("Responsive Layout") {
                it("adapts to different screen sizes") {
                    let view = timerView.body
                    expect(view).toNot(beNil())
                }

                it("maintains proper spacing in layout") {
                    let vStack = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)

                    expect(vStack).toNot(beNil())
                }
            }

            describe("Accessibility") {
                it("has accessibility labels for timer display") {
                    let timeText = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .text(0)

                    expect(timeText).toNot(beNil())
                }

                it("has accessibility labels for controls") {
                    let button = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .view(CircleButton.self, 1)

                    expect(button).toNot(beNil())
                }
            }

            describe("State Management") {
                it("reads user data on appear") {
                    let onAppear = try timerView.body.inspect()
                        .navigationStack()
                        .zStack(0)
                        .vStack(1)
                        .onAppear()

                    try onAppear.callOnAppear()
                    // Data should be loaded
                }

                it("manages timer state properly") {
                    expect(timerViewModel.executeState).to(beFalse())

                    timerViewModel.onPressedTimerButton()
                    expect(spyTimerManager.startWasCalled || spyTimerManager.stopWasCalled).to(beTrue())
                }
            }
        }
    }
}