@testable import LeafTimer
import XCTest

// Issue #211: 端末のロケール (暦と数字) で保存された旧い日付キーを、グレゴリオ暦 + ASCII 数字の
// キーへ書き直す。期待値は 2026-11-22 に scratchpad の Swift で試作して確かめたもの。
final class DateKeyCalendarMigrationTests: XCTestCase {
    private let japanese = Locale(identifier: "ja_JP@calendar=japanese")
    private let thai = Locale(identifier: "th_TH")
    private let japaneseGregorian = Locale(identifier: "ja_JP")
    private let egyptian = Locale(identifier: "ar_EG")

    private var now: Date {
        DateManager.keyCalendar().date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 12))!
    }

    private func stats(_ daily: [String: Int], last: String?) -> SessionStats {
        SessionStats(dailyCount: daily, totalCount: 10, currentStreak: 2, longestStreak: 5, lastSessionDate: last)
    }

    private func migrate(_ input: SessionStats, _ locale: Locale) -> SessionStats {
        DateKeyCalendarMigration.migrate(input, legacyLocale: locale, now: now)
    }

    func test_japaneseKeysBecomeGregorian() {
        let result = migrate(stats(["0008/11/21": 2, "0008/11/22": 3], last: "0008/11/22"), japanese)

        XCTAssertEqual(result.dailyCount, ["2026/11/21": 2, "2026/11/22": 3])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
        XCTAssertEqual(result.totalCount, 10)
        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.longestStreak, 5)
    }

    func test_buddhistKeysBecomeGregorian() {
        let result = migrate(stats(["2569/11/22": 4], last: "2569/11/22"), thai)

        XCTAssertEqual(result.dailyCount, ["2026/11/22": 4])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
    }

    func test_gregorianStatsAreUnchanged() {
        let input = stats(["2026/11/21": 1, "2026/11/22": 2], last: "2026/11/22")

        let result = migrate(input, japaneseGregorian)

        XCTAssertEqual(result, input)
        XCTAssertEqual(result.totalCount, 10)
        XCTAssertEqual(result.currentStreak, 2)
        XCTAssertEqual(result.longestStreak, 5)
    }

    // 暦を途中で変えた人のグレゴリオ暦のキーは、和暦として読むと 4044 年になる → 元のまま残す
    func test_outOfRangeConversionKeepsOriginalKey() {
        let result = migrate(stats(["2026/11/20": 1, "0008/11/22": 3], last: "0008/11/22"), japanese)

        XCTAssertEqual(result.dailyCount, ["2026/11/20": 1, "2026/11/22": 3])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
    }

    func test_collidingKeysAreSummed() {
        let result = migrate(stats(["0008/11/22": 2, "2026/11/22": 1], last: "2026/11/22"), japanese)

        XCTAssertEqual(result.dailyCount, ["2026/11/22": 3])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
    }

    func test_unparsableKeyIsKept() {
        let result = migrate(stats(["garbage": 1, "0008/11/22": 3], last: nil), japanese)

        XCTAssertEqual(result.dailyCount, ["garbage": 1, "2026/11/22": 3])
        XCTAssertNil(result.lastSessionDate)
    }

    // 中国暦の yyyy は 60 年周期の中の年。旧 formatter に defaultDate (now の正午) が無いと
    // 周期を補えず紀元前の年になり、範囲外で変換されない (最終レビュー I-2)
    func test_chineseKeysBecomeGregorian() {
        let result = migrate(stats(["0043/10/14": 2], last: "0043/10/14"), Locale(identifier: "zh_CN@calendar=chinese"))

        XCTAssertEqual(result.dailyCount, ["2026/11/22": 2])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
    }

    // Cairo は 2026-04-24 (金) の 0 時に夏時間が始まり、その日の 0 時が存在しない。
    // defaultDate が無いと旧 formatter が nil を返し、キーが元のまま残る (最終レビュー I-2)
    func test_keyOnDaylightSavingStartDayIsConverted() throws {
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "Africa/Cairo"))
        defer { NSTimeZone.default = originalTimeZone }

        let result = migrate(stats(["٢٠٢٦/٠٤/٢٤": 1], last: "٢٠٢٦/٠٤/٢٤"), egyptian)

        XCTAssertEqual(result.dailyCount, ["2026/04/24": 1])
        XCTAssertEqual(result.lastSessionDate, "2026/04/24")
    }

    // ar_EG は暦がグレゴリオ暦でも、数字がアラビア数字で保存されている
    func test_arabicDigitKeysBecomeASCII() {
        let result = migrate(stats(["٢٠٢٦/١١/٢٢": 5], last: "٢٠٢٦/١١/٢٢"), egyptian)

        XCTAssertEqual(result.dailyCount, ["2026/11/22": 5])
        XCTAssertEqual(result.lastSessionDate, "2026/11/22")
    }
}
