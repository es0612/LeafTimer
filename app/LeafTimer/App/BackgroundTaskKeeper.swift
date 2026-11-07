import UIKit

/// background task の開始と終了を担う相手。本番は `UIApplication`、テストは spy。
protocol BackgroundTaskRunning: AnyObject {
    func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier)
}

extension UIApplication: BackgroundTaskRunning {}

/// バックグラウンドへ移る直前に task を始め、アクティブに戻ったら終える。
/// Issue #201: UIScene に対応すると AppDelegate の `applicationWillResignActive` /
/// `applicationDidBecomeActive` は呼ばれなくなるため、SceneDelegate から呼べるよう切り出した。
final class BackgroundTaskKeeper {
    private let runner: BackgroundTaskRunning
    private(set) var taskID = UIBackgroundTaskIdentifier.invalid

    init(runner: BackgroundTaskRunning) {
        self.runner = runner
    }

    func begin() {
        taskID = runner.beginBackgroundTask { [weak self] in
            // Issue #70: expiration handler は self 解放後にも呼ばれうるため強参照しない。
            self?.end()
        }
    }

    func end() {
        // Issue #128: 初回 activation 等、background task 未登録なら何もしない。
        guard taskID != .invalid else { return }
        runner.endBackgroundTask(taskID)
        taskID = .invalid
    }
}
