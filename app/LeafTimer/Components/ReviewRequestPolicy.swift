import Foundation

protocol ReviewRequestPolicy {
    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool
}

struct ThresholdReviewRequestPolicy: ReviewRequestPolicy {
    static let thresholds = [5, 20, 50]

    func shouldRequest(totalCount: Int, lastRequestedCount: Int) -> Bool {
        Self.thresholds.contains { threshold in
            lastRequestedCount < threshold && totalCount >= threshold
        }
    }
}
