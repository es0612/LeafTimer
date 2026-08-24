import Foundation

// Issue #54: フェーズ境界のローカル通知予約の抽象。
// TimerManager / AudioManager と同じ protocol DI パターン。
struct NotificationEntry: Equatable {
    let fireDate: Date
    let titleKey: String
    let bodyKey: String
}

protocol NotificationScheduler {
    func requestAuthorizationIfNeeded()
    func scheduleChain(entries: [NotificationEntry])
    func cancelAll()
}

// タイマー開始時点の状態から先 3 往復分のフェーズ境界通知を組み立てる純粋ロジック。
enum NotificationChainBuilder {
    static let cycles = 3

    static func build(
        endDate: Date,
        breakState: Bool,
        workDuration: Int,
        breakDuration: Int
    ) -> [NotificationEntry] {
        guard workDuration + breakDuration > 0 else { return [] }

        var entries: [NotificationEntry] = []
        var fireDate = endDate
        var isBreak = breakState

        for _ in 0..<(cycles * 2) {
            let entry = isBreak
                ? NotificationEntry(
                    fireDate: fireDate,
                    titleKey: "notification.breakEnd.title",
                    bodyKey: "notification.breakEnd.body"
                )
                : NotificationEntry(
                    fireDate: fireDate,
                    titleKey: "notification.workEnd.title",
                    bodyKey: "notification.workEnd.body"
                )
            entries.append(entry)

            isBreak.toggle()
            let nextDuration = isBreak ? breakDuration : workDuration
            fireDate = fireDate.addingTimeInterval(TimeInterval(nextDuration))
        }

        return entries
    }
}
