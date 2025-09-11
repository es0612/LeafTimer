import Foundation
import SwiftUI

class SettingViewModel: ObservableObject {
    // MARK: - Dependency Injection

    var userDefaultWrapper: UserDefaultsWrapper

    // MARK: - Observed Parameter

    @Published
    var workingTime: Int = 4
    @Published
    var breakTime: Int = 4

    @Published
    var workingSound: Int = 0
    @Published
    var breakSound: Int = 0

    @Published
    var vibrationIsOn: Bool = true

    @Published
    var mode: Int = 0

    // MARK: - Initialization

    init(userDefaultWrapper: UserDefaultsWrapper) {
        self.userDefaultWrapper = userDefaultWrapper
    }

    func write(selected: Int, item: String) {
        userDefaultWrapper.saveData(key: item, value: selected)
    }

    func write(isOn: Bool, item: String) {
        userDefaultWrapper.saveData(key: item, value: isOn)
    }

    func readInt(item: String) -> Int {
        userDefaultWrapper.loadData(key: item)
    }

    func readBool(item: String) -> Bool {
        userDefaultWrapper.loadData(key: item)
    }

    func readData() {
        workingTime = readInt(item: UserDefaultItem.workingTime.rawValue)
        breakTime = readInt(item: UserDefaultItem.breakTime.rawValue)
        vibrationIsOn = readBool(item: UserDefaultItem.vibration.rawValue)

        workingSound = readInt(item: UserDefaultItem.workingSound.rawValue)
        breakSound = readInt(item: UserDefaultItem.breakSound.rawValue)
    }
}

extension SettingViewModel {}
