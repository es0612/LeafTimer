import XCTest
@testable import LeafTimer

/// Issue #70: CircleButton の内側円比率をリテラル重複から static 定数に集約した際の
/// 設計意図を固定するテスト。
final class CircleButtonRatioTests: XCTestCase {

    /// 入れ子の円は内側ほど小さく、かつ最外円 (比率 1.0) を超えない。
    /// 定義式の再掲ではなく「入れ子構造が壊れていないこと」を検証する。
    func testInnerRatiosAreStrictlyNested() {
        let ratios = CircleButton.innerRatios
        XCTAssertTrue(
            0 < ratios.inner && ratios.inner < ratios.third
                && ratios.third < ratios.second && ratios.second < 1,
            "内側円の比率は 0 < inner < third < second < 1 を満たす必要がある: \(ratios)"
        )
    }
}
