import Foundation

@testable import LeafTimer

class SpyNotificationScheduler: NotificationScheduler {
    private(set) var requestAuthorizationCallCount = 0
    func requestAuthorizationIfNeeded() {
        requestAuthorizationCallCount += 1
    }

    private(set) var scheduledChains: [[NotificationEntry]] = []
    func scheduleChain(entries: [NotificationEntry]) {
        scheduledChains.append(entries)
    }

    private(set) var cancelAllCallCount = 0
    func cancelAll() {
        cancelAllCallCount += 1
    }
}
