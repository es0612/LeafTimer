// app/LeafTimerTests/SettingsLocalizationTests.swift
import XCTest
@testable import LeafTimer

/// Issue #59/#60 で追加したキーが ja/en 両方の Localizable.strings に存在することを検証する。
/// パターンは StatLocalizationTests を踏襲 (テスト実行環境の言語設定に依存しない)。
final class SettingsLocalizationTests: XCTestCase {

    private static let newKeys = [
        // #60: 設定画面
        "settings.done",
        "settings.mode_footer",
        "settings.timer.preview_button",
        "settings.timer.preview_title",
        "settings.timer.preview_work",
        "settings.timer.preview_break",
        "settings.sound_footer",
        "settings.reset.button",
        "settings.reset.alert_title",
        "settings.reset.confirm",
        "settings.reset.alert_message",
        "settings.reset.done_title",
        "settings.reset.done_message",
        "settings.system_section",
        "settings.footer.app_name",
        "settings.footer.copyright",
        "common.cancel",
        "common.ok",
        // #59: VoiceOver ラベル
        "timer.a11y.start",
        "timer.a11y.stop",
        "timer.a11y.reset",
        "timer.a11y.history",
        "timer.a11y.settings",
        "timer.a11y.remaining_time"
    ]

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return "<<missing \(locale).lproj>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

    func testAllNewKeysExistInJapanese() {
        for key in Self.newKeys {
            XCTAssertNotEqual(localized(key, locale: "ja"), "<<missing>>", "ja.lproj に \(key) が無い")
        }
    }

    func testAllNewKeysExistInEnglish() {
        for key in Self.newKeys {
            XCTAssertNotEqual(localized(key, locale: "en"), "<<missing>>", "en.lproj に \(key) が無い")
        }
    }

    func testRepresentativeJapaneseValues() {
        XCTAssertEqual(localized("settings.done", locale: "ja"), "完了")
        XCTAssertEqual(localized("settings.system_section", locale: "ja"), "システム")
        XCTAssertEqual(localized("timer.a11y.start", locale: "ja"), "タイマーを開始")
    }

    func testRepresentativeEnglishValues() {
        XCTAssertEqual(localized("settings.done", locale: "en"), "Done")
        XCTAssertEqual(localized("timer.a11y.stop", locale: "en"), "Stop timer")
    }
}
