import Nimble
import Quick
import ViewInspector

import SwiftUI

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override class func spec() {
        describe("test for TimerView") {

            var timerView: TimerView!
            var spyTimerManager: SpyTimerManager!

            beforeEach {
                spyTimerManager = SpyTimerManager()
                timerView = TimerView(
                    timerViewModel: TimerViewModel(
                        timerManager: spyTimerManager,
                        audioManager: SpyAudioManager(), 
                        userDefaultWrapper: LocalUserDefaultsWrapper()
                    ), 
                    settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
                )
            }

            xit("displayed remaining time.") {
                let textViewString = try timerView.body
                    .inspect().navigationStack().zStack(0).vStack(1).text(0).string()

                expect(textViewString).to(equal("25:00"))
            }

            xit("displayed start button.") {
//                let stopButton = try timerView.body
//                .inspect().navigationView().vStack(0).button(1)
//
//                expect(try stopButton.text().string()).to(equal("START"))
            }

            it("displayed navigation bar") {
                let navStack = try timerView.body.inspect().navigationStack()

                expect(navStack).notTo(beNil())
            }

            xit("displayed navigation bar button item") {
                let toolbarButton = try timerView.body.inspect().navigationStack()
                    .zStack(0).vStack(1).toolbar()
                
                expect(toolbarButton).notTo(beNil())
            }

            xit("call timerManager methods when button tapped") {
                let stopButton = try timerView.body
                .inspect().navigationStack().zStack(0).vStack(1).button(1)

                try stopButton.tap()

                let _ = try timerView.body.inspect()

                expect(spyTimerManager.start_wasCalled).toEventually(beTrue())

            }
        }
    }
}
