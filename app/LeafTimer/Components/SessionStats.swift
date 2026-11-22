// app/LeafTimer/Components/SessionStats.swift
import Foundation

struct SessionStats: Codable, Equatable {
    var dailyCount: [String: Int]
    var totalCount: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: String?

    static let empty = SessionStats(
        dailyCount: [:],
        totalCount: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastSessionDate: nil
    )
}

extension SessionStats {
    /// 表示に使う連続日数 (Issue #206)。最後に記録した日が today でも前日でもなければ
    /// 連続は途切れているので 0 を返す (spec: 2026-05-28-pomodoro-log-visualization-design.md)。
    /// 保存値の currentStreak は書き換えない。次の recordSession が 1 からやり直す。
    func streak(asOf today: String) -> Int {
        guard let last = lastSessionDate else {
            return 0
        }
        if last == today || Self.isPreviousDay(last, of: today) {
            return currentStreak
        }
        return 0
    }

    /// candidate ("yyyy/MM/dd") が today の前日か。recordSession の判定と共通にする。
    static func isPreviousDay(_ candidate: String, of today: String) -> Bool {
        let formatter = DateManager.makeKeyFormatter()
        let calendar = DateManager.keyCalendar()
        guard let todayDate = formatter.date(from: today),
              let candidateDate = formatter.date(from: candidate),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: todayDate) else {
            return false
        }
        return calendar.isDate(candidateDate, inSameDayAs: yesterday)
    }
}
