import Foundation

protocol UserDefaultsWrapper {
    func saveData(key: String, value: Int)
    func loadData(key: String) -> Int

    func saveData(key: String, value: Bool)
    func loadData(key: String) -> Bool
}

class LocalUserDefaultsWrapper: UserDefaultsWrapper {
    private let userDefaults = UserDefaults.standard

    func saveData(key: String, value: Int) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func loadData(key: String) -> Int {
        return userDefaults.integer(forKey: key)

        // default 0
    }

    func saveData(key: String, value: Bool) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func loadData(key: String) -> Bool {
        return userDefaults.bool(forKey: key)

        //default false
    }

}
