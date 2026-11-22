@testable import LeafTimer
import XCTest

// Issue #211: 日付キー (yyyy/MM/dd) は端末の暦・数字に左右されないよう、
// グレゴリオ暦 + en_US_POSIX に固定する。
final class DateManagerTests: XCTestCase {
    func test_makeKeyFormatter_isFixedToGregorianPOSIX() {
        let formatter = DateManager.makeKeyFormatter()
        XCTAssertEqual(formatter.calendar.identifier, .gregorian)
        XCTAssertEqual(formatter.locale.identifier, "en_US_POSIX")
        XCTAssertEqual(formatter.dateFormat, "yyyy/MM/dd")
    }

    func test_keyCalendar_isGregorian() {
        XCTAssertEqual(DateManager.keyCalendar().identifier, .gregorian)
    }
}
