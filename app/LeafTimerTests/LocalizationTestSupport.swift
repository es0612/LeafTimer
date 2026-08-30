// app/LeafTimerTests/LocalizationTestSupport.swift
import XCTest
@testable import LeafTimer

/// Issue #105: Settings / Stat / Onboarding の Localization テストで重複していた helper の集約先。
extension XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    /// - lproj が見つからない: XCTFail を記録し "<<missing>>" を返す (PR #96 の抜け穴修正を維持)
    /// - key が無い: "<<missing>>" を返す
    func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            XCTFail("\(locale).lproj が見つからない")
            return "<<missing>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }
}
