import Foundation
import SwiftUI

class SettingViewModel: ObservableObject {

    // MARK: - Dependency Injection
    var userDefaultWrapper: UserDefaultsWrapper

    // MARK: - Observed Parameter
    @Published var workingTime: Int = 0
    @Published var breakTime: Int = 0

    @Published var workingSound: Int = 0
    @Published var breakSound: Int = 0

    @Published var vibrationIsOn: Bool = true

    @Published var mode: Int = 0


    // MARK: - Initialization
    init(userDefaultWrapper: UserDefaultsWrapper) {
        self.userDefaultWrapper = userDefaultWrapper
    }

    func write(selected: Int, item: String){
        userDefaultWrapper.saveData(key: item, value: selected)
    }

    func write(isOn: Bool, item: String){
        userDefaultWrapper.saveData(key: item, value: isOn)
    }

    func read(item: String) -> Int {
        return userDefaultWrapper.loadData(key: item)
    }

    func read(item: String) -> Bool {
        return userDefaultWrapper.loadData(key: item)
    }

    func readData() {
        workingTime = read(item: UserDefaultItem.workingTime.rawValue)
        breakTime = read(item: UserDefaultItem.breakTime.rawValue)
        vibrationIsOn = read(item: UserDefaultItem.vibration.rawValue)

        workingSound = read(item: UserDefaultItem.workingSound.rawValue)
        breakSound = read(item: UserDefaultItem.breakSound.rawValue)
    }

}

extension SettingViewModel {

}
