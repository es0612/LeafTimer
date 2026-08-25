import XCTest

@testable import LeafTimer

// Issue #62: Reduce Motion 有効時は葉 GIF を先頭フレームの静止画に切り替える。
// host app の実 asset (leaf1) を使い、フレーム構成の変化で静止/再生を判定する。
final class GIFPlayerViewTests: XCTestCase {
    // Reduce Motion ON → 単一フレーム (UIImage.images == nil) の静止画
    func testReduceMotionOnShowsSingleStaticFrame() {
        let view = GIFPlayerView(gifName: "leaf1")

        view.setReduceMotion(true)

        XCTAssertNotNil(view.displayedImage)
        XCTAssertNil(view.displayedImage?.images)
    }

    // Reduce Motion OFF → 複数フレームのアニメ画像 (従来挙動)
    func testReduceMotionOffShowsAnimatedImage() {
        let view = GIFPlayerView(gifName: "leaf1")

        view.setReduceMotion(false)

        XCTAssertGreaterThan(view.displayedImage?.images?.count ?? 0, 1)
    }

    // init 直後 (setReduceMotion 未呼び出し) は従来どおりアニメ再生
    func testInitialStateIsAnimated() {
        let view = GIFPlayerView(gifName: "leaf1")

        XCTAssertGreaterThan(view.displayedImage?.images?.count ?? 0, 1)
    }
}
