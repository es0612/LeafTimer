import Foundation
import UserNotifications

// Issue #54: UNUserNotificationCenter の thin wrapper。unit test 対象外
// (Simulator 実地確認で代替)。identifier は固定 prefix + index で、
// cancelAll は自分の予約分だけを削除する。
class DefaultNotificationScheduler: NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "jp.ema.LeafTimer.phase."
    private var didRequestAuthorization = false
    // Issue #54 I-2: 許可応答前に scheduleChain された entries を保持し、
    // granted 後に自己完結で再予約する (add() の .notDetermined 未検証セマンティクスに依存しない)
    private var lastEntries: [NotificationEntry] = []

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            guard granted, let self else { return }
            DispatchQueue.main.async {
                self.addRequests(for: self.lastEntries)
            }
        }
    }

    func scheduleChain(entries: [NotificationEntry]) {
        cancelAll()
        lastEntries = entries
        addRequests(for: entries)
    }

    private func addRequests(for entries: [NotificationEntry]) {
        for (index, entry) in entries.enumerated() {
            let interval = entry.fireDate.timeIntervalSinceNow
            guard interval > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString(entry.titleKey, comment: "")
            content.body = NSLocalizedString(entry.bodyKey, comment: "")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval, repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.identifierPrefix + String(index),
                content: content,
                trigger: trigger
            )
            // Issue #54 M-2: 予約失敗はログのみ (spec: 致命ではない)
            center.add(request) { error in
                if let error {
                    AppLogger.notification.error("notification add failed - \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func cancelAll() {
        // Issue #120: 許可ダイアログ応答と Stop の交錯レースで completion が
        // 停止済みチェーンを復活させないよう、保持中 entries も同時に破棄する
        lastEntries = []
        let identifiers = (0..<(NotificationChainBuilder.cycles * 2))
            .map { Self.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        // Issue #120 (M-1): 配送済みバナーも通知センターから掃除する。
        // scheduleChain 経由でも呼ばれるため、再予約時に stale バナーが消えるのは意図した挙動
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
