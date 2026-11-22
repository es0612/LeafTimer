@testable import LeafTimer
import XCTest

// Issue #211: LocalSessionStatsRepository.load() が、旧い日付キーの書き直しを 1 回だけ行う。
final class SessionStatsCalendarMigrationTests: XCTestCase {
    private let suiteName = "SessionStatsCalendarMigrationTests"
    private var testDefaults: UserDefaults!

    private var now: Date {
        DateManager.keyCalendar().date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12))!
    }

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

    private func makeRepository(_ localeID: String) -> LocalSessionStatsRepository {
        let fixedNow = now
        return LocalSessionStatsRepository(
            userDefaults: testDefaults, legacyLocale: Locale(identifier: localeID), now: { fixedNow }
        )
    }

    private func saveStats(_ daily: [String: Int], last: String?) throws {
        let stats = SessionStats(dailyCount: daily, totalCount: 10, currentStreak: 2, longestStreak: 5, lastSessionDate: last)
        testDefaults.set(try JSONEncoder().encode(stats), forKey: "sessionStats")
        testDefaults.set(true, forKey: "statsMigrated")
    }

    func test_loadConvertsJapaneseKeysAndSetsFlag() throws {
        try saveStats(["0008/11/22": 3], last: "0008/11/22")
        let repository = makeRepository("ja_JP@calendar=japanese")

        let first = repository.load()
        let second = repository.load()

        XCTAssertEqual(first.dailyCount, ["2026/11/22": 3])
        XCTAssertEqual(first.lastSessionDate, "2026/11/22")
        XCTAssertTrue(testDefaults.bool(forKey: "statsDateKeysGregorian"))
        XCTAssertEqual(second, first)
    }

    func test_conversionRunsOnlyOnce() throws {
        try saveStats(["0008/11/22": 3], last: "0008/11/22")
        let repository = makeRepository("ja_JP@calendar=japanese")
        _ = repository.load()

        try saveStats(["0008/11/21": 1], last: "0008/11/21")

        XCTAssertEqual(repository.load().dailyCount, ["0008/11/21": 1])
    }

    func test_gregorianLoadKeepsStatsAndSetsFlag() throws {
        try saveStats(["2026/11/22": 2], last: "2026/11/22")

        let stats = makeRepository("ja_JP").load()

        XCTAssertEqual(
            stats,
            SessionStats(dailyCount: ["2026/11/22": 2], totalCount: 10, currentStreak: 2, longestStreak: 5, lastSessionDate: "2026/11/22")
        )
        XCTAssertTrue(testDefaults.bool(forKey: "statsDateKeysGregorian"))
    }

    // 旧形式 (UserDefaults に日付キーを直接持つ) の移行は端末のロケールで読む。
    // タイ仏暦の閏日 2563/02/29 はグレゴリオ暦で読むと 3/1 にずれ、連続が (2, 1) になる
    // (2026-11-22 に scratchpad で実測)。
    func test_legacyMigrationThenCalendarConversion() {
        testDefaults.set(1, forKey: "2563/02/28")
        testDefaults.set(1, forKey: "2563/02/29")
        testDefaults.set(1, forKey: "2563/03/01")

        let stats = makeRepository("th_TH").load()

        XCTAssertEqual(stats.dailyCount, ["2020/02/28": 1, "2020/02/29": 1, "2020/03/01": 1])
        XCTAssertEqual(stats.currentStreak, 3)
        XCTAssertEqual(stats.longestStreak, 3)
        XCTAssertEqual(stats.lastSessionDate, "2020/03/01")
    }
}
