import Foundation
import SwiftUI

class SettingViewModel: ObservableObject {
    // MARK: - Dependency Injection

    var userDefaultWrapper: UserDefaultsWrapper
    var reviewRequester: ReviewRequesting

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

    init(
        userDefaultWrapper: UserDefaultsWrapper,
        reviewRequester: ReviewRequesting = StoreKitReviewRequester()
    ) {
        self.userDefaultWrapper = userDefaultWrapper
        self.reviewRequester = reviewRequester
    }

    func openAppStoreReviewPage() {
        reviewRequester.openAppStoreReviewPage()
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

extension SettingViewModel {
    /// 初回オンボーディングを表示すべきか判定する。
    /// - 既に見た（フラグ true）→ false
    /// - 既存ユーザー（totalPomodoroCount > 0）→ フラグを true にシードして false
    /// - それ以外（真の新規）→ true
    func shouldShowOnboarding() -> Bool {
        if readBool(item: UserDefaultItem.hasSeenOnboarding.rawValue) {
            return false
        }
        if readInt(item: UserDefaultItem.totalPomodoroCount.rawValue) > 0 {
            markOnboardingSeen()
            return false
        }
        return true
    }

    /// オンボーディングを見たことを記録する（以後は表示しない）。
    func markOnboardingSeen() {
        write(isOn: true, item: UserDefaultItem.hasSeenOnboarding.rawValue)
    }
}
