import Firebase
import SwiftUI
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        // GADMobileAds の start は UMP 同意 + ATT 完了後に AdsBootstrapper が行う (#57)

        window = UIWindow()

        // Issue #70: 同一の UserDefaults.standard を見るラッパーを VM ごとに
        // 別インスタンス生成していたため 1 つに集約する (振る舞いは不変)。
        let userDefaultWrapper = LocalUserDefaultsWrapper()

        let contentView = TimerView(
            timerViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: userDefaultWrapper,
                sessionStatsRepository: LocalSessionStatsRepository()
            ),
            settingViewModel: SettingViewModel(
                userDefaultWrapper: userDefaultWrapper
            )
        )

        let vc = UIHostingController(rootView: contentView)

        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        // 同意フォーム/ATT ダイアログの提示は app active 後である必要があるため
        // 起動処理完了後の main queue で開始する
        DispatchQueue.main.async { [weak self] in
            AdsBootstrapper.shared.bootstrap(
                from: self?.window?.rootViewController,
                completion: nil
            )
        }

        // AVAudioSession の設定は DefaultAudioManager に一元化している (#55)。
        // ここで options 無しの setCategory を呼ぶと .mixWithOthers が上書きされ、
        // 他アプリの音楽がタイマー起動時に停止する。
        return true
    }

    // バックグラウンド遷移移行直前に呼ばれる
    func applicationWillResignActive(_ application: UIApplication) {
        // 新しいタスクを登録
        backgroundTaskID = application.beginBackgroundTask {
            [weak self] in
            // Issue #70: expiration handler は self 解放後にも呼ばれうるため
            // force unwrap を guard let に置き換える。
            guard let self else { return }
            application.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }

    // アプリがアクティブになる度に呼ばれる
    func applicationDidBecomeActive(_ application: UIApplication) {
        // タスクの解除
        application.endBackgroundTask(backgroundTaskID)
    }
}
