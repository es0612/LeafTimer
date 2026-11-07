import Firebase
import UIKit

// Issue #201: window の作成と lifecycle (background task) は SceneDelegate が持つ。
// ここにはアプリ全体で 1 回だけ行う初期化だけを置く。
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        // GADMobileAds の start は UMP 同意 + ATT 完了後に AdsBootstrapper が行う (#57)

#if DEBUG
        // Issue #161: ストア用スクショ撮影のサンプルデータ (起動引数がある時だけ)。
        // didFinishLaunching は scene の接続より前に呼ばれるので、root view を作る前に効く。
        DebugStoreScreenshot.seedIfRequested()
#endif

        // AVAudioSession の設定は DefaultAudioManager に一元化している (#55)。
        // ここで options 無しの setCategory を呼ぶと .mixWithOthers が上書きされ、
        // 他アプリの音楽がタイマー起動時に停止する。
        return true
    }
}
