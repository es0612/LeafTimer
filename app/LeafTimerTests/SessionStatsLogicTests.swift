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

    // MARK: - LocalSessionStatsRepository 基本ロジック

    private let testSuiteName = "SessionStatsLogicTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testRecordSessionFromEmpty() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 1)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 1)
        XCTAssertEqual(stats.lastSessionDate, "2026/05/28")
    }

    func testLoadAfterRecordPersists() {
        let repo1 = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo1.recordSession(today: "2026/05/28")

        let repo2 = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo2.load()
        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 1)
    }

    func testLoadWhenEmptyReturnsEmpty() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()
        XCTAssertEqual(stats, .empty)
    }
}
