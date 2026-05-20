@testable import LeafTimer

class MockReviewRequester: ReviewRequesting {
    // MARK: - Call Tracking

    private(set) var requestReviewCallCount = 0
    private(set) var openAppStoreReviewPageCallCount = 0

    // MARK: - ReviewRequesting Implementation

    func requestReview() {
        requestReviewCallCount += 1
    }

    func openAppStoreReviewPage() {
        openAppStoreReviewPageCallCount += 1
    }

    // MARK: - Helper Methods for Testing

    func reset() {
        requestReviewCallCount = 0
        openAppStoreReviewPageCallCount = 0
    }
}
