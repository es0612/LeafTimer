import XCTest
@testable import LeafTimer

final class OnboardingLocalizationTests: XCTestCase {

    /// 指定ロケールの .lproj から key を解決する（simulator の言語設定に依存しない）。
    private func localized(_ key: String, locale: String) -> String {
        let appBundle = Bundle(for: TimerViewModel.self)
        guard let path = appBundle.path(forResource: locale, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return "<<missing \(locale).lproj>>"
        }
        return lproj.localizedString(forKey: key, value: "<<missing>>", table: nil)
    }

    private let keys = [
        "onboarding.welcome.title",
        "onboarding.welcome.body",
        "onboarding.usage.title",
        "onboarding.usage.body",
        "onboarding.skip",
        "onboarding.start_button",
        "settings.help_section",
        "settings.replay_onboarding",
    ]

    func testOnboardingKeysExistInJapanese() {
        for key in keys {
            XCTAssertNotEqual(localized(key, locale: "ja"), "<<missing>>", "ja missing: \(key)")
        }
    }

    func testOnboardingKeysExistInEnglish() {
        for key in keys {
            XCTAssertNotEqual(localized(key, locale: "en"), "<<missing>>", "en missing: \(key)")
        }
    }
}
