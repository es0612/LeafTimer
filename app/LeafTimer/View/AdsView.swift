import GoogleMobileAds
import SwiftUI

struct AdsView: View {
    @ObservedObject private var adsBootstrapper = AdsBootstrapper.shared

    var body: some View {
#if DEBUG
        // Issue #161: ストア用スクショにテスト広告を写さない
        if DebugStoreScreenshot.isHideAdsRequested() {
            Color.clear
        } else {
            banner
        }
#else
        banner
#endif
    }

    @ViewBuilder
    private var banner: some View {
        if adsBootstrapper.isAdsStarted {
            AdsBannerView()
        } else {
            Color.clear
        }
    }
}

private struct AdsBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)

        banner.adUnitID = KeyManager().getAdUnitID()
        // iOS 17対応: windowSceneから適切なrootViewControllerを取得
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            banner.rootViewController = windowScene.windows.first?.rootViewController
        }

        let request = GADRequest()
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
