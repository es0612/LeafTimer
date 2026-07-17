import Foundation
import UIKit

protocol ConsentService {
    var canRequestAds: Bool { get }
    func gatherConsent(
        from viewController: UIViewController?,
        completion: @escaping (Error?) -> Void
    )
}

protocol TrackingAuthorizer {
    func requestAuthorization(completion: @escaping () -> Void)
}

protocol AdsStarter {
    func startAds()
}

/// 広告表示前の同意フローを統括する。
/// 順序: UMP 同意取得 → ATT 許可リクエスト → (同意 OK なら) GADMobileAds start
final class AdsBootstrapper: ObservableObject {
    @Published private(set) var isAdsStarted = false

    private let consentService: ConsentService
    private let trackingAuthorizer: TrackingAuthorizer
    private let adsStarter: AdsStarter
    private var isBootstrapping = false

    init(
        consentService: ConsentService,
        trackingAuthorizer: TrackingAuthorizer,
        adsStarter: AdsStarter
    ) {
        self.consentService = consentService
        self.trackingAuthorizer = trackingAuthorizer
        self.adsStarter = adsStarter
    }

    func bootstrap(from viewController: UIViewController?, completion: (() -> Void)?) {
        guard !isAdsStarted, !isBootstrapping else {
            completion?()
            return
        }
        isBootstrapping = true

        // UMP がエラーを返しても前回セッションの cached 同意で
        // canRequestAds が立ち得るため、エラーでもフローは継続する
        consentService.gatherConsent(from: viewController) { [weak self] _ in
            self?.trackingAuthorizer.requestAuthorization {
                guard let self else { return }
                self.isBootstrapping = false
                if self.consentService.canRequestAds {
                    self.adsStarter.startAds()
                    self.isAdsStarted = true
                }
                completion?()
            }
        }
    }
}
