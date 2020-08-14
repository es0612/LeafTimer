import Foundation
import SwiftUI

class SettingViewModel: ObservableObject {

    // MARK: - Dependency Injection
    var userDefaultWrapper: UserDefaultsWrapper

    // MARK: - Observed Parameter
    @Published var workingTime: Int = 0
    @Published var brakeTime: Int = 0

    @Published var workingSound: Int = 0
    @Published var brakeSound: Int = 0

    @Published var vibrationIsOn: Bool = true

    @Published var mode: Int = 0


    // MARK: - Initialization
    init(userDefaultWrapper: UserDefaultsWrapper) {
        self.userDefaultWrapper = userDefaultWrapper
    }

}

extension SettingViewModel {

}
