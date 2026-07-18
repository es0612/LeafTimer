import Firebase
import SwiftUI
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var backgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)

    var oldBackgroundTaskID = UIBackgroundTaskIdentifier(rawValue: 0)
    var timer: Timer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        // GADMobileAds の start は UMP 同意 + ATT 完了後に AdsBootstrapper が行う (#57)

        window = UIWindow()

        let contentView = TimerView(
            timerViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: LocalUserDefaultsWrapper(),
                sessionStatsRepository: LocalSessionStatsRepository()
            ),
            settingViewModel: SettingViewModel(
                userDefaultWrapper: LocalUserDefaultsWrapper()
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
            application.endBackgroundTask((self?.backgroundTaskID)!)
            self?.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }

    // アプリがアクティブになる度に呼ばれる
    func applicationDidBecomeActive(_ application: UIApplication) {
        // タスクの解除
        timer?.invalidate()
        application.endBackgroundTask(backgroundTaskID)
    }
}
