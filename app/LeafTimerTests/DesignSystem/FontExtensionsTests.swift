import XCTest
import SwiftUI
@testable import LeafTimer

final class FontExtensionsTests: XCTestCase {

    // MARK: - Timer Display Font Tests

    func testTimerDisplayFontExists() {
        let font = Font.timerDisplay
        XCTAssertNotNil(font)
    }

    func testTimerDisplayFontSize() {
        let fontSize = Font.timerDisplaySize
        XCTAssertEqual(fontSize, 72)
    }

    // MARK: - Session Count Font Tests

    func testSessionCountFontExists() {
        let font = Font.sessionCount
        XCTAssertNotNil(font)
    }

    func testSessionCountFontSize() {
        let fontSize = Font.sessionCountSize
        XCTAssertEqual(fontSize, 24)
    }

    // MARK: - UI Element Font Tests

    func testSettingLabelFontExists() {
        let font = Font.settingLabel
        XCTAssertNotNil(font)
    }

    func testSettingLabelFontSize() {
        let fontSize = Font.settingLabelSize
        XCTAssertEqual(fontSize, 17)
    }

    func testBodyTextFontExists() {
        let font = Font.bodyText
        XCTAssertNotNil(font)
    }

    func testHeadlineFontExists() {
        let font = Font.headline
        XCTAssertNotNil(font)
    }

    func testSubheadlineFontExists() {
        let font = Font.subheadline
        XCTAssertNotNil(font)
    }

    func testCaptionFontExists() {
        let font = Font.caption
        XCTAssertNotNil(font)
    }

    func testFootnoteFontExists() {
        let font = Font.footnote
        XCTAssertNotNil(font)
    }

    // MARK: - Button Font Tests

    func testButtonPrimaryFontExists() {
        let font = Font.buttonPrimary
        XCTAssertNotNil(font)
    }

    func testButtonSecondaryFontExists() {
        let font = Font.buttonSecondary
        XCTAssertNotNil(font)
    }

    // MARK: - Dynamic Type Support Tests

    func testSupportsDynamicType() {
        XCTAssertTrue(Font.supportsDynamicType)
    }

    func testTimerDisplayWithDynamicType() {
        let font = Font.timerDisplayDynamic(.large)
        XCTAssertNotNil(font)
    }

    func testBodyTextWithDynamicType() {
        let font = Font.bodyTextDynamic(.medium)
        XCTAssertNotNil(font)
    }

    // MARK: - Font Weight Tests

    func testFontWeightUltraLight() {
        let weight = Font.Weight.ultraLight
        XCTAssertNotNil(weight)
    }

    func testFontWeightSemibold() {
        let weight = Font.Weight.semibold
        XCTAssertNotNil(weight)
    }

    func testFontWeightMedium() {
        let weight = Font.Weight.medium
        XCTAssertNotNil(weight)
    }

    // MARK: - Design Tests

    func testMonospacedDesignForTimer() {
        let isMonospaced = Font.timerDisplayIsMonospaced
        XCTAssertTrue(isMonospaced)
    }
}