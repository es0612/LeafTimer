import Nimble
import Quick
import ViewInspector

@testable import LeafTimer

class TimerViewSpec: QuickSpec {
    override func spec() {
        describe("test for TimerView") {
            it("displayed remaining time.") {
                let view = TimerView()
                
                let textString = try view.body.inspect().text().string()

                expect(textString).to(equal("25:00"))
            }
        }
    }
}
