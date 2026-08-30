import XCTest
@testable import LeafTimer

final class OnboardingLocalizationTests: XCTestCase {

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
