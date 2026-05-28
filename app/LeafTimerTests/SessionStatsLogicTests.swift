// app/LeafTimerTests/SessionStatsLogicTests.swift
import XCTest
@testable import LeafTimer

final class SessionStatsLogicTests: XCTestCase {

    // MARK: - Codable round-trip

    func testSessionStatsCodableRoundTrip() throws {
        let stats = SessionStats(
            dailyCount: ["2026/05/28": 3, "2026/05/27": 5],
            totalCount: 8,
            currentStreak: 2,
            longestStreak: 5,
            lastSessionDate: "2026/05/28"
        )
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(SessionStats.self, from: data)
        XCTAssertEqual(stats, decoded)
    }

    func testEmptyHasZeroValues() {
        let s = SessionStats.empty
        XCTAssertTrue(s.dailyCount.isEmpty)
        XCTAssertEqual(s.totalCount, 0)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertNil(s.lastSessionDate)
    }
}
