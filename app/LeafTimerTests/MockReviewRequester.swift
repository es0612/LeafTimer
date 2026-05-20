@testable import LeafTimer

class MockReviewRequester: ReviewRequesting {
    private(set) var requestReviewCallCount = 0
    private(set) var openAppStoreReviewPageCallCount = 0

    func requestReview() {
        requestReviewCallCount += 1
    }

    func openAppStoreReviewPage() {
        openAppStoreReviewPageCallCount += 1
    }

    func reset() {
        requestReviewCallCount = 0
        openAppStoreReviewPageCallCount = 0
    }
}
