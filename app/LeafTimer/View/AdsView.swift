import GoogleMobileAds
import SwiftUI

struct AdsView: View {
    @ObservedObject private var adsBootstrapper = AdsBootstrapper.shared

    var body: some View {
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

struct ContentView: View {
    var body: some View {
        //        AdsView()
        // サイズを変更する場合
        AdsView().frame(width: 320, height: 50)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
