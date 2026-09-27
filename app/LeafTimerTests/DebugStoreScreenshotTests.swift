import XCTest
@testable import LeafTimer

/// Issue #161: ストア用スクショ撮影 (make store-screenshots) の DEBUG フック。
final class DebugStoreScreenshotTests: XCTestCase {

    private let suiteName = "DebugStoreScreenshotTests"
    private var testDefaults: UserDefaults!
    private let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 27
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

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

    func testSeedIsReadableByLocalSessionStatsRepository() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: ["LeafTimer", DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        let stats = LocalSessionStatsRepository(userDefaults: testDefaults).load()

        XCTAssertEqual(stats, DebugStoreScreenshot.sampleStats(today: today))
        XCTAssertEqual(stats.totalCount, 128)
        XCTAssertEqual(stats.currentStreak, 12)
    }

    func testSeedFillsLastSevenDaysEndingToday() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: [DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        let days = LocalSessionStatsRepository(userDefaults: testDefaults)
            .recentDailyCounts(days: 7, endingAt: "2026/09/27")

        XCTAssertEqual(days.map(\.date).first, "2026/09/21")
        XCTAssertEqual(days.map(\.count), [3, 5, 2, 6, 4, 7, 4])
    }

    func testSeedMarksOnboardingSeen() {
        DebugStoreScreenshot.seedIfRequested(
            arguments: [DebugStoreScreenshot.seedArgument], defaults: testDefaults, today: today
        )

        XCTAssertTrue(testDefaults.bool(forKey: UserDefaultItem.hasSeenOnboarding.rawValue))
    }

    func testSeedIsNotAppliedWithoutArgument() {
        DebugStoreScreenshot.seedIfRequested(arguments: ["LeafTimer"], defaults: testDefaults, today: today)

        XCTAssertNil(testDefaults.data(forKey: "sessionStats"))
        XCTAssertFalse(testDefaults.bool(forKey: UserDefaultItem.hasSeenOnboarding.rawValue))
    }

    func testAutoStartFlagReadsLaunchArgument() {
        XCTAssertTrue(DebugStoreScreenshot.isAutoStartRequested(arguments: ["LeafTimer", "-AutoStart"]))
        XCTAssertFalse(DebugStoreScreenshot.isAutoStartRequested(arguments: ["LeafTimer"]))
    }
}
