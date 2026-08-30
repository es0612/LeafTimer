import Foundation

protocol UserDefaultsWrapper {
    func saveData(key: String, value: Int)
    func loadData(key: String) -> Int

    func saveData(key: String, value: Bool)
    func loadData(key: String) -> Bool
}

class LocalUserDefaultsWrapper: UserDefaultsWrapper {
    private let userDefaults: UserDefaults

    /// Issue #77: テストから suite 指定の UserDefaults を注入できるようにする。
    /// 既存の呼び出し (引数なし) は .standard のまま。
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // Issue #70: synchronize() は iOS 12 以降 deprecated かつ不要 (UserDefaults が自動で永続化する)

    func saveData(key: String, value: Int) {
        userDefaults.set(value, forKey: key)
    }

    func loadData(key: String) -> Int {
        userDefaults.integer(forKey: key)

        // default 0
    }

    func saveData(key: String, value: Bool) {
        userDefaults.set(value, forKey: key)
    }

    func loadData(key: String) -> Bool {
        userDefaults.bool(forKey: key)

        // default false
    }
}
