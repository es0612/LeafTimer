import XCTest

@testable import LeafTimer

final class NotificationChainBuilderTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let work = 25 * 60
    private let brk = 5 * 60

    // work 中に開始 → workEnd, breakEnd, ... が交互に 6 件
    func testBuildsAlternatingChainFromWork() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: false,
            workDuration: work, breakDuration: brk
        )
        XCTAssertEqual(entries.count, 6)
        XCTAssertEqual(entries[0], NotificationEntry(
            fireDate: base,
            titleKey: "notification.workEnd.title",
            bodyKey: "notification.workEnd.body"
        ))
        XCTAssertEqual(entries[1], NotificationEntry(
            fireDate: base.addingTimeInterval(TimeInterval(brk)),
            titleKey: "notification.breakEnd.title",
            bodyKey: "notification.breakEnd.body"
        ))
        XCTAssertEqual(entries[2].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            entries[2].fireDate,
            base.addingTimeInterval(TimeInterval(brk + work))
        )
    }

    // break 中に開始 → 先頭は breakEnd
    func testBuildsChainFromBreak() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: true,
            workDuration: work, breakDuration: brk
        )
        XCTAssertEqual(entries[0].titleKey, "notification.breakEnd.title")
        XCTAssertEqual(entries[1].titleKey, "notification.workEnd.title")
        XCTAssertEqual(
            entries[1].fireDate,
            base.addingTimeInterval(TimeInterval(work))
        )
    }

    // duration 両方 0 は空チェーン
    func testZeroDurationsReturnEmpty() {
        let entries = NotificationChainBuilder.build(
            endDate: base, breakState: false,
            workDuration: 0, breakDuration: 0
        )
        XCTAssertTrue(entries.isEmpty)
    }
}
