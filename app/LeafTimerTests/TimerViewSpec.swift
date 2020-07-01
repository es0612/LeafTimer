import Nimble
import Quick
import ViewInspector

import SwiftUI

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override func spec() {
        describe("test for TimerView") {

            var timerView: TimerView!
            var spyTimerManager: SpyTimerManager!

            beforeEach {
                spyTimerManager = SpyTimerManager()
                timerView = TimerView(
                    timverViewModel: TimerViewModel(
                        timerManager: SpyTimerManager()
                ))
            }

            it("displayed remaining time.") {
                let textViewString = try timerView.body
                    .inspect().navigationView().vStack(0).text(0).string()

                expect(textViewString).to(equal("25:00"))
            }

            it("displayed start button.") {
                let stopButton = try timerView.body
                .inspect().navigationView().vStack(0).button(1)

                expect(try stopButton.text().string()).to(equal("START"))
            }

            it("displayed navigation bar") {
                let navBar = try timerView.body.inspect().navigationView()

                expect(navBar).notTo(beNil())
            }

            xit("call timerManager methods when button tapped") {
                let stopButton = try timerView.body
                .inspect().navigationView().vStack(0).button(1)

                try stopButton.tap()

                let _ = try timerView.body.inspect()

                expect(spyTimerManager.start_wasCalled).toEventually(beTrue())

            }
        }
    }
}
