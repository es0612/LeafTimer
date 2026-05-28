// app/LeafTimerTests/SpySessionStatsRepository.swift
import Foundation
@testable import LeafTimer

class SpySessionStatsRepository: SessionStatsRepository {
    var stubLoadResult: SessionStats = .empty
    var stubRecentResult: [(date: String, count: Int)] = []

    private(set) var loadCallCount = 0
    private(set) var recordSessionCallCount = 0
    private(set) var lastRecordedToday: String?

    func load() -> SessionStats {
        loadCallCount += 1
        return stubLoadResult
    }

    @discardableResult
    func recordSession(today: String) -> SessionStats {
        recordSessionCallCount += 1
        lastRecordedToday = today
        return stubLoadResult
    }

    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] {
        return stubRecentResult
    }

    func reset() {
        loadCallCount = 0
        recordSessionCallCount = 0
        lastRecordedToday = nil
        stubLoadResult = .empty
        stubRecentResult = []
    }
}
