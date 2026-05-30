// app/LeafTimerTests/StatLocalizationTests.swift
import XCTest
@testable import LeafTimer

final class StatLocalizationTests: XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return "<<missing \(locale).lproj>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

    func testTodayChipJapanese() {
        XCTAssertEqual(String(format: localized("timer.stat.today", locale: "ja"), 3), "今日 3")
    }

    func testTodayChipEnglish() {
        XCTAssertEqual(String(format: localized("timer.stat.today", locale: "en"), 3), "Today 3")
    }

    func testStreakChipJapanese() {
        XCTAssertEqual(String(format: localized("timer.stat.streak", locale: "ja"), 5), "連続 5")
    }

    func testStreakChipEnglish() {
        XCTAssertEqual(String(format: localized("timer.stat.streak", locale: "en"), 5), "Streak 5")
    }

    func testNoFireEmojiInTopScreenStrings() {
        XCTAssertFalse(localized("timer.stat.today", locale: "ja").contains("🔥"))
        XCTAssertFalse(localized("timer.stat.streak", locale: "ja").contains("🔥"))
        XCTAssertFalse(localized("timer.stat.streak", locale: "en").contains("🔥"))
    }
}
