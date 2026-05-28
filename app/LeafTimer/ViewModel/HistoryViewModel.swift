import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    private let repository: SessionStatsRepository

    @Published var last7Days: [(date: String, count: Int)] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalCount: Int = 0

    init(repository: SessionStatsRepository) {
        self.repository = repository
    }

    func load(today: String = DateManager.getToday()) {
        let stats = repository.load()
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
        totalCount = stats.totalCount
        last7Days = repository.recentDailyCounts(days: 7, endingAt: today)
    }
}
