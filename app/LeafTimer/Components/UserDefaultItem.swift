enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration

    case workingSound
    case breakSound
}

enum ItemValue {
    static let workingTimeList = [5 * 60, 10 * 60, 15 * 60, 20 * 60, 25 * 60, 30 * 60]
    static let workingTimeListString = ["5分", "10分", "15分", "20分", "25分", "30分"]

    static let breakTimeList = [1 * 60, 2 * 60, 3 * 60, 4 * 60, 5 * 60, 6 * 60, 7 * 60, 8 * 60, 9 * 60, 10 * 60]
    static let breakTimeListString = ["1分", "2分", "3分", "4分", "5分", "6分", "7分", "8分", "9分", "10分"]

    static let soundList = ["なし", "雨音", "川のせせらぎ"]
    static let soundListFileName = ["noSound", "rain1", "river1"]
}
