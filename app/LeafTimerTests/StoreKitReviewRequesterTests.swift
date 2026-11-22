@testable import LeafTimer
import XCTest

// Issue #216: 設定画面の「このアプリを評価する」は Info.plist の LeafTimerAppStoreID から
// App Store のレビューページ URL を作る。キーが無いと黙って何もしない。
final class StoreKitReviewRequesterTests: XCTestCase {
    func test_infoPlist_declaresAppStoreID() {
        // 1520649806 は iTunes lookup (bundleId=jp.ema.LeafTimer) の trackId
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "LeafTimerAppStoreID") as? String,
            "1520649806"
        )
    }

    func test_reviewPageURL_buildsWriteReviewURLFromAppID() {
        XCTAssertEqual(
            StoreKitReviewRequester.reviewPageURL(appID: "1520649806")?.absoluteString,
            "https://apps.apple.com/app/id1520649806?action=write-review"
        )
    }

    func test_reviewPageURL_returnsNilWhenAppIDIsMissingOrEmpty() {
        XCTAssertNil(StoreKitReviewRequester.reviewPageURL(appID: nil))
        XCTAssertNil(StoreKitReviewRequester.reviewPageURL(appID: ""))
    }
}
