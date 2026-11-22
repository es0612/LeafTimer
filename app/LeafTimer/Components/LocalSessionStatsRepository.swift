import Foundation

class LocalSessionStatsRepository: SessionStatsRepository {
    private let userDefaults: UserDefaults
    private let storageKey = "sessionStats"
    private let dateKeysGregorianKey = "statsDateKeysGregorian"
    /// Issue #211: 旧データの日付キーを書いた端末のロケール (暦と数字)。テストで差し替える。
    private let legacyLocale: Locale
    private let now: () -> Date

    init(userDefaults: UserDefaults = .standard, legacyLocale: Locale = .current, now: @escaping () -> Date = Date.init) {
        self.userDefaults = userDefaults
        self.legacyLocale = legacyLocale
        self.now = now
    }

    func load() -> SessionStats {
        if !userDefaults.bool(forKey: "statsMigrated") {
            performMigration()
        }
        if !userDefaults.bool(forKey: dateKeysGregorianKey) {
            migrateDateKeysToGregorian()
        }
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
        let stats = load()
        let formatter = DateManager.makeKeyFormatter()
        let calendar = DateManager.keyCalendar()
        guard let endDate = formatter.date(from: endingAt) else { return [] }

        var result: [(date: String, count: Int)] = []
        for offset in (0..<days).reversed() {  // (days-1)..0 を旧→新
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { continue }
            let key = formatter.string(from: date)
            result.append((date: key, count: stats.dailyCount[key] ?? 0))
        }
        return result
    }

    // MARK: - Private

    private func save(_ stats: SessionStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func isYesterday(_ candidate: String, of today: String) -> Bool {
        SessionStats.isPreviousDay(candidate, of: today)
    }

    // MARK: - Migration

    private func performMigration() {
        let datePattern = #"^\d{4}/\d{2}/\d{2}$"#
        var dailyCount: [String: Int] = [:]
        for (key, value) in userDefaults.dictionaryRepresentation() {
            guard key.range(of: datePattern, options: .regularExpression) != nil,
                  let count = value as? Int else { continue }
            dailyCount[key] = count
        }

        let legacyTotal = userDefaults.integer(forKey: "totalPomodoroCount")
        let derivedTotal = dailyCount.values.reduce(0, +)
        let (longest, current, lastDate) = computeStreaks(from: dailyCount)
        let stats = SessionStats(
            dailyCount: dailyCount,
            totalCount: max(legacyTotal, derivedTotal),
            currentStreak: current,
            longestStreak: longest,
            lastSessionDate: lastDate
        )
        save(stats)
        userDefaults.set(true, forKey: "statsMigrated")
    }

    /// Issue #211: 端末のロケールで保存した日付キーを、グレゴリオ暦のキーへ 1 回だけ書き直す。
    private func migrateDateKeysToGregorian() {
        if let data = userDefaults.data(forKey: storageKey),
           let stats = try? JSONDecoder().decode(SessionStats.self, from: data) {
            let migrated = DateKeyCalendarMigration.migrate(stats, legacyLocale: legacyLocale, now: now())
            if migrated != stats {
                save(migrated)
            }
        }
        userDefaults.set(true, forKey: dateKeysGregorianKey)
    }

    private func computeStreaks(from dailyCount: [String: Int]) -> (longest: Int, current: Int, lastDate: String?) {
        let sortedDates = dailyCount.keys.sorted()
        guard !sortedDates.isEmpty else { return (0, 0, nil) }

        // 旧データは端末のロケール (暦と数字) で書かれているので、旧挙動のまま読む (Issue #211)
        let formatter = DateFormatter()
        formatter.locale = legacyLocale
        formatter.dateFormat = "yyyy/MM/dd"
        let calendar: Calendar = formatter.calendar

        var longest = 1
        var run = 1
        for i in 1..<sortedDates.count {
            guard let prev = formatter.date(from: sortedDates[i - 1]),
                  let curr = formatter.date(from: sortedDates[i]),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: prev) else {
                run = 1; continue
            }
            if calendar.isDate(curr, inSameDayAs: nextDay) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        var current = 1
        for i in stride(from: sortedDates.count - 1, to: 0, by: -1) {
            guard let curr = formatter.date(from: sortedDates[i]),
                  let prev = formatter.date(from: sortedDates[i - 1]),
                  let yesterday = calendar.date(byAdding: .day, value: -1, to: curr) else { break }
            if calendar.isDate(prev, inSameDayAs: yesterday) {
                current += 1
            } else {
                break
            }
        }
        return (longest, current, sortedDates.last)
    }
}
