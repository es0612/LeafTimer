enum UserDefaultItem: String {
    case workingTime
    case breakTime
    case vibration

    case workingSound
    case breakSound
}

struct ItemValue{
    static let workingTimeList = [15*60, 20*60, 25*60, 30*60]
    static let workingTimeListString = ["15分", "20分", "25分", "30分"]

    static let breakTimeList = [3*60, 5*60, 7*60, 10*60]
    static let breakTimeListString = ["3分", "5分", "7分", "10分"]

    static let soundList = ["雨音", "川のせせらぎ"]
    static let soundListFileName = ["rain1", "river1"]

}
