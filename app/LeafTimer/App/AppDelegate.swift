import UIKit
import SwiftUI
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    var backgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)

    var oldBackgroundTaskID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    var timer: Timer?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow()

        let contentView = TimerView(
            timverViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: LocalUserDefaultsWrapper()
            ),
            settingViewModel: SettingViewModel(
                userDefaultWrapper: LocalUserDefaultsWrapper()
            )
        )

        let vc = UIHostingController(rootView: contentView)

        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }

        return true
    }

    //バックグラウンド遷移移行直前に呼ばれる
    func applicationWillResignActive(_ application: UIApplication) {
        // 新しいタスクを登録
        backgroundTaskID = application.beginBackgroundTask {
            [weak self] in
            
            application.endBackgroundTask((self?.backgroundTaskID)!)
            self?.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }
    
    //アプリがアクティブになる度に呼ばれる
    func applicationDidBecomeActive(_ application: UIApplication) {
        //タスクの解除
        timer?.invalidate()
        application.endBackgroundTask(self.backgroundTaskID)
    }
}
