// app/LeafTimer/Components/SessionStatsRepository.swift
import Foundation

protocol SessionStatsRepository {
    func load() -> SessionStats
    @discardableResult
    func recordSession(today: String) -> SessionStats
    func recentDailyCounts(days: Int, endingAt: String) -> [(date: String, count: Int)]
}
