import XCTest
@testable import LeafTimer

/// Issue #70: CircleButton の内側円比率をリテラル重複から static 定数に集約した際、
/// 見た目が変わっていないことを固定するテスト。
final class CircleButtonRatioTests: XCTestCase {

    func testInnerRatiosMatchOriginalLiterals() {
        XCTAssertEqual(CircleButton.innerRatios.second, 140.0 / 150.0, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.innerRatios.third, 120.0 / 150.0, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.innerRatios.inner, 105.0 / 150.0, accuracy: 0.0001)
    }

    func testResolvedDiameterIsCappedAtMaxDiameter() {
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 150), 150, accuracy: 0.0001)
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 300), CircleButton.maxDiameter, accuracy: 0.0001)
    }
}
