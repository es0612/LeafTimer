#if DEBUG
import Foundation

/// Issue #161: ストア用スクショ撮影 (`make store-screenshots`) の起動引数フック。
/// simctl には tap も app コンテナの UserDefaults への確実な書き込み手段も無い
/// (`simctl spawn defaults write` はコンテナ外に書き、plist 直書きは cfprefsd に
/// 戻される — 2026-09-27 実測) ため、撮影用の状態はアプリ自身に作らせる。
enum DebugStoreScreenshot {
    static let seedArgument = "-SeedSampleStats"
    static let autoStartArgument = "-AutoStart"

    /// 過去 7 日 (today を含む) の件数と、見栄えのする streak / 累計の固定値。
    static func sampleStats(today: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> SessionStats {
        let counts = [3, 5, 2, 6, 4, 7, 4]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"

        var dailyCount: [String: Int] = [:]
        for (offset, count) in counts.enumerated() {
            let day = calendar.date(byAdding: .day, value: offset - (counts.count - 1), to: today)!
            dailyCount[formatter.string(from: day)] = count
        }
        return SessionStats(
            dailyCount: dailyCount,
            totalCount: 128,
            currentStreak: 12,
            longestStreak: 21,
            lastSessionDate: formatter.string(from: today)
        )
    }

    /// `-SeedSampleStats` がある時だけ、LocalSessionStatsRepository と同じキーに書き込む。
    /// オンボーディングも既読にして、タイマー画面の上に fullScreenCover が出ないようにする。
    static func seedIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        today: Date = Date()
    ) {
        guard arguments.contains(seedArgument),
              let data = try? JSONEncoder().encode(sampleStats(today: today)) else { return }
        defaults.set(data, forKey: "sessionStats")
        defaults.set(true, forKey: "statsMigrated")
        defaults.set(true, forKey: UserDefaultItem.hasSeenOnboarding.rawValue)
    }

    static func isAutoStartRequested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(autoStartArgument)
    }
}
#endif
