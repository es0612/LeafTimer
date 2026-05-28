import Foundation

class LocalSessionStatsRepository: SessionStatsRepository {
    private let userDefaults: UserDefaults
    private let storageKey = "sessionStats"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> SessionStats {
        guard let data = userDefaults.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(SessionStats.self, from: data) else {
            return .empty
        }
        return stats
    }

    @discardableResult
    func recordSession(today: String) -> SessionStats {
        var stats = load()

        stats.totalCount += 1
        stats.dailyCount[today, default: 0] += 1

        // streak 更新は Task 6 で本実装、ここでは最小限
        stats.currentStreak = 1
        stats.longestStreak = max(stats.longestStreak, 1)
        stats.lastSessionDate = today

        save(stats)
        return stats
    }

    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)] {
        // Task 7 で実装
        return []
    }

    // MARK: - Private

    private func save(_ stats: SessionStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
