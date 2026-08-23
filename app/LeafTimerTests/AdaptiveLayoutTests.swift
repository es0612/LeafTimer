import SwiftUI
import XCTest

@testable import LeafTimer

/// Issue #64: 固定 frame → 画面比率レイアウトの純粋ロジック検証。
final class AdaptiveLayoutTests: XCTestCase {
    // 参照サイズ (iPhone 17 の content 領域近似) では現行の固定値を維持する (回帰基準)
    func testReferenceSizeKeepsLegacyValues() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 390, height: 760))

        XCTAssertEqual(metrics.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(metrics.leafSize(for: .small), 90, accuracy: 0.5)
        XCTAssertEqual(metrics.leafSize(for: .mid), 200, accuracy: 0.5)
        XCTAssertEqual(metrics.leafSize(for: .big), 350, accuracy: 0.5)
        XCTAssertEqual(metrics.leafBottomPadding(for: .big), 300, accuracy: 0.5)
        XCTAssertEqual(metrics.leafTrailingPadding(for: .small), 22, accuracy: 0.5)
        XCTAssertEqual(metrics.leafLeadingPadding(for: .mid), 11, accuracy: 0.5)
    }

    // SE (content 高さ ≒ 600pt) では縮小され、big 葉 + bottom padding が画面内に収まる
    func testSmallDeviceScalesDownAndFits() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 375, height: 600))

        XCTAssertEqual(metrics.scale, 600.0 / 760.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(
            metrics.leafSize(for: .big) + metrics.leafBottomPadding(for: .big), 600
        )
    }

    // iPad (content 高さ ≒ 1110pt) は上限 1.35 でキャップされバルーン化しない
    func testLargeDeviceIsCapped() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 820, height: 1110))

        XCTAssertEqual(metrics.scale, 1.35, accuracy: 0.001)
        XCTAssertEqual(metrics.leafSize(for: .big), 350 * 1.35, accuracy: 0.5)
    }

    // 極端に小さい入力 (回転直後の 0 サイズ等) でも下限 0.55 でクランプされる
    func testTinySizeClampsToLowerBound() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 320, height: 100))

        XCTAssertEqual(metrics.scale, 0.55, accuracy: 0.001)
    }

    // Issue #114: iPad Split View の細長ウィンドウ (幅 320 × 高さ 1000) では
    // 高さ比 (1.32) でなく幅比 (320/390 ≈ 0.82) が採用され、big 葉がはみ出さない
    func testNarrowTallWindowUsesWidthRatio() {
        let metrics = TimerLayoutMetrics(contentSize: CGSize(width: 320, height: 1000))

        XCTAssertEqual(metrics.scale, 320.0 / 390.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(metrics.leafSize(for: .big), 320)
    }

    // AX5 で @ScaledMetric が拡大した直径は 210pt でキャップされる
    func testCircleButtonDiameterIsCapped() {
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 150), 150)
        XCTAssertEqual(CircleButton.resolvedDiameter(scaled: 320), 210)
    }

    // Issue #113: accessibility サイズでは StatChip の横並びが SE 幅に収まらず
    // 左チップが「今…」に省略されるため、縦積みレイアウトへ切り替える
    func testStatChipsStackVerticallyOnlyAtAccessibilitySizes() {
        XCTAssertFalse(StatChip.usesVerticalLayout(for: .large))
        XCTAssertFalse(StatChip.usesVerticalLayout(for: .xxxLarge))
        XCTAssertTrue(StatChip.usesVerticalLayout(for: .accessibility1))
        XCTAssertTrue(StatChip.usesVerticalLayout(for: .accessibility5))
    }
}
