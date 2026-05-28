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

        let last = stats.lastSessionDate
        if last == today {
            // 同日 2 件目以降は streak 変えない
        } else if let last = last, isYesterday(last, of: today) {
            stats.currentStreak += 1
        } else {
            stats.currentStreak = 1
        }
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
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

    private func isYesterday(_ candidate: String, of today: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        guard let todayDate = formatter.date(from: today),
              let candidateDate = formatter.date(from: candidate),
              let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: todayDate) else {
            return false
        }
        return Calendar.current.isDate(candidateDate, inSameDayAs: yesterday)
    }
}
