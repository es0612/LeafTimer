import Foundation
import UserNotifications

// Issue #54: UNUserNotificationCenter の thin wrapper。unit test 対象外
// (Simulator 実地確認で代替)。identifier は固定 prefix + index で、
// cancelAll は自分の予約分だけを削除する。
class DefaultNotificationScheduler: NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "jp.ema.LeafTimer.phase."
    private var didRequestAuthorization = false

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleChain(entries: [NotificationEntry]) {
        cancelAll()

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
            center.add(request)
        }
    }

    func cancelAll() {
        let identifiers = (0..<(NotificationChainBuilder.cycles * 2))
            .map { Self.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
