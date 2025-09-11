import Foundation

@testable import LeafTimer

class MockUserDefaultWrapper: UserDefaultsWrapper {
    
    // MARK: - Mock Data
    var mockIntValue: Int = 0
    var mockBoolValue: Bool = false
    
    // MARK: - Call Tracking
    private(set) var saveDataIntCallCount = 0
    private(set) var saveDataBoolCallCount = 0
    private(set) var loadDataIntCallCount = 0
    private(set) var loadDataBoolCallCount = 0
    
    private(set) var lastSavedKey: String?
    private(set) var lastSavedValue: Int?
    private(set) var lastSavedBoolValue: Bool?
    
    // MARK: - Storage for multiple keys
    private var intStorage: [String: Int] = [:]
    private var boolStorage: [String: Bool] = [:]
    
    // MARK: - Int Methods
    func saveData(key: String, value: Int) {
        saveDataIntCallCount += 1
        lastSavedKey = key
        lastSavedValue = value
        intStorage[key] = value
    }
    
    func loadData(key: String) -> Int {
        loadDataIntCallCount += 1
        
        // Return stored value if exists, otherwise return mock value
        return intStorage[key] ?? mockIntValue
    }
    
    // MARK: - Bool Methods
    func saveData(key: String, value: Bool) {
        saveDataBoolCallCount += 1
        lastSavedKey = key
        lastSavedBoolValue = value
        boolStorage[key] = value
    }
    
    func loadData(key: String) -> Bool {
        loadDataBoolCallCount += 1
        
        // Return stored value if exists, otherwise return mock value
        return boolStorage[key] ?? mockBoolValue
    }
    
    // MARK: - Helper Methods for Testing
    func reset() {
        saveDataIntCallCount = 0
        saveDataBoolCallCount = 0
        loadDataIntCallCount = 0
        loadDataBoolCallCount = 0
        lastSavedKey = nil
        lastSavedValue = nil
        lastSavedBoolValue = nil
        intStorage.removeAll()
        boolStorage.removeAll()
        mockIntValue = 0
        mockBoolValue = false
    }
    
    func setValue(for key: String, value: Int) {
        intStorage[key] = value
    }
    
    func setValue(for key: String, value: Bool) {
        boolStorage[key] = value
    }
}