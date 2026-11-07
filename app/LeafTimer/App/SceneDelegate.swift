import SwiftUI
import UIKit

/// Issue #201: iOS / iPadOS 27.2 では UIScene ライフサイクルに対応していないアプリが
/// 起動時に assert で落ちるため、window の作成と lifecycle の処理を AppDelegate から移した。
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var backgroundTaskKeeper = BackgroundTaskKeeper(runner: UIApplication.shared)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

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

        window.rootViewController = UIHostingController(rootView: contentView)
        window.makeKeyAndVisible()
        self.window = window

        // 同意フォーム/ATT ダイアログの提示は app active 後である必要があるため
        // 起動処理完了後の main queue で開始する
        DispatchQueue.main.async { [weak self] in
            AdsBootstrapper.shared.bootstrap(
                from: self?.window?.rootViewController,
                completion: nil
            )
        }
    }

    // バックグラウンド遷移移行直前に呼ばれる
    func sceneWillResignActive(_ scene: UIScene) {
        backgroundTaskKeeper.begin()
    }

    // アクティブになる度に呼ばれる
    func sceneDidBecomeActive(_ scene: UIScene) {
        backgroundTaskKeeper.end()
    }
}
