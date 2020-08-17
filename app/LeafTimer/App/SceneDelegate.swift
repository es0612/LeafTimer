import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        let contentView = TimerView(
            timverViewModel: TimerViewModel(
                timerManager: DefaultTimerManager(),
                audioManager: DefaultAudioManager(),
                userDefaultWrapper: LocalUserDefaultsWrapper()
        ),
            settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
        )

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)

            let vc = UIHostingController(rootView: contentView)
            vc.view.backgroundColor = .white
            
            window.rootViewController = vc

            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
