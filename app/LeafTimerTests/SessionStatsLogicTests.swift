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

    func testSameDaySecondSession_streakUnchanged() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/28")
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.totalCount, 2)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 2)
        XCTAssertEqual(stats.currentStreak, 1, "同日 2 件目以降は streak 変えない")
        XCTAssertEqual(stats.longestStreak, 1)
    }

    func testConsecutiveDay_streakIncrements() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/27")
        let stats = repo.recordSession(today: "2026/05/28")

        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 2)
    }

    func testGap_streakResets() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        let stats = repo.recordSession(today: "2026/05/28")  // 1 日空き

        XCTAssertEqual(stats.currentStreak, 1, "1 日以上空くと reset")
        XCTAssertEqual(stats.longestStreak, 1)
    }

    func testLongestStreakKeptWhenCurrentDrops() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        _ = repo.recordSession(today: "2026/05/27")
        _ = repo.recordSession(today: "2026/05/28")  // 3 連続
        let stats = repo.recordSession(today: "2026/05/31")  // 2 日空き、reset

        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 3, "過去の最長は維持される")
    }

    // MARK: - recentDailyCounts

    func testRecentDailyCountsIncludesToday() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/28")
        _ = repo.recordSession(today: "2026/05/28")  // 同日 2 件目

        let result = repo.recentDailyCounts(days: 7, endingAt: "2026/05/28")

        XCTAssertEqual(result.count, 7, "today を含む 7 日分")
        XCTAssertEqual(result.last?.date, "2026/05/28", "末尾が today (古い→新しい順)")
        XCTAssertEqual(result.last?.count, 2)
        XCTAssertEqual(result.first?.date, "2026/05/22", "先頭は 6 日前")
        XCTAssertEqual(result.first?.count, 0, "記録のない日は 0")
    }

    func testRecentDailyCountsFillsMissingDays() {
        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo.recordSession(today: "2026/05/26")
        _ = repo.recordSession(today: "2026/05/28")

        let result = repo.recentDailyCounts(days: 7, endingAt: "2026/05/28")
        let dict = Dictionary(uniqueKeysWithValues: result.map { ($0.date, $0.count) })

        XCTAssertEqual(dict["2026/05/26"], 1)
        XCTAssertEqual(dict["2026/05/27"], 0, "間の日は 0")
        XCTAssertEqual(dict["2026/05/28"], 1)
    }
}
