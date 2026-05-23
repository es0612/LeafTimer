import Nimble
import Quick

@testable import LeafTimer

class KeyManagerSpec: QuickSpec {
    override class func spec() {
        describe("KeyManager") {
            describe("getAdUnitID()") {
                it("returns Google's official test banner ID in Debug builds") {
                    // テストターゲットは常に Debug Configuration でビルドされるため、
                    // ここでは Debug 分岐 (Google 公式テスト ID) のみを検証する。
                    // Release 分岐は #if !DEBUG で別途コードレビューで担保。
                    let adUnitID = KeyManager().getAdUnitID()
                    expect(adUnitID) == "ca-app-pub-3940256099942544/2934735716"
                }
            }
        }
    }
}
