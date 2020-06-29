import Nimble
import Quick
import ViewInspector

import SwiftUI

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override func spec() {
        describe("test for TimerView") {

            var timerView: TimerView!
            var stubTimerManager: StubTimerManager!

            beforeEach {
                stubTimerManager = StubTimerManager()
                timerView = TimerView(timerManager: DefaultTimerManager())
            }

            it("displayed remaining time.") {
                _ = try timerView.body.inspect()

                expect(stubTimerManager.getDisplayedTime_wasCalled).to(beTrue())
            }

            it("displayed start button.") {
                _ = try timerView.body.inspect()

                expect(stubTimerManager.getButtonState_wasCalled).to(beTrue())
            }

            it("displayed navigation bar") {
                let navBar = try timerView.body.inspect().navigationView()

                expect(navBar).notTo(beNil())
            }

            it("call timerManager methods when button tapped") {
                let stopButton = try timerView.body
                .inspect().navigationView().vStack(0).button(1)

                try stopButton.tap()

                expect(stubTimerManager.startTimer_wasCalled).to(beTrue())

            }
        }
    }
}
