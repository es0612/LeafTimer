// app/LeafTimerTests/LocalizationTestSupportTests.swift
import XCTest
@testable import LeafTimer

/// Issue #105: 3 ファイルに重複していた localized(_:locale:) を LocalizationTestSupport に集約した。
/// PR #96 で片方だけ直して他が取り残された drift の再発防止として、helper 自身の sentinel 挙動を固定する。
final class LocalizationTestSupportTests: XCTestCase {

    func testExistingKeyResolvesInBothLocales() {
        XCTAssertNotEqual(localized("timer.title", locale: "ja"), "<<missing>>")
        XCTAssertNotEqual(localized("timer.title", locale: "en"), "<<missing>>")
    }

    func testMissingKeyReturnsSentinel() {
        XCTAssertEqual(localized("definitely.not.a.real.key", locale: "ja"), "<<missing>>")
        XCTAssertEqual(localized("definitely.not.a.real.key", locale: "en"), "<<missing>>")
    }

    func testMissingLocaleReturnsSentinelAndFails() {
        // lproj が丸ごと無い場合は XCTFail + "<<missing>>" (PR #96 で塞いだ抜け穴の固定)。
        // XCTExpectFailure はクロージャ形でスコープを localized 呼び出しだけに絞る —
        // 無引数形だと直後の XCTAssertEqual の失敗まで吸収して vacuous pass になる。
        var result = ""
        XCTExpectFailure("zz.lproj は存在しないので XCTFail が記録される") {
            result = localized("timer.title", locale: "zz")
        }
        XCTAssertEqual(result, "<<missing>>")
    }
}
