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
