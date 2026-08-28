import Foundation
import StoreKit
import UIKit

protocol ReviewRequesting {
    @MainActor func requestReview()
    func openAppStoreReviewPage()
}

final class StoreKitReviewRequester: ReviewRequesting {
    @MainActor
    func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        // Issue #70: SKStoreReviewController.requestReview(in:) は iOS 18 で deprecated。
        // deployment target が iOS 17 のため #available ガードなしで移行できる。
        // Issue #128: main thread 契約は protocol の @MainActor でコンパイル時検査される。
        AppStore.requestReview(in: scene)
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
