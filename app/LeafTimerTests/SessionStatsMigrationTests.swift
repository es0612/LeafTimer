import XCTest
@testable import LeafTimer

final class SessionStatsMigrationTests: XCTestCase {

    private let suiteName = "SessionStatsMigrationTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    func testMigrateLegacyDailyKeys() {
        // 旧データを直接書き込む
        testDefaults.set(3, forKey: "2026/05/26")
        testDefaults.set(5, forKey: "2026/05/27")
        testDefaults.set(2, forKey: "2026/05/28")
        testDefaults.set(20, forKey: "totalPomodoroCount")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.dailyCount["2026/05/26"], 3)
        XCTAssertEqual(stats.dailyCount["2026/05/27"], 5)
        XCTAssertEqual(stats.dailyCount["2026/05/28"], 2)
        // legacy totalPomodoroCount (20) と dailyCount の合計 (10) のうち大きい方
        XCTAssertEqual(stats.totalCount, 20)
    }

    func testMigrationSentinelPreventsRerun() {
        testDefaults.set(3, forKey: "2026/05/27")

        let repo1 = LocalSessionStatsRepository(userDefaults: testDefaults)
        _ = repo1.load()

        XCTAssertTrue(testDefaults.bool(forKey: "statsMigrated"))

        // 2 度目の load は既存 SessionStats を返し、再 migration しない
        testDefaults.set(99, forKey: "2026/06/01")
        let repo2 = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo2.load()
        XCTAssertNil(stats.dailyCount["2026/06/01"], "sentinel 後は再 migration されない")
    }

    func testNonIntegerLegacyKeysSkipped() {
        testDefaults.set(3, forKey: "2026/05/27")
        testDefaults.set("not-an-int", forKey: "2026/05/26")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.dailyCount["2026/05/27"], 3)
        XCTAssertNil(stats.dailyCount["2026/05/26"])
    }

    func testMigrationCalculatesLongestStreak() {
        // 3 連続 + ギャップ + 2 連続
        testDefaults.set(1, forKey: "2026/05/20")
        testDefaults.set(1, forKey: "2026/05/21")
        testDefaults.set(1, forKey: "2026/05/22")
        testDefaults.set(1, forKey: "2026/05/27")
        testDefaults.set(1, forKey: "2026/05/28")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.longestStreak, 3)
        XCTAssertEqual(stats.lastSessionDate, "2026/05/28")
    }

    func testMigrationCurrentStreakWhenLastIsToday() {
        testDefaults.set(1, forKey: "2026/05/27")
        testDefaults.set(1, forKey: "2026/05/28")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.currentStreak, 2)
    }

    func testMigrationCurrentStreakIsOneWhenSingleOldEntry() {
        testDefaults.set(1, forKey: "2025/01/01")

        let repo = LocalSessionStatsRepository(userDefaults: testDefaults)
        let stats = repo.load()

        XCTAssertEqual(stats.longestStreak, 1)
        XCTAssertEqual(stats.lastSessionDate, "2025/01/01")
        // currentStreak は「末尾から連続している長さ」を入れる方針 = 1
        XCTAssertEqual(stats.currentStreak, 1)
    }
}
