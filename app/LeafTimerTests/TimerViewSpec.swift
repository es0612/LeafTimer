import Nimble
import Quick
import ViewInspector

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override func spec() {
        describe("test for TimerView") {
            it("displayed remaining time.") {
                let timerView = TimerView()
                
                let textString = try timerView.body.inspect().vStack().text(0).string()

                expect(textString).to(equal("25:00"))
            }

            it("displayed stop button.") {
                let timerView = TimerView()

                let stopButton = try timerView.body.inspect().vStack().button(1)

                expect(stopButton).notTo(beNil())
                expect(try stopButton.text().string()).to(equal("STOP"))
            }
        }
    }
}
