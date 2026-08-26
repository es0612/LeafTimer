import Foundation
import StoreKit
import UIKit

protocol ReviewRequesting {
    func requestReview()
    func openAppStoreReviewPage()
}

final class StoreKitReviewRequester: ReviewRequesting {
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        // Issue #70: SKStoreReviewController.requestReview(in:) は iOS 18 で deprecated。
        // deployment target が iOS 17 のため #available ガードなしで移行できる。
        // requestReview() は Timer コールバック (main queue async) と
        // UIApplication.willEnterForegroundNotification の @objc ハンドラ経由でのみ
        // 呼ばれ、常に main thread から呼ばれる前提のため assumeIsolated で通す。
        MainActor.assumeIsolated {
            AppStore.requestReview(in: scene)
        }
    }

    func openAppStoreReviewPage() {
        guard let appID = Bundle.main.object(forInfoDictionaryKey: "LeafTimerAppStoreID") as? String,
              !appID.isEmpty,
              let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
