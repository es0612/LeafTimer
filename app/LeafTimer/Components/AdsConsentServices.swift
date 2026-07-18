import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// UMP (User Messaging Platform) による GDPR 同意取得。
/// EEA/UK 以外の地域では form 提示不要と判定され、そのまま completion が呼ばれる。
final class UMPConsentService: ConsentService {
    var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    func gatherConsent(
        from viewController: UIViewController?,
        completion: @escaping (Error?) -> Void
    ) {
        let parameters = RequestParameters()
        #if DEBUG
        // Simulator 検証用: launch argument で EEA 地域を強制する
        if ProcessInfo.processInfo.arguments.contains("-UMPDebugGeographyEEA") {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { updateError in
            if let updateError {
                DispatchQueue.main.async {
                    completion(updateError)
                }
                return
            }
            DispatchQueue.main.async {
                // onboarding の fullScreenCover 等が root を占有していても提示できるよう
                // 最前面の presented VC から同意フォームを提示する
                ConsentForm.loadAndPresentIfRequired(from: viewController?.topPresentedViewController) { formError in
                    completion(formError)
                }
            }
        }
    }
}

/// ATT (App Tracking Transparency) の許可リクエスト。
/// 既に許可/拒否済み (.notDetermined 以外) の場合はダイアログなしで即 completion が呼ばれる。
final class ATTAuthorizer: TrackingAuthorizer {
    func requestAuthorization(completion: @escaping () -> Void) {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

final class GADAdsStarter: AdsStarter {
    func startAds() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
}

private extension UIViewController {
    /// presentedViewController チェーンの最前面 (何も提示していなければ self)
    var topPresentedViewController: UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
