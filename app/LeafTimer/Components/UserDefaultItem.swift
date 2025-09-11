import Foundation

enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration

    case workingSound
    case breakSound
}

enum ItemValue {
    static let workingTimeList = [5 * 60, 10 * 60, 15 * 60, 20 * 60, 25 * 60, 30 * 60]
    static let workingTimeListString = [
        NSLocalizedString("time.5_minutes", comment: "5 minutes"),
        NSLocalizedString("time.10_minutes", comment: "10 minutes"),
        NSLocalizedString("time.15_minutes", comment: "15 minutes"),
        NSLocalizedString("time.20_minutes", comment: "20 minutes"),
        NSLocalizedString("time.25_minutes", comment: "25 minutes"),
        NSLocalizedString("time.30_minutes", comment: "30 minutes"),
    ]

    static let breakTimeList = [1 * 60, 2 * 60, 3 * 60, 4 * 60, 5 * 60, 6 * 60, 7 * 60, 8 * 60, 9 * 60, 10 * 60]
    static let breakTimeListString = [
        NSLocalizedString("time.1_minute", comment: "1 minute"),
        NSLocalizedString("time.2_minutes", comment: "2 minutes"),
        NSLocalizedString("time.3_minutes", comment: "3 minutes"),
        NSLocalizedString("time.4_minutes", comment: "4 minutes"),
        NSLocalizedString("time.5_minutes", comment: "5 minutes"),
        NSLocalizedString("time.6_minutes", comment: "6 minutes"),
        NSLocalizedString("time.7_minutes", comment: "7 minutes"),
        NSLocalizedString("time.8_minutes", comment: "8 minutes"),
        NSLocalizedString("time.9_minutes", comment: "9 minutes"),
        NSLocalizedString("time.10_minutes", comment: "10 minutes"),
    ]

    static let soundList = [
        NSLocalizedString("sound.none", comment: "No sound"),
        NSLocalizedString("sound.rain", comment: "Rain sound"),
        NSLocalizedString("sound.river", comment: "River sound"),
    ]
    static let soundListFileName = ["noSound", "rain1", "river1"]
}
