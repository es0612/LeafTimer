import Quick
import Nimble

@testable import LeafTimer

class ReviewRequestPolicySpec: QuickSpec {
    override class func spec() {
        describe("ThresholdReviewRequestPolicy") {
            let policy = ThresholdReviewRequestPolicy()

            context("when total has not crossed any threshold") {
                it("returns false at total=4, last=0") {
                    expect(policy.shouldRequest(totalCount: 4, lastRequestedCount: 0)) == false
                }
            }

            context("when total just crosses the first threshold (5)") {
                it("returns true at total=5, last=0") {
                    expect(policy.shouldRequest(totalCount: 5, lastRequestedCount: 0)) == true
                }
            }

            context("when total is at the threshold but already requested") {
                it("returns false at total=5, last=5") {
                    expect(policy.shouldRequest(totalCount: 5, lastRequestedCount: 5)) == false
                }
            }

            context("when total crosses the second threshold (20)") {
                it("returns true at total=20, last=5") {
                    expect(policy.shouldRequest(totalCount: 20, lastRequestedCount: 5)) == true
                }
                it("returns false at total=20, last=20") {
                    expect(policy.shouldRequest(totalCount: 20, lastRequestedCount: 20)) == false
                }
            }

            context("when total skips multiple thresholds in one update") {
                it("returns true at total=50, last=5") {
                    expect(policy.shouldRequest(totalCount: 50, lastRequestedCount: 5)) == true
                }
            }

            context("when total exceeds the last threshold") {
                it("returns false at total=51, last=50") {
                    expect(policy.shouldRequest(totalCount: 51, lastRequestedCount: 50)) == false
                }
                it("returns false at total=1000, last=50") {
                    expect(policy.shouldRequest(totalCount: 1000, lastRequestedCount: 50)) == false
                }
            }
        }
    }
}
