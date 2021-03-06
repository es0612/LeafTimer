import SwiftUI
import GoogleMobileAds

struct AdsView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: kGADAdSizeBanner)
        
        //                test id
        //                banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"

        banner.adUnitID = KeyManager().getValue(key: "adUnitID")! as? String
        print(banner.adUnitID)
        banner.rootViewController = UIApplication.shared.windows.first?.rootViewController

        let request = GADRequest()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
    }
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
