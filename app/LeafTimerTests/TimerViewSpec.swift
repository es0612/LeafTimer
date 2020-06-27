import Nimble
import Quick
import ViewInspector

import SwiftUI

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override func spec() {
        describe("test for TimerView") {

            var timerView: TimerView!
            beforeEach {
                timerView = TimerView()
            }

            it("displayed remaining time.") {
                let textString = try timerView.body
                    .inspect().vStack().text(0).string()

                expect(textString).to(equal("25:00"))
            }

            it("displayed start button.") {
                let startButton = try timerView.body
                    .inspect().vStack().button(1)

                expect(try startButton.text().string()).to(equal("START"))
            }

            xit("displayed stop button when button tapped") {
                let stopButton = try timerView.body
                    .inspect().vStack().button(1)

                try stopButton.tap()

                expect(try stopButton.text().string())
                    .toEventually(equal("STOP"))
            }
        }
    }
}
