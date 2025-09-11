import Foundation

enum DateManager {
    static func getToday(format: String = "yyyy/MM/dd") -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: now as Date)
    }

    static func convertStringToTime(string: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        return dateFormatter.date(from: string) ?? Date()
    }

    static func convertTimeToString(time: Date) -> String {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "yyyy/MM/dd"
        return dateformatter.string(from: time)
    }
}
