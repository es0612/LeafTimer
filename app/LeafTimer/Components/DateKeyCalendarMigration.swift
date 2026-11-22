import Foundation

/// Issue #211: 端末のロケール (暦と数字) に従って保存された旧い日付キーを、
/// DateManager.makeKeyFormatter() のキー (グレゴリオ暦 + ASCII 数字) へ書き直す。
enum DateKeyCalendarMigration {
    /// LeafTimer の公開 (2020 年) より前のキーは無い、という判断の下限。
    private static let earliestKey = "2020/01/01"

    /// 書き直したキーが earliestKey〜「now の翌日」の外なら元のキーを残す
    /// (暦を途中で変えた人のグレゴリオ暦のキーを和暦として読むと 4044 年になるため)。
    /// 読めないキーも元のまま残す。書き直して同じキーになったら件数を足す。
    /// totalCount / currentStreak / longestStreak は変えない。
    static func migrate(_ stats: SessionStats, legacyLocale: Locale, now: Date) -> SessionStats {
        // 旧挙動と同じく、calendar は設定せずロケールに任せる (ar_EG は暦がグレゴリオ暦でも数字が違う)
        let legacyFormatter = DateFormatter()
        legacyFormatter.locale = legacyLocale
        legacyFormatter.dateFormat = "yyyy/MM/dd"
        let keyFormatter = DateManager.makeKeyFormatter()
        guard let tomorrow = DateManager.keyCalendar().date(byAdding: .day, value: 1, to: now) else {
            return stats
        }
        let latestKey = keyFormatter.string(from: tomorrow)

        func convert(_ key: String) -> String {
            guard let date = legacyFormatter.date(from: key) else { return key }
            let newKey = keyFormatter.string(from: date)
            return (earliestKey...latestKey).contains(newKey) ? newKey : key
        }

        var dailyCount: [String: Int] = [:]
        for (key, count) in stats.dailyCount {
            dailyCount[convert(key), default: 0] += count
        }
        var result = stats
        result.dailyCount = dailyCount
        result.lastSessionDate = stats.lastSessionDate.map(convert)
        return result
    }
}
