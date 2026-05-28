import XCTest
@testable import LeafTimer

final class HistoryViewModelTests: XCTestCase {

    func testLoadPopulatesPublishedProperties() {
        let spy = SpySessionStatsRepository()
        spy.stubLoadResult = SessionStats(
            dailyCount: ["2026/05/28": 3],
            totalCount: 50,
            currentStreak: 4,
            longestStreak: 10,
            lastSessionDate: "2026/05/28"
        )
        spy.stubRecentResult = [
            (date: "2026/05/22", count: 0),
            (date: "2026/05/23", count: 1),
            (date: "2026/05/24", count: 2),
            (date: "2026/05/25", count: 0),
            (date: "2026/05/26", count: 3),
            (date: "2026/05/27", count: 0),
            (date: "2026/05/28", count: 3),
        ]
        let vm = HistoryViewModel(repository: spy)

        vm.load(today: "2026/05/28")

        XCTAssertEqual(vm.currentStreak, 4)
        XCTAssertEqual(vm.longestStreak, 10)
        XCTAssertEqual(vm.totalCount, 50)
        XCTAssertEqual(vm.last7Days.count, 7)
        XCTAssertEqual(vm.last7Days.last?.count, 3)
    }

    func testLoadEmptyShowsSevenZeros() {
        let spy = SpySessionStatsRepository()
        spy.stubLoadResult = .empty
        spy.stubRecentResult = (0..<7).map { (date: "2026/05/2\($0)", count: 0) }
        let vm = HistoryViewModel(repository: spy)

        vm.load(today: "2026/05/28")

        XCTAssertEqual(vm.totalCount, 0)
        XCTAssertEqual(vm.currentStreak, 0)
        XCTAssertEqual(vm.last7Days.count, 7)
        XCTAssertTrue(vm.last7Days.allSatisfy { $0.count == 0 })
    }
}
