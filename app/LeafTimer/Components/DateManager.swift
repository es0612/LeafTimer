import Foundation

enum DateManager {
    /// Issue #211: 日付キー (yyyy/MM/dd) の formatter。端末の暦 (和暦・仏暦) や数字 (アラビア数字) に
    /// 左右されないよう、グレゴリオ暦 + en_US_POSIX に固定する。タイムゾーンは端末に従う。
    /// タイムゾーンの変更を拾えるよう、static にキャッシュせず毎回作る。
    static func makeKeyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = keyCalendar()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }

    /// Issue #211: 日付キーの前後日の計算に使う暦 (グレゴリオ暦・端末のタイムゾーン)。
    static func keyCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    static func getToday() -> String {
        makeKeyFormatter().string(from: Date())
    }

    static func convertStringToTime(string: String) -> Date {
        makeKeyFormatter().date(from: string) ?? Date()
    }

    static func convertTimeToString(time: Date) -> String {
        makeKeyFormatter().string(from: time)
    }
}
